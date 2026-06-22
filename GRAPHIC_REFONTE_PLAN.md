# Refonte Graphique — Hex Cozy Games
## Direction artistique : Low-Poly / HD2D Île Paradisiaque

### Concept
"Hex Cozy Island" — chaque partie sur une île paradisiaque vue en 3/4 isométrique.
Tuiles = parcelles de terrain low-poly assemblées pour créer un archipel.

### Biomes

| Biome | Couleur dominante | Ambiance |
|---|---|---|
| Plaine (`plain`) | Vert clair `#8BC34A` | Herbe tropicale, petits palmiers épars |
| Champ de fleurs (`flowerField`) | Rose/Mauve `#EC407A` | Tapis dense de fleurs, particules de pétales |
| Mangrove (`forest`) | Vert foncé `#2E7D32` | Arbres sur racines, eau sombre |
| Montagne volcanique (`mountain`) | Gris/Noir `#424242` + orangé `#FF6F00` | Roche basaltique, fissures de lave |
| Plage (`beach`) | Sable `#FDD835` + blanc écume | Transition terre-mer |
| Mer (`water`) | Turquoise `#26C6DA` à `#00838F` | Eau claire, reflets |
| Village (`village`) | Bois brun `#8D6E63` + chaud `#FFB74D` | Maisons pilotis, lanternes |

---

### Phases

#### Phase 1 — Fondation (palette + biomes)
- Ajouter `google_fonts` package + config Nunito dans l'app
- Remplacer `BiomeType` enum : `plain`, `flowerField`, `mangrove`, `mountain`, `beach`, `sea`, `village`
- Mettre à jour `BiomeColor` avec dégradé top face + 7 nouvelles couleurs
- Mettre à jour `generateTilePool()` (poids équilibrés)
- Palette globale dans `colors.dart`

#### Phase 2 — Ciel et fond d'écran
- Ciel dégradé (bleu clair → blanc/rose coucher)
- Nuages low-poly en parallaxe lente
- Nappe d'eau turquoise avec vagues animées (oscillation sinusoïdale)
- Soleil (demi-cercle ambré à l'horizon)

#### Phase 3 — Rendu des tuiles amélioré
- Relief variable selon le biome (montagne > village > plage)
- Dégradé sur chaque segment (plus clair au centre)
- Légers offsets aléatoires des sommets (naturel)
- Liseré de transition entre biomes différents
- Ombre portée au sol sous l'extrusion

#### Phase 4 — Décors HD2D procéduraux
- 1 décoration unique par biome dessinée via Canvas :
  - Plaine : palmiers (tronc courbe + feuilles)
  - Champ de fleurs : petits cercles roses/mauves groupés
  - Mangrove : racines en V + feuillage arrondi
  - Volcan : mini-cône + lueur orangée
  - Plage : coquillage/étoile de mer
  - Mer : vaguelettes blanches semi-transparentes
  - Village : maison (trapèze + toit + pilotis)
- Apparition aléatoire ~30% des tuiles

#### Phase 5 — UI thématique île
- Police Nunito partout
- Palette UI : dégradé sable/chaleur, bois clair
- Coins arrondis + ombres portées
- Badges arrondis avec micro-icônes thème

#### Phase 6 — Particules et polish
- Particules au placement (losanges colorés)
- Halo pulsant bouton Jouer
- Transitions douces

### Dépendances ajoutées
- `google_fonts: ^6.1.0`

### Fichiers impactés
- `lib/core/colors.dart`
- `lib/game/hex_cell.dart`
- `lib/game/hex_tile.dart`
- `lib/game/tile_component.dart`
- `lib/game/hex_grid_component.dart`
- `lib/game/background_component.dart` (nouveau)
- `lib/ui/game_screen.dart`
- `lib/ui/*.dart` (Nunito + couleurs)
- `lib/core/theme.dart`
- `pubspec.yaml`
