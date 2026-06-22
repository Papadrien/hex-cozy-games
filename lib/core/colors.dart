/// Design tokens centralisés — remplace toutes les couleurs UI en hex codé en dur.
///
/// Les couleurs de biome restent dans [BiomeColor] (tile_component.dart).
library;

import 'dart:ui' show Color;

/// Fond sombre principal (noir bleuté).
const Color kBackgroundColor = Color(0xFF1A2332);

/// Bleu de marque (utilisé pour les boutons, accents, sélections).
const Color kBrandBlue = Color(0xFF6FA8DC);

/// Or pour les récompenses pièces (cercle extérieur).
const Color kRewardGold = Color(0xFFFFD600);

/// Or foncé pour les récompenses pièces (cercle intérieur).
const Color kRewardGoldDark = Color(0xFFFFA000);

/// Blanc pour les symboles pièces.
const Color kRewardWhite = Color(0xFFFFFFFF);

/// Bleu clair pour les icônes de tuiles bonus.
const Color kBonusBlueLight = Color(0xFF29B6F6);

/// Bleu clair (plus pâle) pour l'intérieur des icônes bonus.
const Color kBonusBlueLighter = Color(0xFF4FC3F7);

/// Rouge corail — abandon, actions destructrices.
const Color kDestructiveRed = Color(0xFFE57373);

/// Vert pour les sections débloquées / succès.
const Color kSuccessGreen = Color(0xFF4CAF50);

/// Violet pour les récompenses de type déblocage d'amélioration.
const Color kUpgradePurple = Color(0xFFCE93D8);

/// Bleu pour les quêtes de type biomes fermés.
const Color kQuestBlue = Color(0xFF64B5F6);

/// Jaune/ambre pour les pièces et icônes de valeur.
const Color kCoinAmber = Color(0xFFFFC107); // Colors.amber
