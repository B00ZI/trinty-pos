# Test batch 1 — Receipts & printing

App: `build\windows\x64\runner\Debug\Easify.exe` (build this batch: 2026-10-18).
Work through the list top to bottom. Every line should be ✅.

## 1. Printer test button (was broken — P31)
- Settings → Printer → **Imprimer un test**.
- ✅ One test ticket prints with "OK Printer Test Successful" (was: nothing, button dead).
- If your printer is off / wrong IP: a red snackbar appears saying the connection failed (was: nothing at all).

## 2. Takeaway + kitchen comment (was never printed — P13)
- Add items, set a **kitchen comment** (e.g. "sans sucre"), mark the order **takeaway**.
- Confirm and pay.
- ✅ **TWO** tickets print, one second apart (by design: one for the client, one for the kitchen).
- ✅ **BOTH** tickets show the black **IN HOUSE** strip and the comment "sans sucre" (was: the first ticket had neither).

## 3. Ticket Simple now saves with a seller (P13)
- Sell with **Ticket Simple**.
- Open Histoire → the order → seller name is filled in (was: empty).

## 4. Double-tap does nothing extra (P35)
- Tap the confirm/pay button **twice very fast**.
- ✅ Only one order is created (Histoire shows one order, one ticket).
- ✅ While saving, the buttons grey out for a moment.

## 5. Reprint shows the OLD price (P14)
- Sell a product (e.g. Thé 10 DH).
- Management → edit that product to 15 DH.
- Histoire → reprint the old order.
- ✅ The reprint still shows **10 DH** and the total matches (was: 15 DH or 0.00 if deleted).

## 6. Deleted product still reprints correctly (P14)
- Sell a product, then delete it from Management.
- Reprint that order from Histoire.
- ✅ The line still shows the product name and price you sold it for (was: "Unknown Product" / 0.00).

## 7. Daily report vs dashboard (P16)
- Play a game session and pay it.
- End the day → print the daily report (rapport journalier).
- ✅ **TOTAL CA** on the paper equals the revenue on the dashboard (was: paper higher — games counted twice).

## 8. Printing always tells you what happened (P32/P37)
Try each of these:
- **No printer set** → Settings → Printer → **clear the IP** and save (empty IP is now allowed = "pas d'imprimante", hint says it under the field) → sell an order → ✅ red message "Aucune imprimante configurée (Paramètres → Imprimante)".
- **Wrong IP** (e.g. 1.1.1.1) → sell an order → ✅ red message "Connexion à l'imprimante échouée — vérifiez l'adresse IP" (was: nothing at all — the hole you found on desktop).
- **Right IP but printer turned off** → sell an order → ✅ red connection message (was: nothing).
- **Settings → Test button** with wrong IP / printer off → ✅ short French message (was: a long raw "timed out" dump).
- **Printer working** → sell an order → ✅ message **"Ticket envoyé — en cours d'impression…"** appears INSTANTLY when the printer accepts the job, then **"Ticket imprimé"** when the paper really comes out (once per copy — client copy and kitchen copy each confirm). You always know the order went through, even while the paper is still coming.

## 9. Printer settings save safely (P29)
- Change a printer setting, save, restart the app.
- ✅ Setting is still there (was: a crash during save could leave NO printer config at all).

## Automated tests (done by me ✅)
- `flutter test test/batch1_printing_test.dart` → **9/9 pass** (character scrubbing, money formula, reprint).
- `flutter analyze` → 180 issues (baseline was 181), **0 errors**.

## Known & accepted for this batch
- P34: if ONE client's printer shows wrong accents (é/à/ç garbled), set **that printer** to Latin-1 / ISO-8859-1 mode — the app no longer switches code pages itself (that would change output on every printer).
- A reprint cannot show the takeaway strip / comment — those live only on the paper of the first print (storing them on the order needs a database change; not in this batch).
