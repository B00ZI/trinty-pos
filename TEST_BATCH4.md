# TEST_BATCH4.md — your turn to test (batch 4 = P23 · P24 · P26 · P30 · P63)

The new build is **already running** on this machine (restarted 20/10 17:32).
Nothing here touches your data except the tests you choose to run — do them
in a safe order: **first the small checks, then the backup tests** (P26 test 3
imports data, so do it last and use a copy of the file, not your only one).

---

## 1. P30 — price and name checks (2 minutes)

| # | Do this | You should see |
|---|---------|----------------|
| 1 | Gestion → **Produits** → ＋ → *Nom*: `Thé` (if "Thé" already exists) → save | Red message **"Ce nom existe déjà"**, nothing saved |
| 2 | Same dialog, new name `Test 1`, *Prix*: `-5` → save | Red **"Le prix ne peut pas être négatif"** |
| 3 | Same, *Prix*: `0` → save | **Saves fine** (free products allowed, your call) |
| 4 | Same, *Prix*: `12,5` → save | Saves at 12.50 (French comma works) |
| 5 | Gestion → **Catégories** → ＋ → a name that already exists | **"Ce nom existe déjà"** |
| 6 | Paramètres → **Ajouter un Utilisateur** → a name that already exists (try `youssef` vs `Youssef`) | **"Ce nom existe déjà"** |
| 7 | Edit an existing product, keep its own name, just change the price | Saves fine (editing doesn't collide with itself) |

## 2. P23 — an old order can't sneak into a new sale (2 minutes)

| # | Do this | You should see |
|---|---------|----------------|
| 1 | **Historique** → open an old order → **Modifier** | The order's lines load in the cart |
| 2 | Press ← (top-left) — do **not** save | Back to Historique |
| 3 | **Nouvelle Commande** | **Empty cart** + message **"Panier de la commande précédente vidé"** |
| 4 | Now add 2 teas, press ← (back), then **Nouvelle Commande** again | The 2 teas are **still there** (your own draft is kept, nothing lost) |

## 3. P24 — game sale and its session are one save (hard to force; check the result)

A crash exactly between the two writes was the bug — you can't trigger that on
purpose. So check the outcome instead:

| # | Do this | You should see |
|---|---------|----------------|
| 1 | Jeux → start a **fixed-duration** game (15/30/60 min) | Ticket prints, post shows running |
| 2 | Dashboard / Historique for that period | The game's money appears **once** — not twice |
| 3 | **Terminer la partie** on a prepaid/limited session | Ends, prints, and the amount still counts once |

## 4. P26 — the new Sauvegarde (do this one carefully)

### 4a. Look at the new UI
| # | Do this | You should see |
|---|---------|----------------|
| 1 | Gestion → the new button (⇄ icon, tooltip "Sauvegarde"), top right | A dialog with **two buttons: Exporter / Importer** |
| 2 | **Exporter** | "Que voulez-vous exporter ?" — **Tout (recommandé)** ticked + 7 sections below (Produits & catégories, Commandes & tickets, Utilisateurs, Dépenses, Fond de caisse, Jeux & parties, Réglages boutique & imprimantes) |
| 3 | Untick "Tout" → tick only **Produits & catégories** → "Exporter la sélection" | A file is shared — open it: it contains `categories` + `products` only |

### 4b. The "what will be replaced?" question
| # | Do this | You should see |
|---|---------|----------------|
| 1 | Exporter → **Tout (recommandé)** → keep the file somewhere |
| 2 | **Importer** → pick that file | **Before anything is written**: "Importer cette sauvegarde ? — Ce fichier contient : X commandes, Y produits, Z utilisateurs…" + "Annuler / **Importer**" |
| 3 | Press **Annuler** | Nothing changed anywhere |
| 4 | Import the same file again → confirm | Success message lists the counts; importing the **same** file twice never duplicates: **0 commandes ajoutées** (your live orders are never replaced), no double users, no double products |

### 4c. The real restore test (only if you want to go all the way)
On a **copy** of your machine, or after you have two files saved:
1. Export **Tout** → save the file.
2. Import it → your orders, users (PINs still work!), expenses, floats, game
   sessions and settings are all still there — nothing changed because it is
   your own data (that is the point: same shop = no duplicates).

⚠️ The **Wi-Fi password is never in the file** — it stays in the system's
secure storage, so a backup file can be shared without leaking it.

## 5. P63 — Histoire never sits on a stale day (your "19 but I see 9" report)

| # | Do this | You should see |
|---|---------|----------------|
| 1 | **Historique** (from the hub) | The date shown is **today's business day** |
| 2 | Tap ← a few times to look at an older day | It moves back one day per tap (browsing works) |
| 3 | Press ← to leave, open **Historique** again | It is back on **today** — not the old day |
| 4 | While on an old day: open an order → **Modifier** → ← (back) | Histoire shows **today** again (it snaps as soon as it is uncovered) |
| 5 | Browse to an old day once more, then tap the **"Aujourd'hui"** button at the right of the date | Jumps back to today in one tap |

---

### Test order reminder
Do sections 1 → 2 → 3 → 4a → 4b first; section 4c (a real restore) and
section 5 whenever you like. Section 4b's step 4 imports data — use a copy
of the exported file, never your only one.

When you have tested: tell me what works, what doesn't, and anything new you
find. Nothing gets fixed without your say.
