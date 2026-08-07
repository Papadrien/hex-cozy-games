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

/// Orange du bouton « Regarder une publicité » pour des pièces
/// (`home_screen.dart`, `_RewardedAdButton`) — distinct du doré des
/// récompenses ([kRewardGold]) pour bien démarquer ce bouton spécifique.
const Color kAdRewardOrange = Color(0xFFFF8F00);

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

/// Teal tropical pour le bouton Jouer principal — aussi la teinte "verte"
/// utilisée sur les boutons secondaires (pause, croix d'annulation,
/// paramètres/boutique de l'écran d'accueil…).
const Color kTropicalTeal = Color(0xFF2A9D8F);

/// Bordure teal claire assortie à [kTropicalTeal] pour les boutons
/// secondaires reteintés en vert.
const Color kTropicalTealBorder = Color(0xFF3DBFAF);

/// Blanc glassmorphism pour les boutons secondaires.
const Color kGlassWhite = Color(0x33FFFFFF);

/// Bordure glassmorphism pour les boutons secondaires.
const Color kGlassBorder = Color(0x4DFFFFFF);

/// Bleu nuit glassmorphism — fond foncé des composants HUD (lisibilité
/// texte blanc améliorée par rapport à l'ancien bleu glacier clair).
const Color kGlassBlue = Color(0xFF2E3B52);

/// Bleu nuit des surfaces de dialogue (AlertDialog…) — plus sombre que
/// [kGlassBlue] pour bien détacher les modales du fond des écrans.
const Color kDialogNavy = Color(0xFF1A2F45);

/// Bordure glassmorphism commune — blanc translucide à 20% d'opacité,
/// utilisée comme contour par défaut de tous les composants vitrés (écran
/// d'accueil, sous-pages, HUD de jeu).
const Color kGlassBlueBorder = Color(0x33FFFFFF);

/// Orange pour les quêtes de type connexions multiples (répétables).
const Color kConnectionOrange = Color(0xFFFFB74D);

/// Or vif pour la quête record (meilleure partie en pièces gagnées).
const Color kRecordGold = Color(0xFFFFD54F);

/// Violet pour la section des 4 quêtes "cluster couleur" (forêt/eau/
/// plaine/montagne — débloquent Vert+/Bleu+/Jaune+/Violet+).
const Color kBiomeColorQuestPurple = Color(0xFFBA68C8);
