# TEST_BATCH7.md — Batch 7 : les catégories ne perdent plus leurs produits (P21)

**Version testée :** 2.0.0 (build 20002), app Windows relancée le 20/10 ~22:02.
**Durée :** ~5 minutes.

---

## L'histoire corrigée

> Tu renommes « Cafés » en « Boissons chaudes » → avant, tes cafés **disparaissaient
> de l'écran de commande** (plus aucune carte ne les montrait). Tu supprimais une
> catégorie → pareil. Et modifier une catégorie la **déplaçait en premier** dans la
> liste sans raison.

---

## À tester (dans Gestion → Catégories)

### 1. Renommer garde les produits ✏️
1. Sur l'écran **Gestion**, section **Catégories**, touche le **crayon** d'une
   catégorie qui a des produits (ex. « Cafés »).
2. Change le nom (ex. « Boissons chaudes ») → **Enregistrer**.

**Attendu :** la carte est renommée **à sa place exacte** (elle ne saute pas en
premier), et surtout : va sur l'écran de commande → tous les produits de l'ancienne
catégorie sont maintenant sous le nouveau nom.

### 2. La position dans la liste ne bouge plus lors d'une modification
1. Range les catégories par glisser-déposer dans l'ordre que tu veux.
2. Modifie le nom de la 2e catégorie (sans toucher à l'image) → Enregistrer.

**Attendu :** elle reste **2e**. (Avant : elle retombait en position 0/premier.)

### 3. Suppression refusée quand la catégorie sert encore 🚫
1. Touche la **poubelle** d'une catégorie qui a des produits.

**Attendu :** message **« Cafés » : 2 produits l'utilisent encore — changez-leur
de catégorie d'abord.** — la catégorie **reste**, ses produits aussi, et **aucun
code PIN n'est demandé** (le refus vient avant).

### 4. Suppression libre quand elle est vide
1. Crée une catégorie vide (bouton **+**), puis touche sa **poubelle**.

**Attendu :** le dialogue du **code administrateur** apparaît (comme avant) → après
le code, la catégorie est supprimée.

### 5. Une nouvelle catégorie arrive à la fin ➕
1. Touche **+** → nom (ex. « Desserts ») → **Enregistrer**.

**Attendu :** « Desserts » apparaît **en dernière position** (avant : elle sautait
en premier).

---

## Question importante pour toi

**Est-ce que tu as déjà vu, AVANT cette correction, un produit qui avait disparu de
l'écran de commande** (suite à un ancien renommage/suppression de catégorie) ?
- **Non** → rien à faire, c'est parfait.
- **Oui / je crois** → dis-le-moi : ces « orphans » d'avant ne se réparent pas tout
  seuls, je te ferai un petit outil de rattrapage (une fois, et seulement si tu en
  as vraiment.

---

## En retard (toujours ouverts)

- **TEST_BATCH6.md** : la liste complète du batch 6 (live settings, navigation,
  panneau dev).
- **APK** : installer `Easify-v2.0.0.2.apk` sur une tablette **sans l'app** (2 min)
  — notifications « Partie terminée » réelles à vérifier sur Android.
