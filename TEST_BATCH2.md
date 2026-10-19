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

Everything checked → **batch 2 done**. Next up: batch 3 (business day).
