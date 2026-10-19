# TEST_BATCH2 — your manual checklist (batch 2)

App: `build\windows\x64\runner\Debug\Easify.exe` (rebuilt 2026-10-19).
Automated: 27/27 unit tests (extras snapshot + money parser), analyze 0 errors.

## Part A — Extras are frozen at sale time (P15 / P22)

| # | Do this | You should see |
|---|---------|----------------|
| A1 | Sell 1× Thé + extra Lait (2 DH) → note the total in Histoire | extra shown as `+ Lait … 2.00` |
| A2 | Management → edit **Lait** 2 → 5 DH → look at that old order again | **nothing changes** (old sale keeps 2 DH) |
| A3 | New sale with Lait | new sale charges 5 DH ✓ |
| A4 | Sell Thé + Lait → note total → **delete Lait** in Management → look at the old order | still `+ Lait … 2.00`, total unchanged |
| A5 | Look at any order with extras saved **before today's fix** | shows the same numbers as always |
| A6 | Cart: tap an extra twice → line shows `Lait ×2 … 4.00 DH`; tap **−** | quantity and price follow, − still removes |
| A7 | Dashboard + receipt of a sale with extras | both agree with Histoire |
| A8 | Cart line with extras | under the name: **product price only**; below: each extra with its price; under them: **"Total … DH"** = product + extras (receipt style) |

## Part B — Money inputs: comma works, no silent 0.00 (P17 / P18)

| # | Do this | You should see |
|---|---------|----------------|
| B1 | Any sale → Valider → payment dialog → type `12,5` | green **"Monnaie à rendre"** appears — comma works |
| B2 | Payment dialog → paste/type `abc` in Montant Reçu | red **"Montant invalide"** (no silent blank box) |
| B3 | Payment dialog → type less than total | red "Montant manquant" **and Valider still works** (by design) |
| B4 | Fond de caisse → type `12,5` → save → reopen | shows **12,50** (not 0.00) |
| B5 | Fond de caisse → empty field → Enregistrer | **refuses with a message**, nothing saved |
| B6 | Settings → majoration amount → `2,50` → save | saved correctly (used to become 0.00) |
| B7 | Management → product price → type `2,50` | accepted (comma used to say "Prix valide requis") |
| B8 | Expenses → add an expense `12,5` → list | saved; shows **12.50 DH** (no more `$`) |
| B9 | Games → tarif horaire → `30,5` → save | saved (comma works) |

## Part C — quick regression (nothing else broke)

| # | Do this | You should see |
|---|---------|----------------|
| C1 | Normal sale with two copies | both print, comment + takeaway on both (batch 1) |
| C2 | Ticket Simple | one copy, seller attached (batch 1) |
| C3 | Sale without printer configured | French snackbar, no crash (batch 1) |

## Part D — Extras per unit + mixed orders (owner option B)

| # | Do this | You should see |
|---|---------|----------------|
| D1 | Add Thé ×2 → tap **+** → add Lait (2 DH) | cart: `Thé … 20.00`, `+ Lait ×2 … 4.00`, **Total 24.00**; receipt prints `+ Lait ×2` |
| D2 | With that line having extras, tap **Thé** in the grid | a **second, plain** Thé line appears (not merged) |
| D3 | Flow "1 Thé Lait + 1 Thé plain" | two lines, totals 12.00 + 10.00 |
| D4 | Tap tap tap **Thé ×3 first**, then add Lait once | one line: `+ Lait ×3 … 6.00`, Total **36.00** |
| D5 | Look at any order **with extras sold before today's fix** | totals unchanged (extras counted once, as sold) |
| D6 | Edit an old order, change an extra's count | stays on the old rule — no surprise multiplication |
| D7 | Remove the extra from a per-unit line, add another extra | new extra counts per unit (line keeps its rule) |
| D8 | Add extras to a line → go back to the cart (leave extras mode) → tap **−** on the extra | it works — quantity drops / extra removed, anytime, on any line |

Everything checked → **batch 2 + cart behavior complete**. Next up: batch 3 (business day).
