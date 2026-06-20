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
