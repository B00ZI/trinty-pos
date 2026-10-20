# BATCH 6 PLAN — leftovers & platform truth (P51–P57)

Approuvé par le propriétaire le 20/10/2026 ("go"), avec l'information
clé : **l'application est utilisée surtout sur des tablettes Android**.

## Les 7 points

### P53 — `windows/` + `tool/` absents de git (déjà fait ✅)
Vérifié : sur notre branche `2.0.0.3`, les 18 fichiers `windows/` et
`tool/generate_activation_key.dart` sont dans git depuis le lot 2
(`d5f5afa`). Seule la branche de production `2.0.0.2` en manque —
elle les aura en mergeant. Ligne fermée, rien à coder.

### P55 — Le test cassé de départ
`test/widget_test.dart` (modèle Flutter d'origine) : construit l'app sans
`ProviderScope`, attend un texte qui n'existe pas, ouvre une vraie base et
la fuit. **Supprimé** — nos 78 tests réels le remplacent.

### P54 — La carte d'identité de l'app (pubspec)
- `version: 1.0.0+1` → `2.0.0.2+20002` (votre produit = 2.0.0.2).
- Description : « A new Flutter project » → vrai texte français.
- Suppression des paquets installés mais **jamais importés** :
  `cupertino_icons`, `network_info_plus`, `charset_converter`,
  `mrx_charts`, et `audioplayers` (son de notification jamais joué).
- On garde le nom `Easify` (le renommer = toucher tous les fichiers, zéro
  bénéfice) et l'override pointycastle (décision P48 : garder).

### P56 — La carte des écrans reconstruite à chaque redraw
`createRouter()` était rappelé à chaque `build()` de l'app : un redraw
racine jetait la pile de navigation (retour à l'accueil en plein travail).
Maintenant : le routeur est créé **une seule fois** (state de `Easify`).
Le dernier `Navigator.push` direct (Histoire → Modifier) passe par
go_router comme le reste.

### P57 — Les réglages fraîchis à la vite
- `storeConfigProvider` : lu UNE fois → tapé « lu en direct » sur le
  stream de config (changer un réglage Paramètres se voit partout sans
  redémarrage).
- `printerConfigProvider` : idem sur le stream imprimante.
- `allUsersProvider` : lu UNE fois (le Dashboard ne voyait pas les
  nouveaux utilisateurs) → base sur `UserRepository.watchAll()` qui
  existait déjà.

### P51 — Le panneau développeur ment sur Windows
- Les boutons « Export DB » / « Export SQL » écrivent dans un dossier
  Android : sur Windows, `getExternalStorageDirectory()` rend `null` →
  **rien ne se passe, même pas une erreur**. Supprimés : la
  **Sauvegarde** (lot 4) fait ça, sur Android ET Windows.
- `cancelSessionNotification` supprimé (jamais appelé, annule par un
  mauvais identifiant).

### P52 — Android, maintenant qu'on sait que c'est le vrai terrain ⭐
- `AndroidManifest.xml` : permission `POST_NOTIFICATIONS` (Android 13+).
- La permission est **demandée une fois** avant la première alerte
  (API de flutter_local_notifications, sans nouveau paquet).
- Identifiants de notification : `DateTime.now().millisecond` (0–999 !)
  → deux alertes pouvaient s'écraser l'une l'autre ; maintenant un
  compteur croissant.
- Alertes limitées à Android (`Platform.isAndroid`) + try/catch : Windows
  ne peut pas planter sur cette voie (UnimplementedError).
- **Fil** : l'alerte « Partie terminée » qui n'était jamais appelée est
  maintenant déclenchée quand une partie à durée limitée se termine
  toute seule (écran Jeux) — le serveur sait que le client doit bouger.
- `init()` aussi sous garde platforme + try/catch.

## Tests (`test/batch6_platform_and_live_test.dart`)
1. P54 : le pubspec dit bien `2.0.0.2`, la description n'est plus le
   modèle, les paquets morts ont disparu (lecture du fichier).
2. P52 : `showHeadsUpNotification` ne lève rien sur l'hôte de test (pas
   Android) — la garde fonctionne.
3. P57 : avec une vraie boutique ObjectBox — un utilisateur ajouté
   apparaît dans `allUsersProvider`, un changement de nom de magasin
   apparaît dans `storeConfigProvider`, sans redémarrage.

## Défis techniques
- `Provider` qui regarde un stream : la première lecture peut rendre la
  valeur « par défaut » un très court instant — acceptable (comme
  aujourd'hui où la valeur était périmée).
- Pas d'APK possible ici : pas d'SDK Android sur cette machine — à
  expliquer au propriétaire à la fin.

## Après le lot
- `flutter pub get` (le pubspec a changé), analyze 0 erreur / ≤ 178 infos,
  tous les tests, build Windows, redémarrage, docs, 1 commit.
