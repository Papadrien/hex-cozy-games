/// Design tokens centralisés — palette "Hex Cozy Island".
///
/// Thème île paradisiaque : tons sable, turquoise, vert tropical, bois chaud.
/// Les couleurs de biome (tuiles) sont définies dans [BiomeColor].
library;

import 'dart:ui' show Color;

/// Fond principal — dégradé sable/chaleur (clair, ou version foncée adaptée).
const Color kBackgroundColor = Color(0xFF1A2A32); // bleu-nuit tropical

/// Fond du jeu — eau turquoise claire.
const Color kGameBackground = Color(0xFF00F2E8);

/// Fond secondaire — sable clair pour cartes et modales.
const Color kIslandSand = Color(0xFFF5E6CA);

/// Fond secondaire foncé — bois clair tropical.
const Color kIslandWood = Color(0xFF8D6E63);

/// Turquoise de marque — boutons, accents.
const Color kBrandTurquoise = Color(0xFF26C6DA);

/// Bleu de marque (conservé pour compatibilité).
const Color kBrandBlue = Color(0xFF26C6DA);

/// Or pour les récompenses pièces.
const Color kRewardGold = Color(0xFFFFD600);

/// Or foncé pour les récompenses pièces.
const Color kRewardGoldDark = Color(0xFFFFA000);

/// Blanc.
const Color kRewardWhite = Color(0xFFFFFFFF);

/// Bleu clair pour icônes tuiles bonus.
const Color kBonusBlueLight = Color(0xFF29B6F6);

const Color kBonusBlueLighter = Color(0xFF4FC3F7);

/// Rouge corail — abandon, actions destructrices.
const Color kDestructiveRed = Color(0xFFE57373);

/// Vert succès.
const Color kSuccessGreen = Color(0xFF66BB6A);

/// Violet pour premium / déblocages.
const Color kUpgradePurple = Color(0xFFCE93D8);

/// Rose champ de fleurs.
const Color kFlowerPink = Color(0xFFEC407A);

/// Vert mangrove.
const Color kMangroveGreen = Color(0xFF2E7D32);

/// Sable plage.
const Color kBeachSand = Color(0xFFFDD835);

/// Turquoise mer.
const Color kSeaTurquoise = Color(0xFF00838F);

/// Bleu pour quêtes.
const Color kQuestBlue = Color(0xFF64B5F6);

/// Jaune/ambre pour pièces.
const Color kCoinAmber = Color(0xFFFFC107);

/// Fond de carte île (sable chaud semi-transparent).
const Color kIslandCard = Color(0xC0F5E6CA);

/// Variante foncée de carte île (bois tropical).
const Color kIslandCardDark = Color(0xB08D6E63);
