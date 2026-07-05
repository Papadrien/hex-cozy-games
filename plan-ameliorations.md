# Plan — Nouvelles améliorations (upgrades) hex-cozy-games

> Document de conception uniquement. Aucun code n'a été modifié à ce stade.

## 1. Tableau final des 14 améliorations

| # | Amélioration | Quête de déblocage | Effet par niveau (1 → 2 → 3) |
|---|---|---|---|
| 1 | **Tuiles de départ+** | *Pièces gagnées* — 2000 pièces (cumul) | +2 → +5 → +10 tuiles au départ |
| 2 | **Connexions doublées** | *Biomes fermés* — 25 biomes | ×2 tuiles bonus sur quint/sext → + quad → + triple |
| 3 | **Pièces+** | *Pièces gagnées* — 3000 pièces (cumul) | +25% → +50% → +100% sur toutes les pièces |
| 4 | **Rouge+** *(renommé, ex-Villages+)* | *Rouge* — groupe rouge > 50 tuiles | +33% → +66% → +100% sur les côtés village |
| 5 | **Combo+** *(nouveau)* | *Meilleure série* — 10 connexions consécutives sans interruption | 1 tuile bonus tous les 5 dans la série → +1 tuile bonus/palier (2 puis 3 tuiles par déclenchement) |
| 6 | **Vert+** *(nouveau)* | *Forêt* — groupe vert > 50 tuiles | +25% → +50% → +100% pièces forêt |
| 7 | **Bleu+** *(nouveau)* | *Eau* — groupe bleu > 50 tuiles | +25% → +50% → +100% pièces eau |
| 8 | **Jaune+** *(nouveau)* | *Plaine* — groupe jaune > 50 tuiles | +25% → +50% → +100% pièces plaine |
| 9 | **Violet+** *(nouveau)* | *Montagne* — groupe violet > 50 tuiles | +25% → +50% → +100% pièces montagne |
| 10 | **Bonus de clôture** *(nouveau)* | *Biomes fermés* — 50 biomes (cumul) | +1 tuile/10 tuiles du biome fermé → +2/10 → +3/10 |
| 11 | **Aperçu prolongé** *(nouveau)* | *Triples connexions* — 15 réalisées (cumul, one-shot) | 3 tuiles visibles → +1/palier (4 puis 5) |
| 12 | **Emplacement Joker (Hold)** *(nouveau)* | *Quadruples connexions* — 8 réalisées (cumul, one-shot) | 1 utilisation/partie → +1/palier (2 puis 3) |
| 13 | **Deuxième chance** *(nouveau)* | *Quintuples connexions* — 5 réalisées (cumul, one-shot) | 1 utilisation/partie → +1/palier (2 puis 3) |
| 14 | **Couleur détestée** *(nouveau)* | *Biomes fermés* — 100 biomes (cumul) | Exclut une couleur aléatoire pendant 5 tuiles → +3 (8) → +2 (10) |

**Coût de montée de niveau** (remplace `kUpgradeCosts = [100, 250]`) :
```
kUpgradeCosts = [20000, 50000]
```
Niveau 1→2 : 20 000 pièces. Niveau 2→3 : 50 000 pièces. Uniforme sur toutes les améliorations à paliers multiples.

**Note de simplification** : Emplacement Joker et Deuxième chance partagent maintenant exactement le même mécanisme de compteur ("N utilisations par partie, N = niveau"), ce qui permet de factoriser le code entre les deux au lieu de les traiter comme deux systèmes séparés.

---

## 2. Nouvelles quêtes nécessaires

### Catégories "record" (réutilisent `maxBiomeSizes`, déjà calculé par `BoardAnalysis`)
| id | catégorie | target | récompense |
|---|---|---|---|
| `forest_51` | `forestClusterSize` | 51 | unlock Vert+ |
| `water_51` | `waterClusterSize` | 51 | unlock Bleu+ |
| `plain_51` | `plainClusterSize` | 51 | unlock Jaune+ |
| `mountain_51` | `mountainClusterSize` | 51 | unlock Violet+ |

### Nouvelle catégorie "record de série" (nécessite un nouveau mécanisme de jeu)
| id | catégorie | target | récompense |
|---|---|---|---|
| `best_streak_10` | `bestConnectionStreak` | 10 | unlock Combo+ |

### Quêtes one-shot sur catégories existantes (partagent la catégorie avec les quêtes répétables de farm, mais `isRepeatable: false`)
| id | catégorie | target | récompense |
|---|---|---|---|
| `connections_triple_first` | `tripleConnections` | 15 | unlock Aperçu prolongé |
| `connections_quad_first` | `quadConnections` | 8 | unlock Emplacement Joker |
| `connections_quint_first` | `quintConnections` | 5 | unlock Deuxième chance |

### Extension de la chaîne `biomes_closed`
`biomes_10` (existant, 75 pièces) → `biomes_25` (existant, Connexions doublées) → **`biomes_50`** (nouveau, Bonus de clôture) → **`biomes_100`** (nouveau, Couleur détestée)

---

## 3. Découpage en stories (chacune volontairement petite et isolée)

L'ordre suit les dépendances : d'abord tout ce qui est pur seed/data (sans risque, sans nouveau mécanisme), puis les mécaniques de jeu une par une, de la plus simple à la plus engageante en UI.

### Phase A — Seed & données (aucun nouveau mécanisme de jeu)

- **Story A1 — Coût de montée de niveau**
  Remplacer `kUpgradeCosts` par `[20000, 50000]`.

- **Story A2 — Renommage Villages+ → Rouge+**
  Renommer l'upgrade existante (id conservé, `name` changé).

- **Story A3 — Nouveaux pourcentages Pièces+**
  Passer les paliers de +10/20/30% à +25/50/100%.

- **Story A4 — Quêtes "cluster couleur" x4**
  Créer les 4 quêtes record (`forest_51`, `water_51`, `plain_51`, `mountain_51`) sur le modèle exact de `village_100` (aucune nouvelle logique de board analysis, `maxBiomeSizes` existe déjà).

- **Story A5 — Upgrades Vert+/Bleu+/Jaune+/Violet+ (seed uniquement)**
  Ajouter les 4 lignes upgrades liées aux quêtes de A4. *(L'effet réel — bonus % par biome — est traité en Story B5, ici on ne fait que le déblocage.)*

- **Story A6 — Extension chaîne biomes_closed**
  Ajouter `biomes_50` et `biomes_100` à la suite de `biomes_25`.

- **Story A7 — Upgrades Bonus de clôture & Couleur détestée (seed uniquement)**
  Ajouter les 2 lignes upgrades liées aux quêtes de A6.

- **Story A8 — Quêtes one-shot connexions x3**
  Ajouter `connections_triple_first`, `connections_quad_first`, `connections_quint_first` (même catégorie que les quêtes répétables existantes, mais `isRepeatable: false`).

- **Story A9 — Upgrades Aperçu prolongé / Emplacement Joker / Deuxième chance (seed uniquement)**
  Ajouter les 3 lignes upgrades liées aux quêtes de A8.

- **Story A10 — Catégorie + quête bestConnectionStreak**
  Ajouter la nouvelle catégorie `bestConnectionStreak` et la quête `best_streak_10`.

- **Story A11 — Upgrade Combo+ (seed uniquement)**
  Ajouter la ligne upgrade liée à la quête de A10.

- **Story A12 — Migration de schéma**
  Une seule migration regroupant A1 à A11 (bump de version, insertOrIgnore des nouvelles lignes, update des anciennes).

### Phase B — Mécaniques de jeu (une story = un mécanisme testable isolément)

- **Story B1 — Génération du biome à part par couleur**
  Généraliser le bonus % pièces par biome (actuellement seulement `villageCoinsPercentBonus`) : 4 nouveaux `UpgradeEffectType` (`forestCoinsPercentBonus`, `waterCoinsPercentBonus`, `plainCoinsPercentBonus`, `mountainCoinsPercentBonus`), même logique que Rouge+ appliquée à chaque biome. Active les upgrades de Story A5.

- **Story B2 — Compteur de série de connexions (streak)**
  Ajouter en session un compteur de série consécutive (incrémenté à chaque pose qui connecte ≥1 côté, remis à 0 sinon), remonté en fin de partie comme un record (même schéma que `largestVillage`). Alimente la quête `best_streak_10`.

- **Story B3 — Effet Combo+**
  Utilise le compteur de B2 : à chaque multiple de 5 dans la série en cours, ajoute des tuiles bonus à la pile selon le niveau (1/2/3 tuiles).

- **Story B4 — Aperçu prolongé**
  Exposer N tuiles de la file d'attente dans `TileStackState` (au lieu d'une seule) et adapter le HUD (`tile_stack_hud.dart`) pour afficher dynamiquement 2 à 5 tuiles selon le niveau de l'upgrade.

- **Story B5 — Couleur détestée**
  `generateTilePool` accepte un biome exclu + une durée (nombre de tuiles). À l'initialisation de la pile, si l'upgrade est active : tirer un biome au hasard et l'exclure pendant N tuiles (5/8/10 selon niveau).

- **Story B6 — Détection de fermeture de biome en direct**
  Prérequis technique pour B7 : après chaque pose, calculer quels biomes viennent *tout juste* de se fermer (et leur taille), plutôt que d'attendre le total de fin de partie (`closedBiomes` actuel ne calcule qu'un total agrégé).

- **Story B7 — Effet Bonus de clôture**
  Utilise B6 : à chaque fermeture détectée, ajoute `(taille du biome ÷ 10) × niveau` tuiles bonus à la pile.

- **Story B8 — Connexions doublées à 3 paliers**
  Refactoriser `applyConnectionMultiplier` pour qu'il reçoive le nombre de côtés connectés et n'applique le ×2 qu'aux paliers débloqués par le niveau courant (lvl1 : quint+sext, lvl2 : +quad, lvl3 : +triple).

- **Story B9 — Compteur d'utilisations par partie (base commune Hold + Deuxième chance)**
  Mécanisme générique : "N utilisations/partie" décrémenté à l'usage, réinitialisé à chaque nouvelle partie, N = niveau de l'upgrade concernée. Utilisé par B10 et B11.

- **Story B10 — Emplacement Joker (Hold)**
  Encart HUD dédié, état "tuile en réserve", logique d'échange tuile active ↔ tuile en réserve, consomme une utilisation de B9.

- **Story B11 — Deuxième chance**
  Bouton HUD → mode sélection sur le plateau → retrait d'une tuile posée → réinjection en tête de pile, consomme une utilisation de B9.

---

## 4. Ordre d'implémentation suggéré

1. **Phase A en bloc** (A1 → A12) : aucun risque, juste de la donnée, testable en un coup.
2. **B1** (généralisation coins bonus par biome) : réutilise un pattern déjà en prod.
3. **B2 → B3** (streak + Combo+) : mécanique isolée, pas de dépendance UI lourde.
4. **B4** (aperçu prolongé) : petit changement HUD, sans nouvelle interaction.
5. **B5** (couleur détestée) : isolé à la génération de pile.
6. **B6 → B7** (bonus de clôture) : B6 est un prérequis technique pur, B7 branche l'effet dessus.
7. **B8** (connexions doublées 3 paliers) : refactor ciblé d'une fonction existante.
8. **B9 → B10 → B11** (Hold + Deuxième chance) : le plus gros morceau UI, laissé pour la fin ; B9 factorise la logique commune avant de brancher les deux interactions.

Chaque story de la phase B est pensée pour être livrable et testable indépendamment des suivantes.
