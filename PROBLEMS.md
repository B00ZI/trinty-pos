# PROBLEMS.md — Easify POS · full problem list (branch 2.0.0.3)

**Source:** full audit of branch `2.0.0.2` (see `AUDIT_EASIFY_2.0.0.2.md` for file:line detail).
**Workflow:** we go one problem at a time. For each: I explain it simply → you decide:
`✅ fix it` · `⚠️ by design — <your real-world reason>` · `📋 later` · `❓ question`.
Your decision is recorded in the Status column. Nothing is changed without your approval.

**Legend:** 🔴 critical · 🟠 high · 🟡 medium · 🔵 low — severity = impact if it bites, not effort.

---

## A. Security & licensing

| ID | Problem (short) | Sev | Where | Status | Your decision / reason |
|----|------------------|-----|-------|--------|--------------------------|
| P01 | App contains its own license **signing key**; code is on a **public** GitHub repo → anyone can make activation codes for any device | 🔴 | activation_service.dart:25-53 | ⚠️ by design | Keep as-is: offline licensing, manual client installs; changing the key flow would conflict with the existing app / register-pin workflow used by recent + main apps |
| P02 | Entering a wrong activation key **prints the correct key** in the log; fingerprint also logged | 🔴→🟡 | activation_service.dart:84,107 | ✅ fixed | You approved: removed `expected=` leak, all prints now `kDebugMode`-only (dev builds still show them) |
| P03 | Dev panel ships in release: 5 taps on title → export DB/SQL (**PIN hashes, Wi-Fi password**), delete all data — no PIN | 🔴 | navigation_hub_screen.dart:101-115, dev_panel_screen.dart | ✅ fixed | You approved: 5 taps now open a PIN keypad, panel opens only with code `9999` (`AdminPinDialog.verifyFixedCode`) |
| P04 | Long-press "Historique" card → **wipe every sale** with only a yes/no dialog, no PIN | 🔴→✅ | navigation_hub_screen.dart, widgets/maintenance_section.dart, service/history_cleanup_service.dart | ✅ fixed | You approved: long-press removed; new Settings → **Maintenance** section (PIN-gated) with auto-retention (OFF/30/90/180/365 j, runs at startup) + manual cleanup (older than X / keep today / delete all) behind the **admin PIN**; `9999` stays dev-panel-only |
| P05 | Default admin PIN is **0000**, no lockout/attempt limit (10,000 combos = guessable in hours) | 🟠 | main.dart:32-39, admin_pin_dialog.dart | ⚠️ by design | Keep as-is: onboarding is your manual demo and most clients hand the code to their staff anyway — PIN is an optional deterrent; you advise clients to set a stronger code if they want to block admin/deletion actions |
| P06 | Only Security tab + Dashboard are PIN-gated; **pricing, Wi-Fi password, business-day, printer settings, full product CRUD are open** | 🟡→✅ | settings_screen.dart, management_screen.dart | ✅ fixed | You approved the selective gate: admin PIN on **product delete** + **category delete** (create/edit stay free); **Wi-Fi password masked** with tap-to-reveal; operational settings stay open (consistent with your P05 model) |
| P07 | Database file unencrypted in Documents (PIN hashes, revenue); **Wi-Fi password stored plaintext** | 🟡 | objectbox.dart, store_config.dart | ⬜ | |
| P08 | Latent fail-open: if key parsing ever throws, expected key = literal `"ERROR"` → typing ERROR activates the app | 🟡 | activation_service.dart:135-138 | ⬜ | |
| P09 | Windows fingerprint uses Windows **DigitalProductId** → re-activating/reinstalling Windows can lock a customer out; cloned VMs share one key *(our desktop patch)* | 🟡 | activation_service.dart:78-86 | ⬜ | |
| P10 | Android release signed with **debug keystore**, app id `com.example.Easify` (Play Store rejects; anyone can re-sign) | 🔵 | android/app/build.gradle.kts:23,30-34 | ⬜ | |

## B. Orders, money & data

| ID | Problem (short) | Sev | Where | Status | Your decision / reason |
|----|------------------|-----|-------|--------|--------------------------|
| P11 | **Order numbers stuck at 1** on fresh installs: 3 competing counter implementations (seed id 0 vs write id 1 vs games' own) | 🔴 | main.dart:23-26, order_repository.dart:79-99, games_screen.dart:127-149 | ⬜ | |
| P12 | Editing an order = 3 separate writes, **no transaction anywhere in the app** → crash = order with zero items, old items deleted | 🔴 | order_screen.dart:963-976 | ⬜ | |
| P13 | Cart cleared **before** receipt is built → **takeaway flag & kitchen comment never print**; also prints **twice**; "Ticket Simple" orders save **without user** | 🔴 | order_screen.dart:1000-1104, 1013-1051 | ⬜ | |
| P14 | **8 different revenue formulas** that disagree; reprint ignores stored price + extras → reprinted receipts show wrong money (deleted product → 0.00) | 🔴 | printer_helper.dart:71-93 + 7 others | ⬜ | |
| P15 | Extras priced from **live** product price → editing an extra's price **retroactively changes past orders' totals** | 🟠 | pricing_service.dart:14-18 | ⬜ | |
| P16 | Printed daily report **double-counts game revenue** (running + prepaid sessions included) → TOTAL CA inflated vs dashboard | 🟠 | printer_helper.dart:652-681 | ⬜ | |
| P17 | Payment dialog: French comma `12,5` breaks change calc (Valider stays enabled anyway), **underpayment can be validated**, received/change/method **never saved** | 🔴 | payment_dialog.dart:40-66 | ⬜ | |
| P18 | All money = `double` (FP rounding), inputs reject French comma → silently save **0.00** (funds, surge); expense widget shows **$** in a DH app | 🟡 | daily_funds_dialog.dart:39, expense_tracking.dart:371 | ⬜ | |
| P19 | **Business day vs calendar day split brain**: dashboard uses business day, funds/expenses/charts use midnight → screens disagree; funds can show **yesterday's** float as today's | 🟠 | funds_repository.dart:18-41 vs dashboard_service.dart:31-36 | ⬜ | |
| P20 | **No indexes** on Order.date / Expense.date / session start / category → full table scans on every refresh (slow after months of sales) | 🟠 | objectbox-model.json | ⬜ | |
| P21 | Categories linked **by name string**: rename/delete a category → its products become unreachable; editing a category resets its sort position | 🟠 | management_screen.dart:496-500,594 | ⬜ | |
| P22 | Deleting a product leaves dangling links → **past revenue can show 0.00** | 🟠 | management_screen.dart:393, pricing_service.dart:10 | ⬜ | |
| P23 | Edit an old order → tap "Nouvelle Commande" → **cart still has the old order's lines** (double-charge risk) | 🟠 | order_screen.dart:963-984 | ⬜ | |
| P24 | Game order ↔ session link written as a separate 2nd save → crash in between = **same sale counted twice** | 🟠 | games_screen.dart:147-160 | ⬜ | |
| P25 | Dashboard chart trend labels are **hardcoded fiction** (`+12.5%`, `+8.4%`, `+18.7%`) shown next to real numbers | 🟡 | charts.dart:209,224,238 | ⬜ | |
| P26 | "Sauvegarde" (backup) only saves **products+categories** (no orders/users/expenses) but looks like a full backup; import silently overwrites by name | 🟡 | data_backup_service.dart:27-87 | ⬜ | |
| P27 | Business-day **"end time" setting does nothing** (start+24h hardcoded) | 🟡 | business_day_helper.dart:16 | ⬜ | |
| P28 | Midnight boundary: `between()` is inclusive → record exactly at the boundary counts in **two days** | 🟡 | order_repository.dart:54-55 + 4 more | ⬜ | |
| P29 | Printer config save = **delete all first, then write** → crash in between = no printer config left | 🟡 | settings_screen.dart:263-270 | ⬜ | |
| P30 | Validation: prices accept **negative/zero**; duplicate user names allowed | 🟡 | management_screen.dart:257, settings_screen.dart:448 | ⬜ | |

## C. Printing (thermal receipts)

| ID | Problem (short) | Sev | Where | Status | Your decision / reason |
|----|------------------|-----|-------|--------|--------------------------|
| P31 | Printer encoder is **Latin-1 only**: `✅`, `œ`, `€` → crash → **"Imprimer un test" button is broken**, receipt can die mid-print | 🔴 | printer_helper.dart:520,481 | ⬜ | |
| P32 | No printer configured → `StateError`; **all 8 print call sites unawaited/uncatched** → button silently does nothing | 🟠 | printer_helper.dart:142 + order/history/games/store_config | ⬜ | |
| P33 | On print error the **socket is never closed** → printer keeps 1 connection, later prints silently fail | 🟠 | printer_helper.dart:535-641, settings_screen.dart:277-296 | ⬜ | |
| P34 | French accents printed as raw Latin-1 with **no code-page switch** → é/à/ç wrong unless printer manually configured | 🟡 | printer_helper.dart (no ESC t) | ⬜ | |
| P35 | **No loading/disabled state on buttons** → double-tap = empty order + parallel printer connections | 🟠 | order_screen.dart:786,816 + others | ⬜ | |
| P36 | Logo/image decode + receipt rasterization run on the UI thread → frame stutter during printing | 🟡 | printer_helper.dart:292-404 | ⬜ | |
| P37 | Print failures swallowed (`return;` on non-success) → user never told the ticket didn't print | 🔵 | printer_helper.dart:548,602 | ⬜ | |

## D. Design / UI (possible deliberate choices)

| ID | Problem (short) | Sev | Where | Status | Your decision / reason |
|----|------------------|-----|-------|--------|--------------------------|
| P38 | PDR palette (blue #2D7DD2 etc.) replaced by **teal theme** — 0% palette compliance, 462 references. Documented as intentional in UI_MODERNIZATION_PLAN.md | 🔴* | theme/app_colors.dart | ⬜ | |
| P39 | **Order-card sizes changed** (aspect 0.55→0.65, cart/buttons resized) though PDR says "DO NOT change card sizes" — same commit | 🔴* | order_screen.dart:360,418 | ⬜ | |
| P40 | Not localizable: ~280 hardcoded French strings, no `.arb`; **some English** leaks in UI ("Add expense", "Revenue Overview") | 🟡 | throughout, expense_tracking.dart, charts.dart | ⬜ | |
| P41 | Product/category images: **no error fallback** → deleted file = broken/red tile on the main order grid | 🟡 | product_card.dart:53-57, category_card.dart:59 | ⬜ | |
| P58 | Product selection requires a **long-press** to enter select mode (edit/delete toolbar), and there's **no multi-select** — "why do I keep holding?" | 🟡 | management_screen.dart:354-399 | ⏸ deferred | Raised by you during P06 (2026-10-18): deferred to a dedicated UI/UX fixes pass |

*🔴* = violates the written spec; severity depends on whether that spec still governs.

## E. Robustness & code health

| ID | Problem (short) | Sev | Where | Status | Your decision / reason |
|----|------------------|-----|-------|--------|--------------------------|
| P42 | **No global error handler**; ErrorBoundary widget exists but unused → async failures = "button does nothing" | 🟠 | main.dart, widgets/error_boundary.dart | ⬜ | |
| P43 | `context` used after `await` without `mounted` check (5 spots) → crash on fast navigation | 🟡 | settings/history/order/games screens | ⬜ | |
| P44 | TextEditingController never disposed (settings: 8 controllers, 0 dispose) → leaks | 🟡 | settings_screen.dart, management_screen.dart | ⬜ | |
| P45 | **Dead code**: ~5 unused providers, ~5 unused widgets (incl. shadowing `Product` class), dead route, dead auth service methods | 🟡 | providers/*, widgets/bestSellr.dart etc. | ⬜ | |
| P46 | Repository layer half-adopted: history/games/settings bypass it → same rules implemented 3-4× and drifting | 🟡 | screens/* vs repositories/* | ⬜ | |
| P47 | `AuthService.setAuthMode` writes `perOrder`, `getAuthMode` expects `per_order` → latent round-trip bug | 🟡 | auth_service.dart:12-25 | ⬜ | |
| P48 | `dependency_overrides: pointycastle ^4.0.0` forces crypto libs onto an untested major version — **in the license-signing path** | 🟡 | pubspec.yaml:72-73 | ⬜ | |
| P49 | Release builds log navigation (`debugLogDiagnostics: true`) + receipt contents via debugPrint | 🔵 | router.dart:47, printer_helper.dart:177 | ⬜ | |
| P50 | Games screen: 1-second timer rebuilds everything + **leaks ~3,600 ObjectBox queries/hour** | 🟠 | games_screen.dart:33-58, 358-431 | ⬜ | |

## F. Platform & project hygiene

| ID | Problem (short) | Sev | Where | Status | Your decision / reason |
|----|------------------|-----|-------|--------|--------------------------|
| P51 | Windows gaps: dev-panel export broken (Android-only API), notification show/cancel would throw (dead code), Google Fonts needs network first paint | 🟡 | dev_panel_screen.dart:224,259 | ⬜ | |
| P52 | Android: no `POST_NOTIFICATIONS` permission (13+), notification IDs collide (millisecond 0-999) | 🔵 | AndroidManifest.xml, notification_service.dart:45 | ⬜ | |
| P53 | **`windows/` + `tool/` not in git** → nobody can build the desktop version from a clone | 🟠 | repo root | ⬜ | |
| P54 | pubspec: `version: 1.0.0+1` on "2.0.0.2", package name `Easify` invalid for pub, 4 unused deps, asset mess | 🟡 | pubspec.yaml | ⬜ | |
| P55 | Only 1 test exists and it's broken (missing ProviderScope, wrong expectation, leaks store) | 🟡 | test/widget_test.dart | ⬜ | |
| P56 | Router rebuilt inside `build()` (state loss on root rebuild), mixed Navigator/go_router, dead `/order/edit` route | 🟡 | main.dart:58, router.dart | ⬜ | |
| P57 | Stale non-reactive providers: `storeConfigProvider`/`allUsersProvider` one-shot → settings changes need app restart | 🟡 | settings_provider.dart:17-20, auth_provider.dart:21-24 | ⬜ | |

---

## Decisions log

| Date | IDs | Decision | Your reason / scenario |
|------|-----|----------|------------------------|
| 2026-10-17 | P01 | ⚠️ keep as-is | Offline licensing with manual client installs; key flow change would conflict with the existing app / register-pin workflow (recent + main apps) |
| 2026-10-17 | P02 | ✅ fixed | Removed `expected=` key leak + wrapped all activation prints in kDebugMode (dev builds still show them) |
| 2026-10-17 | P03 | ✅ fixed | PIN-gate the dev panel: 5 taps open the keypad, code `9999` opens the panel (owner keeps all tools) |
| 2026-10-18 | P04 | ✅ fixed | Quick-wipe existed because slow tablets need cleanup; replaced by Settings → **Maintenance**: auto-clean (owner picks OFF/30/90/180/365 j, runs at startup) + manual scoped clean behind the **admin PIN** (the PIN the owner sets in-app); `9999` stays dev-panel-only |
| 2026-10-18 | P05 | ⚠️ keep as-is | Manual demo onboarding; clients give the code to their staff anyway; PIN = optional deterrent — you advise clients to set a stronger code if they want protection |
| 2026-10-18 | P06 | ✅ fixed | Selective gate (your approval): admin PIN on product + category **delete** (create/edit free), Wi-Fi password masked with tap-to-reveal; operational settings stay open per the P05 model; you raised P58 (hold-to-select products) → deferred to UI/UX pass |
|      |     |          |                       |
