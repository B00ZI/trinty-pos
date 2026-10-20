# BATCH 5 PLAN — Stabilité interne (P42, P43, P44, P45, P47, P49, P50)

Approuvé par le propriétaire ("go") le 20/10/2026.
Suite des lots 1–4 + P63 (voir `HANDOFF_NEXT_SESSION.md`).

## Les 7 corrections

### P50 — La minuterie des parties (vite-fait du lot 5)
- Avant : `Timer.periodic(1s)` → `setState()` (tout l'écran se redessine) +
  1 requête ObjectBox par seconde (~3 600/heure).
- Après : la minuterie ne fait plus que 3 choses par seconde :
  1. incrémenter un `ValueNotifier` auquel seules les 2 lignes d'horloge
     (temps écoulé / prix courant) sont abonnées ;
  2. vérifier en mémoire la liste des parties actives (cache) pour les
     parties à durée limitée ;
  3. reinterroger la base au plus toutes les 10 secondes (~360/heure).
- Les cartes des postes continuent d'être pilotées par le StreamBuilder
  existant (elles ne redépendent pas du timer).

### P47 — Le mode « PIN » qui s'oublie
- `AuthService.setAuthMode` écrivait `perOrder` (nom Dart) alors que la
  lecture cherche `per_order` : le réglage choisi revenait toujours à OFF.
- Écriture et lecture alignées sur la même écriture `per_order`, et la
  lecture accepte aussi l'ancienne faute `perOrder`.

### P42 — Rien ne tombe en panne silencieusement
- `runZonedGuarded` + `PlatformDispatcher.onError` + `FlutterError.onError`
  installés dans `main()` : toute erreur non attrapée (bouton qui plante,
  bug d'affichage) affiche un message court en français et est journalisée
  en debug seulement (P49).
- L'`ErrorBoundary` (écran « Réessayer ») qui existait sans être branché est
  maintenant branché via `MaterialApp.router(builder: ...)`.

### P43 — Les dialogues qui s'ouvrent après un « await »
- Garde `mounted` / `context.mounted` après chaque `await` qui précède un
  `showDialog`/`ScaffoldMessenger` : jeux (3), commande (1), paramètres (4),
  `dialog.dart` (2). Plus de risque d'utiliser un écran disparu.

### P44 — Les champs texte qui fuient
- `dispose()` ajouté : paramètres imprimante (2 contrôleurs), section prix
  (1), gestion produits (3), catégories (1) ; les contrôleurs des
  dialogues ajoutés/modifiés sont libérés à la fermeture du dialogue.

### P45 — Le code mort
- Supprimés : `providers/game_session_provider.dart` (0 import),
  `widgets/bestSellr.dart` (0 import, redéfinissait sa propre classe
  Product), `widgets/comment_dialog.dart` (0 import),
  `widgets/order_details.dart` (0 import), la route morte
  `/order/edit/:orderId`, `AuthService.getUsers` + `AuthService.verifyPin`
  (jamais appelés), les imports inutilisés (router, printer_helper,
  store_config).
- `error_boundary.dart` n'est PAS supprimé : il est branché (P42).

### P49 — Les deux lignes de debug qui parlent aux clients
- `router.dart` : `debugLogDiagnostics: kDebugMode` (les traces GoRouter
  existent seulement en debug).
- `printer_helper.dart` : l'impression de la recette dans la console est
  entourée de `if (kDebugMode)` comme la ligne au-dessus.

## Tests (`test/batch5_auth_and_errors_test.dart`)
1. P47 : `setAuthMode(perOrder)` → `getAuthMode()` rend `perOrder`
   (aller-retour complet) ; l'ancienne valeur `perOrder` est lue correctement.
2. P42 : `ErrorReporter` affiche le message français, et le rappeler
   2 fois de suite n'en montre qu'un seul (pas de dégouline).
3. P50/P49/P43/P44/P45 : vérifications manuelles + analyse du code
   (suppressions avérées par 0 référence).

## Défis techniques
- Supprimer un provider/widget pourrait casser un import non repéré →
  l'analyseur le dira (0 erreur autorisée).
- Le `runZonedGuarded` ne doit pas avaler les erreurs des tests : les tests
  n'exécutent pas `main()`, donc pas de conflit.

## Après le lot
- `flutter analyze` : 0 erreur, ≤ 178 infos (les 10 garde-contexte en moins
  vont sous la barre).
- `flutter build windows --debug` + redémarrage.
- `PROBLEMS.md` (lignes P42/P43/P44/P45/P47/P49/P50 + journal),
  `TEST_BATCH5.md`, `HANDOFF_NEXT_SESSION.md`, 1 commit.
