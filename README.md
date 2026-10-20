# Easify POS

**Offline-first point of sale for small cafés and shops — Windows desktop and Android tablets.**

Easify is a French-language, cash-only POS built for Marrakech cafés: take orders, print
thermal receipts, track funds and expenses, run prepaid game sessions, and back up
everything from inside the app. It runs **entirely on the device** — no internet, no
server, no account needed to sell.

| | |
|---|---|
| **Version** | 2.0.0 (build `20002`) |
| **Branches** | `2.0.0.2` = production line · `2.0.0.3` = current fix line (this repo state) |
| **Platforms** | Windows 10/11 x64 · Android tablets (side-loaded APK — no Play Store) |
| **Stack** | Flutter 3.47.x stable · ObjectBox (embedded database) · GoRouter · TCP printing (port 91000) |
| **Quality** | 84 automated tests passing · `flutter analyze`: 0 errors, 0 warnings |

---

## What the app does

- **Selling** — cart with quantity merging, **per-unit extras** ("2 thé lait" charges 2
  lattes), mixed orders (a line with extras closes the line), kitchen comment and
  takeaway flag, two receipt copies by design (client + kitchen), *Ticket Simple*,
  cash payment with change display, optional PIN-per-order, seller attribution.
- **Catalogue** — products and categories with photos, unique names enforced
  (products, categories, users), price rules (0 allowed, negative refused),
  admin-PIN-protected deletes, daily/units-sold awareness.
- **History & business days** — order history that snaps to today (with an
  *"Aujourd'hui"* button when browsing old days), edit and reprint old orders at
  **their original prices**; one clock for the whole app: either standard midnight
  reset or *"à quelle heure ouvrez-vous / fermez-vous"* — the app computes the reset
  as the **middle of the closed hours**, so random opening hours never split a day's
  takings across two dates.
- **Money tracking** — fond de caisse, expenses in DH, daily report ticket,
  dashboard today vs. previous day, day-revenue dialog computed from the real
  database (prices, extras, deleted products handled correctly).
- **Games** — prepaid parties with hourly rates, queue that promotes safely,
  session tickets, sessions saved as orders (no double counting), and on Android a
  **"Partie terminée"** notification when a prepaid party auto-ends.
- **Backup (Sauvegarde)** — one button → Exporter / Importer; pick which sections to
  export; import previews *("Ce fichier contient : X commandes…")* before touching
  anything, never wipes data, matches records by content (never blindly by id),
  and never includes the Wi-Fi password.
- **Settings** — printer setup with test tickets and friendly French errors, users
  & PINs, authentication mode (always / per order), maintenance (auto-clean every
  30–365 days + manual PIN-gated clean), offline activation licensing, hidden
  developer panel behind a PIN.

---

## Release 2.0.0 (build 20002) — what changed

A six-batch audit (63 logged problems → [PROBLEMS.md](PROBLEMS.md)) produced this
release. Highlights:

**Printing & receipts**
- Printing never fails silently anymore: every print action shows *"Ticket imprimé"*
  or a short French error; the printer's raw exception text is gone.
- Non-printable characters scrubbed (✅ → OK, € → EUR, emojis dropped) — test button
  and mid-ticket crashes eliminated on all printers.
- Reprints and the daily report use **the saved order's prices**, not today's.
- Cart clears after the receipt is built; double-taps can't print twice; logos are
  encoded off the UI thread.

**Money & data correctness**
- One money parser everywhere: `12,5` and `12.5` both work; garbage input shows
  *"Montant invalide"* instead of silently saving 0.00.
- Extras snapshot their price and name **at sale time** — later price changes never
  rewrite history.
- Paid game sessions are saved in **one sealed transaction** (order + counter +
  session) — a crash can't make a sale count twice.
- Unique-name and price rules enforced for products, categories, users.

**One clock for the whole app**
- All day queries (orders, sessions, expenses, funds, reports, dashboard) share the
  business-day boundary, with end-exclusive ranges so nothing is double-counted or
  dropped at midnight.

**Backup & safety**
- Full Sauvegarde v2 (see above); old backup files still import.
- A cart opened from *Modifier* is dropped when a fresh *Nouvelle Commande* starts —
  no stale lines from a previous order.

**Stability**
- Global error handler: any unexpected failure shows *"Une erreur est survenue —
  réessayez"* instead of a dead button.
- 10 context-after-await crash guards, controller leaks fixed, ~6 dead files removed
  (warnings 6 → 0), one spelling for the PIN-mode storage key, debug-only logging.
- Games screen no longer queries the database every second (~10× fewer queries).

**Platform & live behavior**
- Android: `POST_NOTIFICATIONS` permission asked once, growing notification IDs,
  everything Android-guarded; the *"Partie terminée"* alert is actually wired up.
- Settings and users apply **immediately** — no app restart.
- Navigation can no longer reset to home on a root redraw.
- Version identity published: `2.0.0+20002` (versionName/versionCode for Android).
- First APK build pipeline set up (see *Building* below); 5 unused packages removed.

---

## Important operating notes

- **Distribution is manual**: send the APK to the tablet and install it
  (Android will ask to allow installs from that source). There is **no Play Store**.
- **Signing key = the app's identity.** A tablet only accepts an *update* if it is
  signed with the same key as the installed app. APKs built from this project are
  signed with the build machine's key (`debug.keystore`); the file
  `cle-de-signature-easify.keystore` is the app's "rubber stamp" — **keep a copy
  somewhere permanent**, or a future build machine can never update tablets
  installed from this one. Tablets running an app signed by a *different, lost* key
  simply refuse new installs — nothing on them is damaged.
- **Data locations**: Windows database lives in `%LOCALAPPDATA%\Easify\objectbox`
  (outside OneDrive/Documents); on Android it is app-private storage. The in-app
  **Sauvegarde** button is the way to copy data between devices.
- **Release vs. development builds**: release builds skip Flutter assertions —
  bugs can be silent there and loud on desktop dev builds. Test on the real target.
- **Business day**: day boundaries come from `StoreConfig` (standard midnight or
  the hours mode). Changing the hours re-anchors *today*, not history.

---

## Building

### Prerequisites
- Flutter 3.47.x (stable)
- **Windows build**: Visual Studio Build Tools 2022 (Desktop development with C++)
- **Android APK**: JDK 17 + Android SDK (platform 36, build-tools 36).
  On this machine: JDK at `C:\dev\android-tools\jdk\jdk-17.0.20.1+1`,
  SDK at `C:\dev\android-sdk` (already configured via `flutter config --android-sdk`).

### Windows (debug)
```powershell
flutter pub get
flutter build windows --debug
# stop any running Easify.exe first (a running exe blocks the linker)
# run: build\windows\x64\runner\Debug\Easify.exe
```

### Android (release APK)
```powershell
$env:JAVA_HOME = 'C:\dev\android-tools\jdk\jdk-17.0.20.1+1'
$env:Path = "$env:JAVA_HOME\bin;$env:Path;C:\dev\flutter\bin"
flutter build apk --release
# → build\app\outputs\flutter-apk\app-release.apk  (~72 MB)
```
> The Android template is pinned to Flutter 3.47 minimums: Gradle 8.14.3,
> Android Gradle Plugin 8.11.1, Kotlin 2.2.20 (`android/settings.gradle.kts`,
> `android/gradle/wrapper/gradle-wrapper.properties`).

### Tests & analysis
```powershell
# always pass explicit test files (bare `flutter test` is not used)
flutter test test\batch1_printing_test.dart test\batch2_extras_test.dart test\batch2_money_parser_test.dart `
  test\batch3_business_day_test.dart test\batch4_backup_and_guards_test.dart test\p63_history_today_test.dart `
  test\batch5_auth_and_errors_test.dart test\batch6_platform_and_live_test.dart
flutter analyze   # baseline: 0 errors / 0 warnings / ≤178 infos
```

---

## Repository documentation

| Document | Purpose |
|---|---|
| [PROBLEMS.md](PROBLEMS.md) | The 63-problem audit list with status + decisions log (owner's calls recorded) |
| [HANDOFF_NEXT_SESSION.md](HANDOFF_NEXT_SESSION.md) | Session rules, baselines, next steps |
| [PDR.md](PDR.md) | Product design requirements |
| [UI_MODERNIZATION_PLAN.md](UI_MODERNIZATION_PLAN.md) | UI/theme direction |
| `BATCH*_PLAN.md` / `TEST_BATCH*.md` | Per-batch implementation plans and owner test checklists |
| [AUDIT_EASIFY_2.0.0.2.md](AUDIT_EASIFY_2.0.0.2.md) | Original code audit |

## Known gaps / roadmap

- **P21** — categories are linked to products by name (rename/delete needs care);
  next-batch candidate.
- **P20** — database indexes (deferred: requires ObjectBox code regeneration).
- **P46** — repository-layer consolidation (deferred; refactor risk over live data).
- **Section D UI pass** — theme/palette decision, chart labels, localisation of
  hardcoded strings, image fallbacks, multi-select in management.

---

Proprietary software — all rights reserved.
