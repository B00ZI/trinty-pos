# BATCH 4 PLAN — P23 · P24 · P26 · P30 (owner approved 2026-10-20, in his words)

> Owner's instruction (kept verbatim so nobody "improves" it later):
> "fix p23 and p24 and make the p26 a real full backup that includes all data and also
> add option to edit it like a model where u can choose what to export all or just select
> what and add the q for replacing also gather the ui for export and import in one btn
> that shows then the two btns add checks on price and names never allow same name but
> allow 0 as price never allow negative price"

**Hard rules for this batch (same as every batch):** no schema change, no objectbox codegen
(build_runner hangs on this machine), in-place JSON/flags only, tablets-safe release builds.

---

## 1. P23 🟠 — an old order's lines must never leak into a new sale

**Bug:** the cart is one shared object. `Modifier` an order loads its lines into the cart
(`loadOrderForEditing` sets `state.orderToEdit`). Leaving with ← does not clear anything, so
the next **Nouvelle Commande** still shows the old lines → Confirmer = the old sale charged
a second time as a brand-new order.

**Fix (one rule, provider-level so it is testable):**
- `CartNotifier.prepareNewOrder()` — new method:
  - if `state.orderToEdit != null` (the cart came from an EXISTING order) → `clearCart()`
    and return `true` ("the old lines were dropped");
  - otherwise return `false` — a normal new-order **draft you stepped away from is kept**
    (unchanged behaviour: shopkeeper adds 3 teas, checks the printer, comes back).
- `_OrderScreenState.initState` post-frame callback: when `widget.orderToEdit == null`
  call `prepareNewOrder()`; if it dropped something show
  `SnackBar('Panier de la commande précédente vidé')`.
- Edit-save path unchanged (P12 sealed transaction).

**Tests:** cart keeps a normal draft / cart from an edit is dropped / draft after an edit is
also dropped (prepareNewOrder twice).

## 2. P24 🟠 — game order ↔ session link: one sealed save

**Bug:** paid game = order written in one transaction, then the session is linked to it in a
**second, separate write** (`session.relatedOrderId = order.id; box.put(session)`). Crash in
between = the session has no link → dashboard/report count the order revenue AND the
unlinked session revenue → the same sale counted **twice**, and the post stays occupied.

**Fix:**
- `GameSessionService`:
  - new `prepareSession(...)` = builds the GameSession (party number + post active flag) **in
    memory, no write**; `startSession(...)` becomes prepare + its old single-session writes
    (behaviour identical for the non-paid path at games_screen:203).
  - new `promoteNextQueued(post, objectbox)` — the queue-promotion half of `endSession`,
    callable after an external transaction; `endSession` keeps its signature and calls it.
- `games_screen` paid-start path: **one** `runInTransaction(TxMode.write, …)` that writes
  order → bumps order counter → sets `session.relatedOrderId` → writes the session → marks
  the post active. Either everything lands or nothing does.
- `games_screen` "Terminer la partie" (prepaid/limited) path: same treatment — order +
  counter + session status/endTime/relatedOrderId in ONE transaction, queue promotion after.

**Tests (real store, batch3 style):** happy path — one sealed save leaves order, session with
`relatedOrderId == order.id`, counter bumped exactly once, post active; failure path — an
exception thrown inside the sealed transaction leaves **no order, no session, counter
untouched** (that is exactly the crash scenario).

## 3. P26 🟡 → full backup with a choice of what to export + "replacing?" question

**Bug:** "Sauvegarde" exports **products + categories only** but sounds like a full backup;
import silently overwrites same-named products.

**Fix — `DataBackupService` version 2 (JSON `version: 2`, old v1 files still import):**

- **Export** = real full data, tick-by-tick sections:
  | Section (French label in the dialog) | Contents |
  |---|---|
  | Produits & catégories | Category, Product |
  | Commandes & tickets | Order + its OrderItems (prices, extras JSON, seller) |
  | Utilisateurs | AppUser (name + PIN hash/salt → PINs still work after a restore) |
  | Dépenses | Expense |
  | Fond de caisse | DailyFunds |
  | Jeux & parties | GamePost, PartyTier, GameSession (incl. order link) |
  | Réglages boutique & imprimantes | StoreConfig + PrinterConfig |
  Counters (order number, party number) always travel with the file.
  **The Wi-Fi password is NOT exported** — it lives in the OS secure storage (P07), a JSON
  file passed around must not carry it.
- **Export UI:** header keeps ONE button (download icon, tooltip "Sauvegarde") → opens a
  dialog with the two buttons the owner asked for:
  1. **Exporter** → second dialog "Que voulez-vous exporter ?" = "Tout (recommandé)" +
     one checkbox per section above → "Exporter la sélection";
  2. **Importer** → picks the .json → reads it → **confirmation question first**:
     "Ce fichier contient : X commandes, Y produits, Z utilisateurs… Ils seront ajoutés ou
     remplacés dans la base. Continuer ?" (Annuler / Importer).
- **Import rules (safe, no surprise wipe):**
  - products / categories → merge **by name** (same rule as today, now announced);
  - users → added unless a user with the same name already exists (local PIN kept);
  - orders / expenses / funds / sessions / posts / tiers → written under their **original id
    if that id is free** (relations stay intact on a fresh install), skipped if the id is
    already used (never clobbers live data);
  - store config / printer configs → only what was ticked, printer merged by id;
  - counters → restored to `max(current, backup)` so order numbers never go backwards;
  - the **whole import runs in ONE transaction** → all-or-nothing, same promise as P12.
- `previewImport(json)` returns the per-section counts for the confirmation dialog (and
  detects a v1 file → shows the old "produits + catégories" wording).

**Tests (real store):** export → empty second store → import → everything back with working
relations (order → user, order item → product, session → order link); id already used →
record skipped, live data untouched; v1 old-format file still imports; counters never
decrease; preview counts match.

## 4. P30 🟡 — price and name checks

**Bug:** price field accepts `-5` (a product that subtracts money on every sale) and `0`;
the same product / category / user name can be created twice.

**Owner's call:** **0 price allowed** (free products are real), **negative never**, **same
name never**.

**Fix:** new tiny pure helper `lib/service/input_rules.dart` (testable without widgets):
- `nonNegativePrice(raw)` → `MoneyParser.parse` + `< 0` rejected → message
  `Le prix ne peut pas être négatif` / `Prix valide requis`;
- `uniqueName(raw, existingNames, excluding)` → trimmed, accents/case-insensitive compare →
  `Ce nom existe déjà`.

Wired into: product dialog (name unique among products, price ≥ 0), category dialog (name
unique among categories — this also closes the duplicate-name crash P59 saw), add-user dialog
(name unique among users).

---

## Definition of done (unchanged)

1. Implement (no schema change, no codegen).
2. `test/batch4_*.dart` new tests + all previous tests still pass (baseline 50/50).
3. `flutter analyze` ≤ 178 infos, 0 errors.
4. `flutter build windows --debug` → stop old Easify → start new one.
5. `PROBLEMS.md` rows + Decisions log (owner's own words) + `TEST_BATCH4.md` checklist +
   handoff update.
6. One descriptive commit referencing P23 P24 P26 P30.

**Not in this batch:** P63 (owner has not answered yet — ask once more), all of section D
(UI pass), P51 dev-panel export (batch 6).
