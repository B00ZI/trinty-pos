# TEST BATCH 5 — Que tester vous-même (20/10/2026)

Lot 5 = la stabilité interne (P42, P43, P44, P45, P47, P49, P50).
L'application lancée : Easify (PID 952, build du 20/10 18:29).
Aucun changement de vos données, aucun changement d'écran — c'est le
« moteur » qui a été réparé.

## 1. ⭐ Les parties (Jeux) — P50 : l'horloge + la batterie

Avant : l'écran des Jeux se redessinait **entièrement chaque seconde**
et interrogeait la base 60 fois par minute (~3 600 requêtes/heure) —
sur une tablette qui reste sur cet écran toute la journée, c'est de la
batterie et de la chaleur pour rien.

Ce qui a changé, en mots simples :
- seules les **2 lignes qui bougent** (le temps qui court + le prix qui
  monte) se redessinent chaque seconde ;
- la base n'est plus interrogée qu'**au plus toutes les 10 secondes** ;
- quand une partie à durée limitée se termine toute seule, l'écran se
  rafraîchit une fois — pas les 59 autres.

À tester :
1. Ouvrir **Jeux**, lancer une partie (paiement).
2. **Regarder la carte du poste** : le temps écoulé tourne à la seconde,
   le prix monte (partie libre) ou compte à rebours (partie prépayée).
3. Laisser l'écran ouvert **10 minutes** — le temps doit toujours tourner
   exactement (il ne doit pas « rater » des secondes).
4. Partie prépayée (30 min / 1 h) : à la fin, la carte disparaît toute
   seule et le poste redevient DISPONIBLE.
5. Démarrer une partie, aller dans un autre écran, revenir sur **Jeux** :
   la partie est toujours là, le temps correct.

## 2. ⭐ « PIN par commande » — P47 : le réglage qui s'oubliait

Avant : il y avait une faute entre ce que la page Paramètres écrivait et
ce que le programme relisait — le mode pouvait revenir à « Désactivé »
après un redémarrage alors que vous l'aviez choisi.

À tester :
1. **Paramètres → Sécurité et Authentification** → choisir
   **PIN par Commande** → le message « Mode d'authentification mis à
   jour » apparaît.
2. **Fermer l'application et la relancer.**
3. Revenir dans Paramètres : **PIN par Commande** est toujours coché.
4. Nouvelle commande → le choix de l'utilisateur (PIN) est demandé.

## 3. ⭐ Un bouton qui plante — P42 : plus jamais « rien ne se passe »

Avant : si une action plantait, le bouton ne faisait rien — sans aucun
mot. Maintenant un message rouge apparaît : **« Une erreur est survenue —
réessayez »**, et l'application continue de tourner.

Comment le voir sans casser quoi que ce soit : c'est un filet de
sécurité — il apparaît seulement si quelque chose échoue vraiment. Il
suffit de savoir qu'il existe maintenant. Si vous le voyez un jour,
notez l'heure et ce que vous faisiez.

## 4. Le reste (code propre) — P43, P44, P45, P49

Pas de geste à faire, c'est du travail « sous le capot » :

- **P43** : les fenêtres (dialogues) ne s'ouvrent plus jamais sur un
  écran déjà fermé — supprime un possible blocage au démarrage d'une
  partie ou d'une commande rapide.
- **P44** : les champs texte sont maintenant libérés quand on quitte un
  écran — l'application vieillit mieux pendant les longues journées.
- **P45** : 4 fichiers morts + une route morte + 2 fonctions mortes +
  des imports inutiles supprimés — rien de visible, tout allégé.
  **Aucune de vos données n'a bougé.**
- **P49** : une tablette en mode release n'écrit plus les traces de
  navigation ni le contenu des tickets dans la console (debug seulement).

## Si tout est bon

Dites simplement **« go »** pour le lot 6 (P51 : le panneau développeur
caché + autres points restants).
