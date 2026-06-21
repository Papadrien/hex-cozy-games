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

// ── AdMob — Story 3.1a / 3.1b ────────────────────────────────────────────

/// ID de test AdMob pour les bannières (Android).
/// Remplacer par l'ID production avant release.
const String kAdMobBannerTestIdAndroid =
    'ca-app-pub-3940256099942544/6300978111';

/// ID de test AdMob pour les bannières (iOS).
const String kAdMobBannerTestIdIOS =
    'ca-app-pub-3940256099942544/2934735716';

/// ID de test AdMob pour les interstitielles (Android).
/// Remplacer par l'ID production avant release.
const String kAdMobInterstitialTestIdAndroid =
    'ca-app-pub-3940256099942544/1033173712';

/// ID de test AdMob pour les interstitielles (iOS).
const String kAdMobInterstitialTestIdIOS =
    'ca-app-pub-3940256099942544/4411468910';

/// Hauteur standard d'une bannière AdMob en dp.
const double kAdBannerHeight = 50.0;

/// Nombre de tuiles posées entre chaque interstitielle AdMob (Story 3.1b).
const int kAdInterstitialFrequency = 20;
