# Full Code Audit — Easify POS, branch 2.0.0.2

Date: 2026-10-17 · Scope: `C:\Users\HP\Documents\bozi\trinty-pos-2.0.0.2` @ `9db66ec`
Stats: 14,497 lines of Dart across 77 files · 1 (broken) test · 7 `print()` · 7 TODO/FIXME
Audited: architecture/state, data/business logic, security, integrations/UI.

---

## App wiring (how it works)

`main()` → timezones → `NotificationService.init()` → `ObjectBox.create()` → seeds
`OrderCounter` + admin user **PIN `0000`** → `ProviderScope` → GoRouter (flat, **no
redirect/guards**) → `NavigationHubScreen` which checks activation (RSA vs embedded key)
and session-auth **inside the screen**, not the router. Repositories exist but only the
dashboard/order chain uses them; history, games, management, settings hit ObjectBox boxes
directly. State = Riverpod StreamProviders **mixed with** inline `StreamBuilder`s **mixed
with** raw `setState`. Screens push sections via `context.push`.

---

# 🔴 CRITICAL

**SEC-1 · The licensing RSA *private* key ships in the app — and the repo is PUBLIC.**
`lib/service/activation_service.dart:25-53`. Confirmed live on
`https://github.com/B00ZI/trinty-pos` (raw file on `main` contains it). Anyone can mint
valid keys for any device offline. The verifier itself *signs with it* (`:127-130`), so it
cannot be removed without redesign. **The key must be considered permanently burned.**

**SEC-2 · The app prints the correct activation key on a wrong guess.**
`activation_service.dart:107`: `print("Short Key mismatch: input=… expected=$cleanExpected")`
— one junk entry reveals the valid key (stdout/logcat). Also prints the device fingerprint
(`:84`, added by our desktop patch) and `activation_dialog.dart:25`.

**BUG-1 · Every order gets stuck on order number 1 (fresh install).**
`main.dart:23-26` seeds `OrderCounter(value: 1)` → id **0** (entity is
`@Id(assignable:true)`); `order_repository.dart:79-94` reads `counters.first` (the id-0 row)
but writes a **second row** `OrderCounter(id: 1, …)`. Games screen has a **third** variant
(`games_screen.dart:127-149`). Result: duplicated/stuck receipt numbers, and the
dev-panel "missing order numbers" feature is built on sand.

**BUG-2 · Confirming an order prints the ticket TWICE, and takeaway/comments never print.**
`order_screen.dart:1094-1104`: `if (!singleTicket) printReceipt(...)` with **no `else`**,
then a second print after a 1 s delay → 2 tickets per sale. Worse, `clearCart()` runs at
`:1000` **before** `_printReceipt` reads the cart at `:1054` → `isTakeAway` and `comment`
are already cleared → **every takeaway order prints as dine-in; kitchen comments lost.**

**BUG-3 · Order edit can permanently destroy an order.**
`order_screen.dart:963-976` (+ duplicate at `:1018-1030`): put order with ZERO items →
hard-delete old items → re-insert. **Zero `store.runInTransaction` calls in the entire
app.** Crash between steps = order with no lines, items gone.

**BUG-4 · Reprinted receipts show wrong money.**
8 different revenue formulas exist and disagree (see MED-1). The reprint path
`printer_helper.dart:71-93` uses `quantity × product.target.price` — ignores the persisted
`item.price` and **ignores extras entirely**; deleted product → total 0.00 "Unknown Product".

**SEC-3 · Full data wipe with no PIN.**
- Long-press the "Historique" hub card (`navigation_hub_screen.dart:146-188, 288`) →
  `removeAll()` on Order/OrderItem/GameSession/Expense/DailyFunds after a yes/no only.
- Dev panel (`:373-411`) same, behind **5 taps on the title, no PIN** (`:101-115`).

**SEC-4 · Dev panel ships in RELEASE**: DB export, SQL dump **including PIN hashes and the
store Wi-Fi password** (`dev_panel_screen.dart:256-371`), per-staff revenue, delete-all —
reachable by anyone who taps the title 5×. No `kDebugMode` guard anywhere.

**PRN-1 · Printer crashes (Latin-1 encoder).** `esc_pos_utils` encodes with `latin1`; any
`✅`, `œ`, `€` > 0xFF throws `ArgumentError`:
- `printer_helper.dart:520` `'✅ Connection: OK'` → **"Imprimer un test" is broken**.
- Same crash mid-receipt for any product/comment with `œ`/`€`/emoji.
- No printer configured → `printerConfigBox.getAll().first` throws `StateError`
  (`printer_helper.dart:142`); **all 8 print call sites are unawaited/uncatched**.

**PDR-1 · Design spec violated ~100%.** PDR mandates ONLY `#FFFFFF / #EDF5FC / #2D7DD2 /
#210124`. Current branch: **0 occurrences** of the palette; theme rebuilt around teal
`#1F7A6C` + 44 off-palette colors in `lib/theme/app_colors.dart` (462 references app-wide).
`UI_MODERNIZATION_PLAN.md:747-749` documents this as *intentional*.
**PDR-2 · Order-card sizes changed anyway** (explicit "DO NOT change" rule): product grid
`childAspectRatio 0.55→0.65`, category `0.75→0.85`, cart 300→200-340, buttons 48→52 —
all in commit `9db66ec`.

**PAY-1 · Payment dialog is cosmetic.** `payment_dialog.dart:40-66`: French decimal comma
(`12,5`) → `FormatException` swallowed → change display vanishes but **Valider stays
enabled**; underpayment can be validated; **received amount, change and payment method are
never persisted** (receipt hardcodes `'cash'`) → cash reconciliation impossible.

---

# 🟠 HIGH

**SEC-5** Default admin PIN `0000` (`main.dart:32-39`), **no lockout/attempt limit** in
`AdminPinDialog` (auto-submits on 4th digit) → 10,000 PINs exhaustible in hours. Only the
Security tab, Dashboard and user CRUD are PIN-gated; **pricing, Wi-Fi password, business-day
hours, printer config and all of Management are NOT.**

**SEC-6** ObjectBox DB **unencrypted at rest** in `Documents\…\objectbox\` — PIN hashes,
Wi-Fi password, all revenue. On Windows the *activation key* is DPAPI-protected (good), the
rest is not.

**DATA-1** **8 revenue formulas** that disagree once extras/surge/edits/deletions are in:
`CartLine.total`, `PricingService`, history's own copy, receipt fold, reprint (BUG-4),
weekly chart (no extras), day-brief, dev panel. Day brief **double-counts game revenue**
(includes running + prepaid sessions; `printer_helper.dart:652-681`).

**DATA-2** Extras priced from the **live** Product row (`pricing_service.dart:14-18`) →
editing an extra's price **retroactively changes past orders' totals**; base prices are
snapshotted, extras are not.

**DATA-3** **Business-day vs calendar-day split brain**: dashboard uses business day,
funds/expenses/weekly chart use midnight → numbers don't reconcile between screens with a
04:00/06:00 day start. Bonus: `getTodayFunds` falls back to **yesterday's** float
(`funds_repository.dart:30-41`).

**DATA-4** **No indexes** on `Order.date`, `Expense.date`, `GameSession.startTime`,
`Product.category`, `name` fields → full-table scans on every dashboard/history/chart
refresh; charts run 14 queries per change.

**DATA-5** Categories linked **by name string**: rename/delete a category → products
orphaned; category edit drops `displayOrder` (resets ordering); duplicate names allowed.

**DATA-6** Product deletion dangles relations → historical revenue can become **0.00**
(`pricing_service.dart:10`).

**DATA-7** Stale cart: editing a past order then "Nouvelle Commande" reuses the edited
lines (edit branch never calls `clearCart`, `order_screen.dart:963-984`) → double-charge risk.

**DATA-8** Game↔order link written in a second `put` (no transaction) → crash window makes
the dashboard **count the sale twice** (`games_screen.dart:147-160`).

**PERF-1** Games screen: `Timer.periodic(1 s)` + `setState` → recreates 3 inline
`StreamBuilder` query streams **every second**, and builds a new un-closed ObjectBox `Query`
per tick (`games_screen.dart:33-58, 358-431`) → ~3,600 leaked query handles/hour.

**WIN-1** Windows gaps: dev-panel export **broken** (`getExternalStorageDirectory()`,
Android-only); `NotificationService.show/cancel` would throw `LateInitializationError`
(**dead code — zero callers today**); `google_fonts` needs network on first paint;
Android side lacks `POST_NOTIFICATIONS` (Android 13+).

**ROB-1** No `runZonedGuarded`/`FlutterError.onError`/`PlatformDispatcher.onError`;
`ErrorBoundary` widget exists but is **never used** → all async failures are invisible
"button does nothing" states. No loading/disabled state on any action button → double-tap
creates **empty orders** (`order_screen.dart:786, 816`) and parallel sockets.

**GIT-1** **`windows/` and `tool/` are NOT in git** → fresh clone cannot build Windows.
Repo also carries stale `analysis_output*.txt`. Android release is signed with the **debug
keystore** and `applicationId com.example.Easify`.

---

# 🟡 MEDIUM (selection)

- **MED-1** All money is `double`; only display rounding. No int-cents anywhere.
- **MED-2** No French number handling: `double.parse` rejects `12,5` → **silently saves 0.00**
  in funds (`daily_funds_dialog.dart:39`), surge amount (`settings_screen.dart:907`), etc.
  Display uses dot + `' DH'`; expense widget shows **`$`** (`expense_tracking.dart:371`).
- **MED-3** Chart trend labels **hardcoded fiction**: `'+ 12.5%'`, `'+ 8.4%'`, `'+ 18.7%'`
  (`charts.dart:209,224,238`) shown next to real numbers.
- **MED-4** Dead code inventory: 5 dead providers (`game_session`, `auth`, `navigation`,
  `product`, `settings`), 5 dead widgets (`bestSellr` — which declares a **shadowing
  `Product` class** —, `comment_dialog`, `dialog.dart`, `error_boundary`, `order_details`),
  dead route `/order/edit/:orderId`, dead `AuthService.setAuthMode` (writes `perOrder`,
  reads `per_order` → latent round-trip bug), dead notification/sound methods.
- **MED-5** Repository layer half-adopted → same rules implemented 3-4× and drifting.
- **MED-6** French/English mix (~280 hardcoded French strings, some English:
  "Add expense", "Revenue Overview", "Order not found"). No `.arb` → not localizable.
- **MED-7** `TextEditingController`s never disposed (settings: 8 controllers, 0 `dispose()`).
- **MED-8** `dependency_overrides: pointycastle ^4.0.0` forces `encrypt`/`rypton` onto an
  untested major version (they declare 3.x) — in the *license-signing* path.
- **MED-9** Latent fail-open: if key parsing ever throws, expected key = literal `"ERROR"`
  → typing `ERROR` **activates the app** (`activation_service.dart:135-138`).
- **MED-10** `debugLogDiagnostics: true` + `debugPrint` receipt dumps in release.
- **MED-11** Backup ("Sauvegarde") exports **only products+categories** — no orders, users,
  expenses — but users will assume full backup; import silently overwrites by name.
- **MED-12** Business-day **end time setting is a no-op** (`business_day_helper.dart:16`).
- **MED-13** `between()` inclusive boundaries → orders exactly at midnight can count twice.
- **MED-14** Printer config save = `removeAll()` then `put()` — crash between = no printer.
- **MED-15** pubspec: `version: 1.0.0+1` on "2.0.0.2", package name `Easify` invalid for
  pub, description still "A new Flutter project.", unused deps (`network_info_plus`,
  `charset_converter`, `mrx_charts`, `cupertino_icons`), legacy `flutter_icons` key,
  `frita.png` declared but unused, `icon.png` undeclared.
- **MED-16** Missing `mounted` checks after awaits in ~5 spots (settings PIN/printer test,
  history PIN, order auth, games).

---

# 🟢 LOW / INFO (things to know)

- **Tests**: only `test/widget_test.dart` — missing `ProviderScope`, asserts text that is
  never rendered, opens a real store and never closes it → decorative/broken.
- **Responsiveness at 1280×800 is genuinely good** (OrientationBuilder/LayoutBuilder,
  no fixed ≥500px containers, everything scrolls).
- **No stock/inventory, no discounts, no refunds/audit trail** (deletion = soft delete with
  no deleted-by/restore).
- **Migration v1→2.0.0.2 is safe** *if* `lib/objectbox-model.json` is preserved — entity
  renames (Ruci→Order, expence→Expense, Catigory→Category) keep explicit UIDs; several
  entities have **no explicit uid in source**, so deleting that file = orphaned data.
- PIN hashing = salted SHA-256 with legacy-upgrade — the best-hardened corner of the app
  (still weak vs a real KDF, but fine for a POS).
- `flutter_secure_storage` on Windows = real DPAPI encryption (only stores the activation key).
- `share_plus` v12 **does** support Windows (earlier assumption wrong); calls are try/caught.
- Notification IDs use `DateTime.now().millisecond` (0-999) → collisions if ever used.
- `_printSingleTicket` never sets `order.user` → "UNASSIGNED" orders skew per-staff stats.
- Receipt line prices use **current** product price while totals use persisted price →
  lines don't sum to total after a price edit.
- Default admin `0000` is verified against *any* admin row (first match wins).
- Seeded `OrderCounter` also powers the dev panel's "missing order numbers" — fix BUG-1 first.

---

# Recommended fix order

1. **SEC-1/SEC-2** — remove key-printing `print()`s now; redesign licensing (key is burned).
2. **BUG-1** order counter (receipts are wrong *today* on fresh installs).
3. **BUG-2** print-once + read cart before clearing; **PRN-1** emoji/latin1 + empty-config guard + await/catch at 8 call sites.
4. **SEC-3/SEC-4** PIN-gate + `kReleaseMode`-strip the dev panel and hub long-press wipe.
5. **BUG-3** wrap order edit / game-order link / counter increments in `runInTransaction`.
6. **DATA-1/2** one authoritative persisted `Order.total` + snapshot extra prices (kills 6 of 8 formulas).
7. **PAY-1** locale-safe parsing + persist received/change/method.
8. **DATA-3/4** unify business-day helper + add indexes.
9. **PDR-1/2** restore palette + card ratios *if* the blue spec still governs this version.
10. **GIT-1** `git add windows/ tool/`; bump pubspec version; drop unused deps.
