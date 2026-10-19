# TEST BATCH 3 — Business day (one clock for the whole app)

Fixes: P19 (two meanings of "today"), P27 (dead end-time setting → 2 questions,
reset calculated), P28 (day boundary double-count / lost last second).
App version: branch 2.0.0.3 after the batch-3 commit.

Everything here is safe to test — default shops (never opened the setting)
must behave EXACTLY like before (that's B1).

---

## B1 — Default shop: nothing changed

| # | Action | Expected |
|---|---|---|
| B1.1 | Settings → Paramètres de la Journée | "Jour standard — la journée démarre à minuit" is selected; the old "Fin de journée" picker is GONE |
| B1.2 | Make a sale, check dashboard, Histoire, dépenses, résumé quotidien | identical to before this batch |

## B2 — The 2 questions and the calculated reset

| # | Action | Expected |
|---|---|---|
| B2.1 | Settings → choose "Basé sur mes horaires" | two questions appear: heure d'ouverture / heure de fermeture + a yellow preview box |
| B2.2 | Set ouverture 16:00, fermeture 23:00 | preview says "Votre journée se réinitialise à 07h30" |
| B2.3 | Try fermeture 04:00 + ouverture 22:00 (a bar) | preview says 13h00 (the whole night = one day) |
| B2.4 | Save, reopen settings | mode + both times still shown (remembered) |

## B3 — Every screen now agrees on "today"

Test recipe: set ouverture **later than the current hour** (e.g. it's 14:00 →
set ouverture 20:00, fermeture 23:00). The calculated reset will be AFTER now,
so the app's "today" becomes yesterday — exactly the situation that used to
make the screens disagree.

| # | Action | Expected |
|---|---|---|
| B3.1 | Look at the dashboard date / "aujourd'hui" cards | it shows YESTERDAY's business day (the day is not over until the reset) |
| B3.2 | Add an expense now | it appears in the expenses list and counts in the SAME day the dashboard shows — not a separate "today" |
| B3.3 | Set the float now | it is saved for the day the dashboard shows; no re-prompt loop |
| B3.4 | Open Histoire | the selected day = the same day the dashboard shows |
| B3.5 | Open the daily-data dialog (résumé quotidien) | its top day = the same day; chart days match history days |

## B4 — The day boundary (P28)

The exact-millisecond cases are covered by automated tests (real database).
Manually: after B3, make a sale and check it appears in **one** day only —
dashboard total = Histoire total = rapport total.

## B5 — Regression (with standard mode restored)

| # | Action | Expected |
|---|---|---|
| B5.1 | Set the mode back to "Jour standard", save | everything back to calendar days |
| B5.2 | Dashboard, Histoire, rapport journalier, réimpression | unchanged from before this batch |
| B5.3 | Dépenses widget, fonds de caisse, résumé quotidien | unchanged for a 00:00 shop |

---

Automated: 50/50 tests (batch3 adds 13: reset formula ×6, day math ×5,
real-DB boundary count ×1, real-DB funds day + carry-over ×1).
