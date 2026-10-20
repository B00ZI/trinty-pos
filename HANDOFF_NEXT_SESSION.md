# HANDOFF — next session starts here (created 2026-10-19, after batch 3)

**Read this file first, then `PROBLEMS.md` fully, before saying anything to the owner.**
Everything the owner cares about is recorded in `PROBLEMS.md` (P01–P63 + Decisions log);
the file-level audit detail is in `AUDIT_EASIFY_2.0.0.2.md`. This file = the glue:
workflow rules, environment commands, what's done, what's next.

---

## 1. The owner & the workflow (their explicit rules — follow exactly)

- Owner writes informal English, wants **very simple explanations with concrete shop
  stories** ("one day at the café…"), **one plain question at a time**.
- **Nothing changes without approval.** Per batch: explain the problems (what / real-life
  notice / how to see it now / what the fix does) → **wait** → owner says "do batch N" /
  "go" → then implement + test + build + restart + document + commit.
- Problems found while testing are **explained first, fixed only on the owner's say**
  ("find the problem and wait for my say"). The one carried question (P63) was answered
  on 2026-10-20 ("yes it should, you can do that now and close P63") and is now fixed —
  no open questions are being carried; ask about anything new, one at a time.
- UI/design problems are **deferred** to a later UI pass (Section D rows).
- Owner tests personally between batches; always write a `TEST_BATCHN.md` checklist.
- All work happens in this worktree on branch **2.0.0.3**. Branch `2.0.0.2`
  (`9db66ec`, production) and the original folder `C:\Users\HP\Documents\bozi\trinty-pos`
  are **never modified**.

### Product facts that are BY DESIGN (do not "fix" these)

- **Double print**: a normal sale prints **2 copies** (client + kitchen/saving);
  "Ticket Simple" = 1 copy. Print feedback must be **instant**.
- **PIN philosophy (P05)**: PIN = optional deterrent for destructive/admin actions only,
  default `0000`, **no lockout** — deliberate.
- **Market**: small cash-only businesses in Marrakech — no card payment. Promotions,
  freebies for friends and pay-later customers are everyday features. French UI, DH.
- **The owner uses the app mainly on ANDROID tablets** (stated 2026-10-20, batch 6) —
  the Windows build here is the dev/test mirror. Any platform-specific work must
  respect Android first. **Open question with the owner**: how do they install APKs
  today? This machine has **no Android SDK** (`flutter doctor` ✗), so no APK can be
  built here yet.
- Release builds (tablets) **skip Flutter assertions** — bugs can be silent there,
  loud in Windows debug (P59 lesson).
- **Extras are per-unit (P61, owner's option B)**: an extra's count applies to every
  unit ("2 thé lait" = 2 lattes); a line with extras is closed (tapping its product
  starts a new line); marker = `"__v": 2` inside the per-line `extraQuantitiesJson`
  (no schema change); old lines without the flag keep the old rule forever.
- **One money formula**: always `PricingService.calculateItemTotal` (snapshot extras).
- **Business day (P19/P27/P28)**: the day boundary lives in
  `StoreConfig.dayStartHour/Minute`; "hours" mode remembers the owner's 2 answers in
  SharedPreferences (`biz_day_mode`, `biz_open_h/m`, `biz_close_h/m`); reset =
  middle of closed hours (`BusinessDayHelper.resetFromHours`); `dayEnd*` fields are
  **dead, never read**; every range query is **end-exclusive `[start, end−1ms]`**.
  Default 00:00 shops behave exactly like stock.

## 2. Environment & commands (this machine)

- Worktree: `C:\Users\HP\Documents\bozi\trinty-pos-2.0.0.2` (Windows, PowerShell).
- Build & run:
  `$env:Path = "$env:Path;C:\dev\flutter\bin"; flutter build windows --debug`
  → `Stop-Process -Name Easify -Force -ErrorAction SilentlyContinue`
  → `Start-Process "...\build\windows\x64\runner\Debug\Easify.exe"`.
- Analyze: exits code 1 when infos exist (**normal**); PowerShell shows harmless
  NativeCommandError noise on stderr. Baseline: **155 infos / 0 errors / 0 warnings** —
  stay ≤ 178 infos, 0 errors.
- Tests: **always pass file paths explicitly**
  (`flutter test test/batch1_printing_test.dart test/batch2_extras_test.dart
  test/batch2_money_parser_test.dart test/batch3_business_day_test.dart
  test/batch4_backup_and_guards_test.dart test/p63_history_today_test.dart
  test/batch5_auth_and_errors_test.dart test/batch6_platform_and_live_test.dart`) —
  bare `flutter test` hung once, and there is no `test/objectbox_test.dart`
  (`test/widget_test.dart` was deleted in batch 6 — broken template). Baseline:
  **84/84 pass**.
- Real-store tests need `objectbox.dll` on PATH:
  add `;C:\Users\HP\Documents\bozi\trinty-pos-2.0.0.2\build\windows\x64\runner\Debug`
  to `$env:Path` before `flutter test`; without it the batch3 store group **skips
  itself** (declared skip, not a failure).
- **build_runner codegen HANGS on this machine** (stuck ~222/260; kill with
  `taskkill /F /IM dart.exe`). **Never** require `objectbox.g.dart` regeneration —
  all fixes use in-place JSON/flags instead of schema changes.
- Live app DB: `%LOCALAPPDATA%\Easify\objectbox`. To dump it: stop Easify first
  (ObjectBox locks exclusively), open via a temporary flutter test using
  `Store(getObjectBoxModel(), directory: <path>)`, then delete the temp test.
- Owner's current app state (2026-10-19 22:16): **"hours" mode active with reset
  09:00** left over from their own B2/B3 test; they were told how to switch back to
  "Jour standard". Test data: orders #17–#35 dated 19/10 (orders #1–#16 deleted
  earlier). **Batch-6 build running since 2026-10-20 19:17** (owner is testing
  P51–P57 with `TEST_BATCH6.md`).
- Test helper added in batch 4: `ObjectBox.attach(Store)` wraps a manually opened
  store with the app's boxes (used by the real-DB tests; no schema/codegen impact).

## 3. What is DONE (commits on 2.0.0.3, oldest → newest)

| Batch | Commit(s) | Contents |
|---|---|---|
| Batch 1 | `dbf89d8` `1adb67b` `f1144f4` `13dee17` `8d28898` | P13 P14 P16 P29 P31 P32 P33 P35 P36 P37 ✅ (P34 ⚠️ keep) — receipts & printing; two-copy preserved; connect-inside-try; instant "Ticket envoyé"; empty IP/port optional |
| Batch 2 | `d5f5afa` `1111073` `df3e92b` `e182771` | P15 ✅ (extras snapshot) · P22 ✅ (deleted products still count) · P17 ✅ (comma money + "Montant invalide"; tracking = NONE by owner decision) · P18 ✅ (shared MoneyParser, `$`→DH) · P60 ✅ (day-dialog revenue → PricingService) · cart line display (base/extras/Total rows) · **P61 = option B** per-unit extras |
| P62 (found by owner while testing P61) | `fa1ee24` | extra − button targets its own line (was dead outside extras mode; could hit wrong line) |
| Batch 3 | `191a952` | **P19 ✅ P27 ✅ P28 ✅** — one clock for the whole app: funds/expenses/day-dialog/units-sold/auto-clean on the business day (P19b fixed along the way); settings = owner's 2-questions idea with calculated reset (P27); end-exclusive ranges everywhere + picker stores exclusive end (P28). 13 new tests |
| Batch 4 | `b0c5615` + P63 follow-up (same session) | **P23 ✅ P24 ✅ P26 ✅ P30 ✅ P63 ✅** — cart from an old order dropped on a fresh Nouvelle Commande (drafts kept); paid game = order+counter+session+link in ONE sealed tx (both spots); **real full backup v2** (one Sauvegarde button → Exporter/Importer, export by sections, import asks "Ce fichier contient…" first, never wipes, no Wi-Fi password in files, v1 files still import); price 0 ok / negative refused / unique names (products, categories, users — `service/input_rules.dart`); **P63** Histoire snaps to today on open *and* when an old instance is uncovered, plus an "Aujourd'hui" button while browsing. 21 new tests (19 + 2 widget tests) |
| Batch 5 | `37a7e51` | **P42 ✅ P43 ✅ P44 ✅ P45 ✅ P47 ✅ P49 ✅ P50 ✅** — global error handler (`runZonedGuarded` + `PlatformDispatcher.onError` + `FlutterError.onError` → "Une erreur est survenue — réessayez", rate-limited; ErrorBoundary plugged in via `MaterialApp.builder`); 10 context-after-await guards; `dispose()` on all held controllers + dialog fields; dead code deleted (`providers/game_session_provider.dart`, `widgets/bestSellr.dart` incl. its shadowing Product, `comment_dialog.dart`, `order_details.dart`, route `/order/edit/:orderId`, `AuthService.getUsers/verifyPin`, `_printTextLogo`, `_formatPaymentMethod`, unused imports → **6 warnings → 0**); **P47** `setAuthMode`/`getAuthMode` share ONE spelling `per_order` (reader also accepts old `perOrder`) — "PIN par commande" cannot forget itself; **P49** router traces + receipt logging debug-only; **P50** games clock ticks via `ValueNotifier` (only the 2 moving lines rebuild), sessions cached, DB asked ≤ every 10s (~360 queries/hour instead of ~3,600). 7 new tests (`test/batch5_auth_and_errors_test.dart`) |
| Batch 6 | (commit of 2026-10-20, see git log) | **P51 ✅ P52 ✅ P53 ✅ P54 ✅ P55 ✅ P56 ✅ P57 ✅** — owner stated the app is used **mainly on Android tablets**. P53 closed (already in git since batch 2); P55 broken template test deleted; P54 pubspec = real identity (`2.0.0+20002`, French description, 5 dead packages removed); P56 router built ONCE (held by Easify state) + Histoire→Modifier through go_router; P57 live providers (`storeConfigProvider`/`printerConfigProvider`/`allUsersProvider` — settings & users apply immediately, no restart); P51 dev-panel export buttons deleted (Android-only folder, silent no-op on Windows) + `cancelSessionNotification` deleted; **P52** Android: manifest `POST_NOTIFICATIONS`, permission asked once before first alert, growing notification IDs (was `millisecond` 0–999), everything Android-guarded + try/catch, "Partie terminée" alert finally wired to the games auto-end. 6 new tests (`test/batch6_platform_and_live_test.dart`) |
| Earlier (pre-batch, security/DB) | per Decisions log in PROBLEMS.md | P01 ⚠️ keep · P02 ✅ · P03 ✅ (dev panel PIN 9999) · P04 ✅ (PIN-gated maintenance) · P05 ⚠️ by design · P06 ✅ · P07 ✅ (desktop DB in %LOCALAPPDATA%) · P08 ✅ fail-closed activation · P09 ⚠️ · P10 ⚠️ (owner must back up debug.keystore) · P11 ❌ not a problem · P12 ✅ transactions · P59 ✅ category dropdown crash |

## 4. What's NEXT (in order)

1. **Owner tests batch 6** with `TEST_BATCH6.md` (live settings, navigation,
   dev panel). Fix only what they report, on their say.
2. **The APK question (asked 2026-10-20, awaiting answer)**: how does the owner
   install APKs on the Android tablets today? No Android SDK on this machine —
   if he wants, install the SDK here and add "build APK" to the workflow.
3. **Leftovers, individually yes/no**: P20 (ObjectBox indexes — **codegen risk: requires
   objectbox.g.dart regeneration which HANGS; propose deferring or doing on another
   machine**), P21 (categories linked by name — note P30 now blocks duplicate category
   names, which shrinks it), P46 (repository layer drift — recommend defer), P48
   (pointycastle override in license path — keep, owner decided).
4. **Section D UI deferrals** (later UI pass): P25 P38 P39 P40 P41 P58.
   Note from P51: if the owner ever wants fancy fonts offline on tablets,
   bundle google_fonts TTFs as assets (needs a yes).

## 5. Per-batch definition of done

1. Implement (in-place flags/JSON only — no schema changes, no codegen).
2. New/updated unit tests in `test/batchN_*.dart`; all previous tests still pass.
3. `flutter analyze` ≤ 178 infos, 0 errors.
4. `flutter build windows --debug`, stop old Easify, start new one.
5. Update `PROBLEMS.md` rows + Decisions log entry (with the owner's own words when
   they made the call); write `TEST_BATCHN.md` checklist (simple steps, French UI
   labels, expected results).
6. Commit with a descriptive message referencing the P-numbers.

Files that are the "spine" of the app for money/time:
`lib/service/pricing_service.dart` (money), `lib/service/business_day_helper.dart`
(days), `lib/repositories/order_repository.dart` + `expense_repository.dart` +
`funds_repository.dart` (all end-exclusive ranges), `lib/models/order_item.dart`
(extras JSON + `__v:2`), `lib/providers/order_provider.dart` (cart), 
`lib/service/money_parser.dart` (input parsing).
