# Easify POS — version 3

**An offline point of sale for small cafés and shops — Windows desktop and Android tablets.**

Easify is a French-language, cash-only POS made for Marrakech cafés. Take orders,
print thermal receipts, track your funds and expenses, run prepaid game sessions,
and back up everything from inside the app. Everything runs **on the device
itself** — no internet, no server, no account needed to sell.

---

## What it does

- **Selling** — a fast cart with quantity merging, **per-unit extras** ("2 thé lait"
  charges 2 lattes), mixed orders in one cart, kitchen comment and takeaway flag,
  two receipt copies (client + kitchen), *Ticket Simple*, cash payment with change
  display, optional PIN per order, and seller attribution on every sale.
- **Catalogue** — products and categories with photos, unique names enforced,
  sensible price rules (0 allowed, negative refused), PIN-protected deletes.
- **History & business days** — order history that opens on today (with an
  *"Aujourd'hui"* button when you browse old days), edit and reprint old orders at
  **their original prices**; the day boundary follows your real opening hours
  (or standard midnight, your choice).
- **Money tracking** — fond de caisse, expenses in DH, a printable daily report,
  and a dashboard comparing today with the previous day, all computed from the
  real database.
- **Games** — prepaid parties with hourly rates, a queue that promotes safely,
  session tickets, sessions saved as orders (never counted twice), and an Android
  **"Partie terminée"** notification when a prepaid party auto-ends.
- **Backup (Sauvegarde)** — one button to export or import; pick which sections to
  export; the import shows what the file contains before touching anything and
  **never wipes your data**.
- **Settings** — printer setup with test tickets and friendly French errors,
  users & PINs, authentication mode, automatic maintenance cleanups, offline
  activation licensing, and a hidden maintenance panel behind a PIN.

---

## What's new in version 3

Version 3 is version 2.0.0 put through a full audit (63 logged problems) and
rebuilt where it mattered:

- **Printing that talks back** — every print says *"Ticket imprimé"* or a short
  French error; nothing fails silently anymore. Odd characters (✅, €, emojis) are
  cleaned for thermal printers instead of crashing mid-ticket. Reprints and the
  daily report use **the prices the order was actually sold at**. The cart clears
  after the receipt is built, and double-taps can't print twice.
- **Money counted exactly** — one input parser everywhere (`12,5` = 12.50),
  garbage input refused with a message instead of saving 0.00. Extras keep their
  price **from the moment of sale**. A paid game session saves as one unbreakable
  step — a crash can't make a sale count twice. Unique names, no negative prices.
- **One clock for the whole app** — you tell Easify when you open and close, and
  it picks the reset time itself (middle of the closed hours), so random opening
  hours or a night bar never split one day's takings across two dates. History,
  reports, funds and dashboard all agree on "today".
- **A real backup** — the Sauvegarde button exports what you choose and imports
  with a preview first; it matches records by content, never wipes, and old
  backup files still load.
- **Fewer crashes, clearer errors** — an unexpected problem now shows
  *"Une erreur est survenue — réessayez"* instead of a button that does nothing;
  the known crash spots are guarded; dead code removed; the games screen queries
  the database ~10× less.
- **Android gets its full treatment** — the *"Partie terminée"* notification is
  real (permission asked once, safe on every device), Windows can never trip the
  notification code, and this project now builds its own installable APK
  (`Easify-v3.0.0.apk`).
- **Settings apply instantly** — printers, config and users changed in Paramètres
  appear everywhere immediately, no restart; navigation can't reset to home
  mid-work.
- **Categories never lose their products** — renaming a category carries its
  products along, a category still in use can't be deleted, and editing keeps its
  place in the list.
- **Identified correctly** — the app now ships as version **3.0.0** (build
  30000), with 5 unused packages removed.

---

## Things to know

- **No Play Store.** The APK is installed by hand: send it to the tablet, open
  it, and allow installs from that source when Android asks.
- **Updates need the same key.** APKs built from this project are signed with one
  saved key (`cle-de-signature-easify.keystore`, kept in this repo plus a copy in
  the owner's Documents). A tablet running an app signed by an older, lost key
  simply refuses a new install — nothing on it is damaged; that tablet keeps
  running what it already has.
- **Data lives on the device** — Windows: `%LOCALAPPDATA%\Easify\objectbox`,
  Android: private app storage. The **Sauvegarde** button is the way to move a
  shop's data to another device.
- **The business day comes from Settings** — standard midnight, or your opening
  and closing hours (Easify computes the reset itself).
- **French UI, cash-only (DH)**, thermal printer over the network (port 91000).

*Developers: setup, build and test commands live in `HANDOFF_NEXT_SESSION.md`;
the full audit and every decision is in `PROBLEMS.md`.*
