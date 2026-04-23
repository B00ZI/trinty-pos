# User Authentication & Games Tickets — Implementation Plan

This plan covers two major feature sets for the Easify POS app: **User Authentication** (PIN-based auth flows) and **Games/Tickets System** (posts, party sessions, ticket printing, notifications).

---

## Codebase Summary

| Aspect | Current State |
|---|---|
| **State Management** | Direct `StatefulWidget` + `setState` (no Bloc/Provider) |
| **Persistence** | ObjectBox (11 entities), SharedPreferences for some settings |
| **Navigation** | `BottomNavigationBar` with 5 tabs in `main.dart` |
| **Settings** | `NavigationRail` with 4 sections (Printer, Users, Store, Hours) |
| **Printing** | `PrinterHelper` using `esc_pos_printer` / `esc_pos_utils` over TCP |
| **User Model** | `AppUser` — simple (id, name only), no PIN, no auth |
| **History** | Shows orders filtered by business day, StreamBuilder |
| **Locale** | French (`fr_FR`) throughout the app |
| **ObjectBox Schema** | `lastEntityId: 11`, `lastRelationId: 3`, `lastIndexId: 2` |

---

## User Review Required

> [!IMPORTANT]
> **ObjectBox Schema Migration**: The `AppUser` entity will gain two new fields (`pin`, `createdAt`). Existing users in the database will get `null` for `pin` and a default `createdAt`. These users will need to have PINs set before auth flows can be activated. This is non-destructive — no data loss.

> [!WARNING]
> **Bottom Navigation Bar Expansion**: Adding a 6th tab ("Games") to the bottom nav. With 6 items, `BottomNavigationBarType.fixed` is already set, which supports this. However, on smaller screens the labels may feel cramped. Consider if this is acceptable or if you'd prefer a drawer-based approach for Games.

> [!IMPORTANT]
> **`flutter_local_notifications`** requires Android-specific setup (notification channel, `AndroidManifest.xml` permissions). This will be handled automatically but requires a rebuild. The `timezone` package also needs initialization at app startup.

---

## Open Questions

> [!IMPORTANT]
> 1. **PIN validation approach**: The spec says "store hashed" — should we use SHA-256 from the existing `crypto` package? (Plan assumes yes.)
> 2. **Idle timeout for Session Login (Flow A)**: The spec mentions "after idle timeout" — should we implement an idle timer, or just app restart / manual switch? (Plan assumes manual switch + app restart only for V1.)
> 3. **Currency**: Game session prices display as `DH` like orders — correct?
> 4. ~~**Party number reset**~~: **Resolved** — `partyNumber` is **global** across all posts, tracked via a dedicated `PartyCounter` entity (same pattern as `OrderCounter`).
> 5. **Auth mode default**: When no users exist and auth is off, should the app behave exactly as it does now (no auth)? (Plan assumes yes — auth flows only activate when toggled ON and ≥1 user exists.)

---

## Proposed Changes

### Phase 1 — Dependencies & Package Setup

#### [MODIFY] [pubspec.yaml](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/pubspec.yaml)
Add new dependencies:
```yaml
flutter_local_notifications: ^18.0.1
timezone: ^0.10.0
```
The `crypto` and `shared_preferences` packages are already present.

---

### Phase 2 — Data Models

#### [MODIFY] [app_user.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/models/app_user.dart)
Extend `AppUser` with:
- `pin` — `String?` (SHA-256 hashed 4-digit PIN, nullable for migration)
- `createdAt` — `DateTime` (defaults to `DateTime.now()`)

Add a static helper method `hashPin(String rawPin)` that returns SHA-256 hex digest.

```dart
@Entity()
class AppUser {
  @Id()
  int id;
  String name;
  String? pin; // SHA-256 hashed
  DateTime createdAt;

  AppUser({this.id = 0, required this.name, this.pin, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  static String hashPin(String rawPin) {
    final bytes = utf8.encode(rawPin);
    return sha256.convert(bytes).toString();
  }

  bool verifyPin(String rawPin) => pin == hashPin(rawPin);
}
```

---

#### [NEW] [game_post.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/models/game_post.dart)
```dart
@Entity()
class GamePost {
  @Id()
  int id;
  String label;        // e.g. "Post 1", "PS5 Left"
  bool isActive;       // true if a party is running

  GamePost({this.id = 0, required this.label, this.isActive = false});
}
```

#### [NEW] [party_counter.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/models/party_counter.dart)
Global sequential counter for party numbers (same pattern as `OrderCounter`):
```dart
@Entity()
class PartyCounter {
  @Id(assignable: true)
  int id;
  int value;

  PartyCounter({this.id = 0, this.value = 1});
}
```
Initialized in `main()` alongside `OrderCounter`.

#### [NEW] [party_tier.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/models/party_tier.dart)
```dart
@Entity()
class PartyTier {
  @Id()
  int id;
  String label;          // e.g. "30 min"
  int durationMinutes;   // 0 = open/unlimited
  double price;

  PartyTier({this.id = 0, required this.label, required this.durationMinutes, required this.price});
}
```

#### [NEW] [game_session.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/models/game_session.dart)
```dart
@Entity()
class GameSession {
  @Id()
  int id;
  int postId;
  int tierId;
  String postLabel;        // snapshot
  int partyNumber;
  String tierLabel;        // snapshot
  DateTime startTime;
  DateTime endTime;
  DateTime? actualEndTime; // set if ended early
  int status;              // 0=active, 1=completed, 2=cancelled
  double price;            // snapshot of tier price
  int? attributedUserId;

  // Relations
  final post = ToOne<GamePost>();
  final tier = ToOne<PartyTier>();

  GameSession({
    this.id = 0,
    required this.postId,
    required this.tierId,
    required this.postLabel,
    required this.partyNumber,
    required this.tierLabel,
    required this.startTime,
    required this.endTime,
    this.actualEndTime,
    this.status = 0,
    required this.price,
    this.attributedUserId,
  });

  // Helpers
  bool get isActive => status == 0;
  bool get isCompleted => status == 1;
  bool get isCancelled => status == 2;
  bool get isOpenSession => endTime.difference(startTime).inMinutes == 0;
}
```

---

#### [MODIFY] [objectbox.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/objectbox.dart)
Register the 4 new entity boxes:
- `Box<GamePost> gamePostBox`
- `Box<PartyTier> partyTierBox`
- `Box<GameSession> gameSessionBox`
- `Box<PartyCounter> partyCounterBox`

#### ObjectBox Code Generation
After model changes, run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
This updates `objectbox.g.dart` and `objectbox-model.json`.

---

### Phase 3 — User Management Enhancement

#### [MODIFY] [settings_screen.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/screens/settings_screen.dart)
**`UserManagementSection`** — Rewrite the `_addUser()` dialog to include:
- Name text field
- PIN field (4-digit, `obscureText: true`, `maxLength: 4`, numeric keyboard)
- Confirm PIN field
- Validation: PINs match, exactly 4 digits, name not empty
- Save: hash PIN via `AppUser.hashPin()` before storing

**Delete user** — Add confirmation dialog before deletion.

**Add "Auth Mode" section** to the `NavigationRail`:
- New rail destination: icon `Icons.security`, label `'Sécurité'`
- New section widget `AuthModeSection` with:
  - Toggle between "Connexion Session" (Flow A) and "PIN par Commande" (Flow B)
  - A third option: "Désactivé" (Off) — no auth
  - Persisted via `SharedPreferences` key `auth_mode` (values: `off`, `session`, `per_order`)
  - Greyed out / disabled if no users exist

---

### Phase 4 — Authentication Flows

#### [NEW] [auth_service.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/service/auth_service.dart)
Centralized auth logic:
- `getAuthMode()` → reads SharedPreferences, returns enum `AuthMode { off, session, perOrder }`
- `setAuthMode(AuthMode mode)` → persists to SharedPreferences
- `verifyPin(AppUser user, String rawPin)` → returns bool
- `getUsers(ObjectBox objectbox)` → returns list of AppUser

#### [NEW] [user_selection_dialog.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/widgets/user_selection_dialog.dart)
Reusable widget used by both auth flows:
- **Step 1 — User Selection**: Shows list of user names as tappable styled cards
- **Step 2 — PIN Entry**: Custom on-screen numeric keypad (ATM-style grid of buttons 0–9, backspace, confirm) — **does NOT trigger the system keyboard**
  - 4 dots/circles showing PIN progress (filled as digits are entered)
  - Buttons: `1 2 3 / 4 5 6 / 7 8 9 / ⌫ 0 ✓`
  - On 4th digit auto-submits, or user taps ✓
- Returns `AppUser?` on success, `null` on cancel
- Shows error shake animation + red flash on wrong PIN with retry (dots reset)

#### [MODIFY] [main.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/main.dart)
**Flow A (Session Login):**
- After activation check, read `auth_mode` from SharedPreferences
- If `session` mode: show `UserSelectionDialog` as a full-screen modal (not dismissible)
- Store selected user in `_selectedUser` state
- Update AppBar to show `'Easify [username]'` (already partially done)
- Replace the double-tap user selection with a proper "Switch User" button in the AppBar or drawer

**Flow B (Per-Order PIN):**
- No login on launch — `_selectedUser` stays null
- The PIN prompt happens at order submission time (handled in `order_screen.dart`)

#### [MODIFY] [order_screen.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/screens/order_screen.dart)
**Flow B integration in `_handleCartAction()`:**
- Before proceeding with save/print, check `auth_mode`
- If `per_order`: show `UserSelectionDialog`, get the user
- Attach user to the order via `order.user.target = selectedUser`
- If cancelled → abort order

---

### Phase 5 — Games Settings UI

#### [NEW] [games_settings_section.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/widgets/games_settings_section.dart)
A settings section widget containing two sub-sections:

**Post Management:**
- "Ajouter un Poste" button → dialog with label text field (default "Poste N")
- List of existing posts as cards with:
  - Label (editable via tap)
  - Delete button (with warning if `isActive`)
- Post count displayed

**Party Tier Management:**
- "Ajouter un Palier" button → dialog with:
  - Label field (e.g. "30 min")
  - Duration field (minutes, 0 = open)
  - Price field (double)
- List of tiers as cards with edit/delete

#### [MODIFY] [settings_screen.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/screens/settings_screen.dart)
Add two new `NavigationRailDestination` items:
1. `Icons.security` → `AuthModeSection` (from Phase 3)
2. `Icons.sports_esports` → `GamesSettingsSection` (from this phase)

Updated rail destinations (6 total):
```
Imprimante | Utilisateurs | Boutique | Horaires | Sécurité | Jeux
```

---

### Phase 6 — Games Screen

#### [NEW] [games_screen.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/screens/games_screen.dart)
Main Games screen with:

**Post Grid/List:**
- Uses `StreamBuilder` watching `GamePost` box for real-time updates
- Each post rendered as a card:
  - **Available** (green accent): label + "Disponible" badge
  - **Busy** (red/orange accent): label + "Partie #N — fin à HH:mm" + live countdown timer
- Countdown uses `Timer.periodic` (1 second) updating remaining time display
- Auto-completes sessions when countdown reaches zero

**Start Session (tap available post):**
- Bottom sheet listing all `PartyTier` options as selectable cards
- Shows: tier label, duration, price
- Confirm button → creates `GameSession`, sets post `isActive = true`, increments `nextPartyNumber`
- If auth mode is `per_order` → prompt PIN first
- Triggers ticket print and schedules notification

**View Active Session (tap busy post):**
- Bottom sheet showing session details:
  - Post label, Party #, Tier, Start/End times, Price, Remaining time
- "Terminer" button → sets `actualEndTime`, `status = completed`, `post.isActive = false`
- "Réimprimer Ticket" button → reprints the game ticket
- Cancels scheduled notification

#### [NEW] [game_session_service.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/service/game_session_service.dart)
Business logic service:
- `startSession(GamePost post, PartyTier tier, int? userId, ObjectBox objectbox)` → creates session, updates post, returns `GameSession`
- `endSession(GameSession session, ObjectBox objectbox)` → marks complete, frees post
- `cancelSession(GameSession session, ObjectBox objectbox)` → marks cancelled, frees post
- `getActiveSessionForPost(int postId, ObjectBox objectbox)` → query helper
- `getNextPartyNumber(ObjectBox objectbox)` → reads from global `PartyCounter`, increments and persists (never reused across any post)

---

### Phase 7 — Game Ticket Printing

#### [MODIFY] [printer_helper.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/service/printer_helper.dart)
Add a new static method `printGameTicket(GameSession session, ObjectBox objectbox)`:

```dart
static Future<void> printGameTicket(GameSession session, ObjectBox objectbox) async {
  final printer = await connectToPrinter(objectbox);
  try {
    printer.reset();
    printer.text('===== TICKET JEUX =====',
        styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    printer.feed(1);
    printer.text('Poste:       ${session.postLabel}');
    printer.text('Partie #:    ${session.partyNumber}');
    printer.text('Palier:      ${session.tierLabel}');
    printer.text('Prix:        ${session.price.toStringAsFixed(2)} DH');
    printer.text('Début:       ${_formatTime(session.startTime)}');
    if (session.endTime.difference(session.startTime).inMinutes > 0) {
      printer.text('Fin:         ${_formatTime(session.endTime)}');
    } else {
      printer.text('Fin:         Ouvert');
    }
    printer.feed(1);
    printer.text('========================',
        styles: PosStyles(align: PosAlign.center));
    printer.feed(2);
    printer.cut(mode: PosCutMode.partial);
  } finally {
    printer.disconnect();
  }
}
```

---

### Phase 8 — Notification System

#### [NEW] [notification_service.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/service/notification_service.dart)
Wraps `flutter_local_notifications`:
- `init()` — initialize plugin with Android channel config, called from `main()`
- `scheduleSessionEnd(GameSession session)` — schedules a notification at `session.endTime`
  - Title: `"Partie Terminée — ${session.postLabel}"`
  - Body: `"Partie #${session.partyNumber} (${session.tierLabel}) est terminée."`
  - Uses `zonedSchedule()` with `timezone` package
- `cancelSessionNotification(int sessionId)` — cancels by ID
- `onNotificationTap(String? payload)` — navigates to Games screen (payload contains post ID)

#### [MODIFY] [main.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/main.dart)
- Import and initialize `NotificationService.init()` in `main()` before `runApp`
- Initialize timezone data: `tz.initializeTimeZones()`
- Handle notification tap callback for navigation to Games screen

---

### Phase 9 — History Screen Extension

#### [MODIFY] [history_screen.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/screens/history_screen.dart)
- Add a tab bar at the top with 3 tabs: `Commandes` | `Parties` | `Tout`
- **Commandes tab**: current order list (unchanged)
- **Parties tab**: list of `GameSession` entities filtered by business day
  - Each card shows: Post label, Party #, Tier label, Start/End times, Price, Staff user name
  - Status badge: `Terminée` (green) / `Annulée` (red)
  - "Réimprimer" button → calls `PrinterHelper.printGameTicket()`
- **Tout tab**: interleaved timeline of both orders and parties sorted by date

---

### Phase 10 — Navigation Integration

#### [MODIFY] [main.dart](file:///c:/Users/ASUS/Desktop/devProjects/drywich2.01/lib/main.dart)
Add 6th tab to `BottomNavigationBar`:
```dart
BottomNavigationBarItem(
  icon: Icon(Icons.sports_esports),
  label: 'Jeux',
),
```

Add `GamesScreen` to `widgetOptions` list at the appropriate index (position 2, between History and Dashboard, or at the end — recommend after History):

Updated tab order:
```
Commande | Historique | Jeux | Tableau de bord | Gestion | Paramètres
```

---

## File Summary

| Action | File | Phase |
|---|---|---|
| MODIFY | `pubspec.yaml` | 1 |
| MODIFY | `models/app_user.dart` | 2 |
| NEW | `models/game_post.dart` | 2 |
| NEW | `models/party_tier.dart` | 2 |
| NEW | `models/game_session.dart` | 2 |
| NEW | `models/party_counter.dart` | 2 |
| MODIFY | `objectbox.dart` | 2 |
| MODIFY | `screens/settings_screen.dart` | 3, 5 |
| NEW | `service/auth_service.dart` | 4 |
| NEW | `widgets/user_selection_dialog.dart` | 4 |
| MODIFY | `main.dart` | 4, 8, 10 |
| MODIFY | `screens/order_screen.dart` | 4 |
| NEW | `widgets/games_settings_section.dart` | 5 |
| NEW | `screens/games_screen.dart` | 6 |
| NEW | `service/game_session_service.dart` | 6 |
| MODIFY | `service/printer_helper.dart` | 7 |
| NEW | `service/notification_service.dart` | 8 |
| MODIFY | `screens/history_screen.dart` | 9 |

**Total: 9 new files, 7 modified files**

---

## Verification Plan

### Automated / Build Verification
1. `flutter pub get` — verify all dependencies resolve
2. `flutter pub run build_runner build --delete-conflicting-outputs` — verify ObjectBox codegen succeeds
3. `flutter analyze` — ensure no static analysis errors
4. `flutter build apk --debug` — verify the app builds successfully

### Functional Verification (Manual)
1. **User Management**: Create user with PIN → verify PIN hash stored → delete with confirmation
2. **Auth Flow A**: Enable Session Login → restart app → verify login popup → select user + PIN → verify AppBar shows name → switch user works
3. **Auth Flow B**: Enable Per-Order PIN → create order → verify PIN prompt before save → correct PIN saves order with user attribution
4. **Games Setup**: Add posts and tiers in settings → verify persistence
5. **Games Screen**: Start session on available post → verify card turns red with countdown → verify ticket prints → end early → verify card turns green
6. **Notifications**: Start a short session (e.g. 1 min) → verify notification fires at end time → end early → verify notification cancelled
7. **History**: Verify Parties tab shows completed sessions → reprint ticket works
8. **Dashboard**: Verify game session revenue appears in totals (if integrated)
