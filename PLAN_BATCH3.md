# PLAN — Batch 3: One clock for the whole app (P19 + P27 + P28)

Status: **WAITING FOR OWNER CONFIRMATION** — nothing is implemented yet.

Theme: today the app has several different meanings of "today" (business day on the
dashboard/history, plain midnight on funds/expenses/dialog). This batch gives the whole
app ONE boundary, chosen safely from the owner's working hours.

---

## Part 1 — P27: settings ask 2 questions, app calculates the reset (owner's idea)

### New settings screen (`lib/widgets/business_day_settings.dart` — rewrite)

Replaces the current "Début de journée" + dead "Fin de journée (Affichage)" pickers:

```
Paramètres de la Journée

○ Jour standard — réinitialisation à minuit
● Basé sur mes horaires

   Heure d'ouverture (généralement)   [ 16:00 🕐 ]
   Heure de fermeture (généralement)  [ 23:00 🕐 ]

   → Votre journée se réinitialise à 07h30
     (vous êtes généralement fermé à cette heure)

   ℹ Si vos horaires changent un jour, l'ancien découpage
     des jours change aussi — à régler une seule fois.

[ Enregistrer les Horaires ]
```

- The preview line updates live when a picker changes.
- The dead "Fin de journée" control is **removed** (it never did anything).

### The calculation (middle of the closed hours)

`reset = middle of the gap between closing and the next opening`

| Owner answers | Closed gap | Reset | Why it's safe |
|---|---|---|---|
| Café 16:00 → 23:00 | 23:00→16:00 | **07:30** | opens at 16h, 18h or 20h → still ONE day |
| Bar 22:00 → 04:00 | 04:00→22:00 | **13:00** | whole night = one day, labelled by the evening's date |
| Shop 10:00 → 19:00 | 19:00→10:00 | **02:30** | random late openings never split |
| Open 01:00 → 23:00 | 2h gap | **00:00** | tiny gap → midnight is already the quietest minute |
| Open = close (nonsense) | — | **00:00** | degenerate answer → fall back to midnight |

Formula (pure function on BusinessDayHelper → unit-testable):
`gapMinutes = (open + 1440 − close) % 1440; if gap == 0 → midnight; reset = (close + gap/2) % 1440`

### Storage (no database schema change, no codegen)

- **Boundary** (what all day logic reads): `StoreConfig.dayStartHour/dayStartMinute` —
  unchanged field, so `BusinessDayHelper` and every existing screen keep working as-is.
  Standard mode = 00:00 (same default as today → existing installs see zero change).
- **The owner's 2 answers + mode**: `SharedPreferences` (already used in the app)
  — UI-level memory only; day logic never needs them.
- `dayEndHour/dayEndMinute`: dead leftovers, never read again (kept in DB, harmless).
- First-run / migration: no `SharedPreferences` value yet → infer mode from boundary
  (00:00 = standard, anything else = "Sur mesure" — owner re-answers once; the preview
  shows the current boundary).

### What does NOT change internally

Day = boundary → boundary + 24 h (existing `getBusinessDayRange`). The batch only
changes **which boundary** gets stored and **which screens use it**.

---

## Part 2 — P19: every screen uses the same boundary

| Site | Today | After |
|---|---|---|
| `dashboard_service.dart` | business day ✓ | unchanged (only the P28 trim fix) |
| `history_screen.dart` | business day ✓ | unchanged (only P28 −1ms) |
| `funds_repository.dart` — `getTodayFunds` / `checkIfFundsExist` / `saveFunds` | plain midnight | business day (record stored under the business date; float set at 07:00 with a 07:30 reset belongs to the previous day) |
| `expense_tracking.dart` — `_loadTodayExpenses` | plain midnight | business day |
| `dialog.dart` — daily-data dialog, chart day list, per-day revenue/expenses | calendar dates | business dates (one order at 01:00 = same day as the evening before) |
| `history_cleanup_service.dart:77` | plain midnight | business day (consistency) |
| Daily report printer | verify source | route through business day if needed |
| Final sweep | grep `DateTime(now().year`, `.day ==`, `between(` | every remaining day read unified |

- **Funds carry-over kept**: if no float is set for the current business day, the app
  still falls back to the latest record (the drawer cash really does continue) — now
  correctly business-day aware.
- Shops on the default 00:00 boundary: behavior **identical** to today everywhere.

---

## Part 3 — P28: the boundary belongs to exactly one day

ObjectBox `between()` is inclusive on both ends → an order at exactly the boundary
instant (08:00:00.000) lands in TWO days, and the dashboard's current "−1 second" trim
loses the final second of the day.

Rule introduced everywhere: **range = [start … end − 1 ms]** (end-exclusive).

| Site | Fix |
|---|---|
| `order_repository.getOrdersByDateRange` | API takes an end-exclusive range, queries `between(start, end − 1ms)` — callers can't forget |
| `dashboard_service` | drop the `−1 second` hack → end − 1ms (today **and** previous-period ranges) |
| `history_screen` day query | −1ms (the double-count case) |
| `funds_repository` day range | −1ms |
| `dialog.dart` / expenses ranges | −1ms (same sweep as Part 2) |

---

## Files touched

- `lib/widgets/business_day_settings.dart` — rewrite (2 questions + preview)
- `lib/service/business_day_helper.dart` — add `resetFromHours(...)` formula
- `lib/repositories/funds_repository.dart` — business day + −1ms
- `lib/repositories/order_repository.dart` — end-exclusive API
- `lib/service/dashboard_service.dart` — −1ms trim (today + prev period)
- `lib/screens/history_screen.dart` — −1ms
- `lib/screens/expense_tracking.dart` — business day
- `lib/widgets/dialog.dart` — business-date day list + −1ms
- `lib/service/history_cleanup_service.dart` — business day
- `lib/service/settings_service.dart` (or equivalent) — SharedPreferences for the 2 answers
- printer daily report — only if verification shows it needs routing
- `test/batch3_business_day_test.dart` — new
- `TEST_BATCH3.md` — new manual checklist
- `PROBLEMS.md` — P19/P27/P28 rows + Decisions log

## Tests (automated)

1. `resetFromHours`: café 16→23 = 07:30 · bar 22→04 = 13:00 · shop 10→19 = 02:30 ·
   01→23 = 00:00 · open = close → 00:00
2. `getBusinessDayRange` / `getBusinessDayDate`: start at boundary, end = +24h;
   07:29:59.999 → previous day, 07:30:00.000 → new day
3. Real in-memory ObjectBox store: orders at the boundary millisecond are counted in
   **exactly one** day (no double count, no lost last second)
4. Funds: float set at 07:00 (reset 07:30) is attributed to the previous business day
   and carried over — not re-prompted
5. All previous tests still pass (37)

## Manual checklist (TEST_BATCH3.md outline)

- B1 default shop (00:00): dashboard / funds / expenses / dialog identical to before
- B2 mode "Sur mesure" 16:00 → 23:00: preview shows 07:30; save; reopen → still shown
- B3 evening + after-midnight sales = ONE day on the dashboard
- B4 funds, expenses list and daily-data dialog agree with the dashboard
- B5 float set in the evening: no re-prompt after midnight, drawer keeps counting
- B6 day-dialog chart days = history days
- B7 order at the exact boundary second appears in ONE day only
- Regression: history, reprint, daily report unchanged for a default shop

## Verification pipeline

analyze (≤ 178 infos, 0 errors) → all tests → `flutter build windows --debug` →
restart app → PROBLEMS.md updated → commit.

## Decisions embedded in this plan (flag any objection now)

1. "Fin de journée" setting removed (it never worked; the 2 questions replace it).
2. Reset = **middle of closed hours** — max tolerance for random opening times.
3. Standard midnight mode stays the default; untouched installs change nothing.
4. Funds carry-over behavior kept (drawer cash continues), just business-day aware.
5. Day labelled by its **start** date (a night bar's Friday 22h→Sat 04h = "Friday").
6. Changing hours later re-cuts old days — warned once in the settings text.
