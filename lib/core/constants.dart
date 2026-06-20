/// Constantes globales de l'application.
///
/// Centralise les valeurs d'équilibrage et de configuration qui doivent
/// pouvoir être ajustées sans toucher à la logique métier (voir
/// 01_contexte_architecture.md, section 9 — risques et mitigation).
library;

/// Nombre de tuiles données au joueur au départ d'une partie (avant bonus
/// d'amélioration "Tuiles de départ+"). Valeur à équilibrer via playtests.
const int kStartingTiles = 21;

/// Nombre de tuiles visibles dans la pile (story 1.4).
const int kVisibleStackSize = 3;

/// Nombre maximal d'améliorations sélectionnables avant une partie (story 5.4).
const int kMaxSelectedUpgrades = 3;

/// Nombre maximal de `BiomeType` différents par tuile (contexte 3.6).
const int kMaxBiomeTypesPerTile = 3;

/// Barème de tuiles bonus selon le nombre de côtés connectés (Story 1.6b).
/// 3→+1, 4→+2, 5→+5, 6→+10.
const Map<int, int> kBonusScale = {
  3: 1,
  4: 2,
  5: 5,
  6: 10,
};

/// Taille de base de l'hexagone (rayon circumscrit) en pixels logiques.
/// Source unique : utilisée par [HexGridComponent] pour le layout de la grille
/// et par [TileComponent] comme valeur par défaut du paramètre hexSize.
const double kHexSize = 48.0;
