/// Constantes globales de l'application.
///
/// Centralise les valeurs d'équilibrage et de configuration qui doivent
/// pouvoir être ajustées sans toucher à la logique métier (voir
/// 01_contexte_architecture.md, section 9 — risques et mitigation).
library;

import '../game/hex_cell.dart';

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

// ── AdMob — Story 3.2a ────────────────────────────────────────────────────

/// ID de test AdMob pour les rewarded (Android).
const String kAdMobRewardedTestIdAndroid =
    'ca-app-pub-3940256099942544/5224354917';

/// ID de test AdMob pour les rewarded (iOS).
const String kAdMobRewardedTestIdIOS =
    'ca-app-pub-3940256099942544/1712485313';

/// Nombre de pièces créditées après visionnage de la pub rewarded quotidienne.
const int kAdRewardedCoins = 50;

// ── Boutique — Story 3.3a / 3.5a ─────────────────────────────────────────────

/// ID produit IAP non-consommable pour le premium (Story 3.5a).
const String kPremiumProductId = 'premium';

/// Packs de pièces (pièces, prix, ID produit IAP).
const List<CoinPack> kCoinPacks = [
  CoinPack(coins: 100, price: '\$0.99', productId: 'coins_small'),
  CoinPack(coins: 500, price: '\$3.99', productId: 'coins_medium'),
  CoinPack(coins: 1200, price: '\$7.99', productId: 'coins_large'),
];

class CoinPack {
  final int coins;
  final String price;
  final String productId;

  const CoinPack({
    required this.coins,
    required this.price,
    required this.productId,
  });
}

// ── Demande d'avis (rate-us) ──────────────────────────────────────────────

/// Nombre de parties jouées (cumul `player_stats.total_games_played`) à
/// partir duquel la bottom sheet de demande d'avis est proposée une seule
/// fois (voir [ReviewService] dans `services/review_service.dart`).
const int kReviewPromptGamesThreshold = 3;

// ── Couleurs bonus progressives ──────────────────────────────────────────

/// Seuil (nombre de tuiles posées EN PARTIE, cumul de la session en cours)
/// à partir duquel chaque couleur bonus peut apparaître sur les tuiles de
/// la pile à poser. [BiomeType.forest], [BiomeType.village], [BiomeType.plain],
/// [BiomeType.water] et [BiomeType.mountain] sont disponibles dès le début
/// (absents de cette map = toujours débloqués).
///
/// Les tuiles déjà posées sur le plateau ne sont jamais modifiées : seule la
/// génération des NOUVELLES tuiles de la pile est concernée. Comme la pile
/// affiche les [kVisibleStackSize] prochaines tuiles à l'avance, une couleur
/// peut apparaître dans la pile visible un peu avant que le seuil ne soit
/// effectivement atteint (ex. seuil à 50 → visible dès la 47ᵉ tuile posée
/// avec kVisibleStackSize = 3), ce qui est le comportement voulu.
const Map<BiomeType, int> kBiomeUnlockThresholds = {
  BiomeType.orange: 50,
  BiomeType.pink: 100,
  BiomeType.black: 150,
  BiomeType.white: 300,
};

/// Renvoie la liste des [BiomeType] utilisables pour une tuile qui occupera
/// la position [placementPosition] dans l'ordre de pose (1 = première tuile
/// posée en partie). Les biomes de base sont toujours inclus ; les couleurs
/// bonus sont ajoutées dès que [placementPosition] atteint leur seuil dans
/// [kBiomeUnlockThresholds].
List<BiomeType> unlockedBiomesAt(int placementPosition) {
  return BiomeType.values.where((b) {
    final threshold = kBiomeUnlockThresholds[b];
    return threshold == null || placementPosition >= threshold;
  }).toList();
}
