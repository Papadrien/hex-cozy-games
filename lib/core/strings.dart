/// Wrapper i18n basé sur [AppLocalizations] (généré via flutter gen-l10n).
///
/// Fournit un accès concis via `context.tr.xxx` et [biomeName] pour les
/// traductions dynamiques non couvertes par les fichiers ARB.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Accès rapide aux traductions depuis n'importe quel [BuildContext].
extension AppLocalizationsX on BuildContext {
  AppLocalizations get tr => AppLocalizations.of(this)!;
}

/// Traduit une couleur de tuile (clé technique anglaise) vers l'affichage
/// localisé. Les tuiles n'ont pas de rendu thématique (village, forêt...) —
/// seule la couleur est visible, donc on affiche uniquement des noms de
/// couleur.
String biomeName(BuildContext context, String biome) {
  if (!AppLocalizations.of(context)!.localeName.startsWith('fr')) return biome;
  switch (biome) {
    case 'forest':
      return 'Vert';
    case 'village':
      return 'Rouge';
    case 'plain':
      return 'Jaune';
    case 'water':
      return 'Bleu';
    case 'mountain':
      return 'Violet';
    case 'orange':
      return 'Orange';
    case 'pink':
      return 'Rose';
    case 'black':
      return 'Noir';
    case 'white':
      return 'Blanc';
    default:
      return biome;
  }
}

/// Description localisée d'une amélioration à partir de son `upgradeId`
/// technique (colonne `id` de [UpgradeRow]). Rédigées à la main, une par
/// amélioration (FR/EN via l10n). Partagée entre l'écran Build et le HUD de
/// jeu (encart des améliorations actives) pour éviter la duplication.
String upgradeDescription(BuildContext context, String upgradeId) {
  final tr = context.tr;
  switch (upgradeId) {
    case 'starting_tiles_plus':
      return tr.upgrade_desc_starting_tiles_plus;
    case 'doubled_connections':
      return tr.upgrade_desc_doubled_connections;
    case 'coins_plus':
      return tr.upgrade_desc_coins_plus;
    case 'villages_plus':
      return tr.upgrade_desc_villages_plus;
    case 'combo_plus':
      return tr.upgrade_desc_combo_plus;
    case 'extended_preview':
      return tr.upgrade_desc_extended_preview;
    case 'hold_slot':
      return tr.upgrade_desc_hold_slot;
    case 'second_chance':
      return tr.upgrade_desc_second_chance;
    case 'forest_plus':
      return tr.upgrade_desc_forest_plus;
    case 'water_plus':
      return tr.upgrade_desc_water_plus;
    case 'plain_plus':
      return tr.upgrade_desc_plain_plus;
    case 'mountain_plus':
      return tr.upgrade_desc_mountain_plus;
    case 'closure_bonus':
      return tr.upgrade_desc_closure_bonus;
    case 'hated_color':
      return tr.upgrade_desc_hated_color;
    case 'millionaire':
      return tr.upgrade_desc_millionaire;
    case 'warehouse':
      return tr.upgrade_desc_warehouse;
    default:
      return '';
  }
}
