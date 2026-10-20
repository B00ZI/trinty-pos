# TEST BATCH 6 — Que tester vous-même (20/10/2026)

Lot 6 = les restes + la vérité Android (P51–P57).
Application lancée : Easify (PID 8408, build du 20/10 19:17).

⚠️ **À savoir** : votre appareil principal = **tablettes Android**. Cette
machine ne peut bâtir que la version **Windows** (pas de SDK Android
installé ici). Les points Android (notifications) se testent quand vous
aurez le prochain APK — voyez la question en bas.

## 1. ⭐ Un réglage s'applique tout de suite — P57

Avant : vous changez un réglage ou vous ajoutez un utilisateur dans
Paramètres → la moitié de l'application gardait l'ancienne valeur jusqu'au
redémarrage.

À tester (maintenant, sur Windows) :
1. **Paramètres → Boutique** : changer le **nom du magasin**, enregistrer.
2. Ouvrir le **Tableau de bord** ou n'importe quel écran : plus besoin de
   redémarrer, le nouveau nom est partout.
3. **Paramètres → Utilisateurs → Ajouter** un utilisateur (ex. Karim).
4. Aller au **Tableau de bord** : Karim est déjà dans la liste déroulante
   des ventes par utilisateur.
5. Même chose pour un changement de **mode jour** ou de **prix en heure de
   pointe** : effet immédiat.

## 2. ⭐ La navigation ne vous jette plus à l'accueil — P56

Avant : si l'application se redessinait entièrement (thème, racine), tout
retombait sur l'écran d'accueil — vous perdiez votre place en plein travail.
Maintenant la carte des écrans est constrite **une seule fois**.

À tester :
1. Commande → Historique → **Modifier** une commande (la ligne
   "Modifier N°…" fonctionne comme avant, animation comprise).
2. Revenir en arrière : la liste d'Historique est à jour.

## 3. Le panneau développeur ne ment plus — P51

1. Ouvrir le panneau développeur (PIN **9999**).
2. **Les deux boutons d'export sont supprimés** (ils écrivaient dans un
   dossier Android : sur Windows, un clic ne donnait rien — pas même un
   message). La **Sauvegarde** dans Paramètres fait ce travail sur les
   deux plateformes.
3. Le reste du panneau (statistiques, filtre par date, suppression
   totale) fonctionne comme avant.

## 4. Sur vos tablettes Android (dès que vous avez le prochain APK) — P52

- Première partie prépayée qui se termine toute seule → **notification
  « Partie terminée — Poste X, le temps est écoulé »** en haut de
  l'écran Android.
- Android 13+ demandera une fois l'autorisation des notifications : dire
  **Autoriser**. (Avant : ni permission, ni alerte fiable — deux alertes
  pouvaient même s'écraser l'une l'autre.)

## 5. L'identité de l'app — P54 (invisible, mais vrai)

La version affichée est maintenant **2.0.0 (build 20002)** au lieu du
faux « 1.0.0 » du gabarit, la description dit ce que c'est, et 5 paquets
inutilisés ont été enlevés (l'APK/APK futur sera plus léger).

## Si tout est bon

Dites simplement **« go »** pour la suite (les restes : P20 index —
risqué à cause du générateur, P21 catégories par nom, P46 — je recommande
de garder, P48 — garder).
Et surtout : **comment installez-vous habituellement l'APK sur vos
tablettes Android ?** (Vous le bâtissez sur un autre ordinateur ? Un
service ?) Cette machine n'a pas le SDK Android — si vous voulez, on
trouve le moyen de vous préparer l'APK à partir d'ici.
