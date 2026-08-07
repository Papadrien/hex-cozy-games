/// Wrapper i18n basé sur [AppLocalizations] (généré via flutter gen-l10n).
///
/// Fournit un accès concis via `context.tr.xxx` et [biomeName] pour les
/// traductions dynamiques non couvertes par les fichiers ARB.
library;

import 'package:flutter/material.dart';

import '../core/game_enums.dart';
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
  final isFr = AppLocalizations.of(context)!.localeName.startsWith('fr');
  switch (biome) {
    case 'forest':
      return isFr ? 'Vert' : 'Green';
    case 'village':
      return isFr ? 'Rouge' : 'Red';
    case 'plain':
      return isFr ? 'Jaune' : 'Yellow';
    case 'water':
      return isFr ? 'Bleu' : 'Blue';
    case 'mountain':
      return isFr ? 'Violet' : 'Purple';
    case 'orange':
      return isFr ? 'Orange' : 'Orange';
    case 'pink':
      return isFr ? 'Rose' : 'Pink';
    case 'black':
      return isFr ? 'Noir' : 'Black';
    case 'white':
      return isFr ? 'Blanc' : 'White';
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

/// Nom localisé d'une amélioration à partir de son `upgradeId` technique
/// (colonne `id` de [UpgradeRow]). Les noms bruts sont stockés en français
/// dans `seed_data.dart` (BDD, colonne `name`) ; cette fonction fait le lien
/// vers les clés ARB FR/EN. Partagée entre l'écran Build et le HUD de jeu.
String upgradeName(BuildContext context, String upgradeId) {
  final tr = context.tr;
  switch (upgradeId) {
    case 'starting_tiles_plus':
      return tr.upgrade_name_starting_tiles_plus;
    case 'doubled_connections':
      return tr.upgrade_name_doubled_connections;
    case 'coins_plus':
      return tr.upgrade_name_coins_plus;
    case 'villages_plus':
      return tr.upgrade_name_villages_plus;
    case 'combo_plus':
      return tr.upgrade_name_combo_plus;
    case 'extended_preview':
      return tr.upgrade_name_extended_preview;
    case 'hold_slot':
      return tr.upgrade_name_hold_slot;
    case 'second_chance':
      return tr.upgrade_name_second_chance;
    case 'forest_plus':
      return tr.upgrade_name_forest_plus;
    case 'water_plus':
      return tr.upgrade_name_water_plus;
    case 'plain_plus':
      return tr.upgrade_name_plain_plus;
    case 'mountain_plus':
      return tr.upgrade_name_mountain_plus;
    case 'closure_bonus':
      return tr.upgrade_name_closure_bonus;
    case 'hated_color':
      return tr.upgrade_name_hated_color;
    case 'millionaire':
      return tr.upgrade_name_millionaire;
    case 'warehouse':
      return tr.upgrade_name_warehouse;
    default:
      return upgradeId;
  }
}

/// Libellés localisés de chaque palier d'effet pour un [effectType] donné
/// (sous-titre de la carte = palier courant, comparatif de niveaux = palier
/// courant vs. suivant). Même structure/longueur que
/// `upgradeAllLevelEffects` dans `progression_provider.dart` (conservée en
/// français, utilisée par les tests unitaires) mais localisée FR/EN via les
/// clés ARB.
List<String> upgradeEffectLevelLabels(
  BuildContext context,
  UpgradeEffectType effectType,
) {
  final tr = context.tr;
  switch (effectType) {
    case UpgradeEffectType.startingTilesBonus:
      return [
        tr.upgrade_effect_startingTilesBonus_0,
        tr.upgrade_effect_startingTilesBonus_1,
        tr.upgrade_effect_startingTilesBonus_2,
      ];
    case UpgradeEffectType.connectionBonusMultiplier:
      return [
        tr.upgrade_effect_connectionBonusMultiplier_0,
        tr.upgrade_effect_connectionBonusMultiplier_1,
        tr.upgrade_effect_connectionBonusMultiplier_2,
      ];
    case UpgradeEffectType.coinsPercentBonus:
      return [
        tr.upgrade_effect_coinsPercentBonus_0,
        tr.upgrade_effect_coinsPercentBonus_1,
        tr.upgrade_effect_coinsPercentBonus_2,
      ];
    case UpgradeEffectType.villageCoinsPercentBonus:
    case UpgradeEffectType.forestCoinsPercentBonus:
    case UpgradeEffectType.waterCoinsPercentBonus:
    case UpgradeEffectType.plainCoinsPercentBonus:
    case UpgradeEffectType.mountainCoinsPercentBonus:
      return [
        tr.upgrade_effect_biomeCoinsBonus_0,
        tr.upgrade_effect_biomeCoinsBonus_1,
        tr.upgrade_effect_biomeCoinsBonus_2,
      ];
    case UpgradeEffectType.closureBonusTiles:
      return [
        tr.upgrade_effect_closureBonusTiles_0,
        tr.upgrade_effect_closureBonusTiles_1,
        tr.upgrade_effect_closureBonusTiles_2,
      ];
    case UpgradeEffectType.hatedColorExclusion:
      return [
        tr.upgrade_effect_hatedColorExclusion_0,
        tr.upgrade_effect_hatedColorExclusion_1,
        tr.upgrade_effect_hatedColorExclusion_2,
      ];
    case UpgradeEffectType.extendedPreviewCount:
      return [
        tr.upgrade_effect_extendedPreviewCount_0,
        tr.upgrade_effect_extendedPreviewCount_1,
        tr.upgrade_effect_extendedPreviewCount_2,
      ];
    case UpgradeEffectType.holdSlotUses:
      return [
        tr.upgrade_effect_holdSlotUses_0,
        tr.upgrade_effect_holdSlotUses_1,
        tr.upgrade_effect_holdSlotUses_2,
      ];
    case UpgradeEffectType.secondChanceUses:
      return [
        tr.upgrade_effect_secondChanceUses_0,
        tr.upgrade_effect_secondChanceUses_1,
        tr.upgrade_effect_secondChanceUses_2,
      ];
    case UpgradeEffectType.comboBonusTiles:
      return [
        tr.upgrade_effect_comboBonusTiles_0,
        tr.upgrade_effect_comboBonusTiles_1,
        tr.upgrade_effect_comboBonusTiles_2,
      ];
    case UpgradeEffectType.millionaireCoins:
      return [tr.upgrade_effect_millionaireCoins_0];
    case UpgradeEffectType.warehouseStartingTiles:
      return [tr.upgrade_effect_warehouseStartingTiles_0];
  }
}

/// Description localisée d'une quête à partir de son `questId` technique
/// (colonne `id` de [PermanentQuestRow] / des quêtes quotidiennes) et de sa
/// `targetValue`. Les textes bruts sont stockés en français dans
/// `seed_data.dart` (BDD) ; cette fonction fait le lien vers les clés ARB
/// FR/EN, en réutilisant un même gabarit paramétré pour les quêtes qui ne
/// diffèrent que par leur palier (ex : les 5 quêtes `daily_coins_*`).
String questDescription(BuildContext context, String questId, int targetValue) {
  final tr = context.tr;
  switch (questId) {
    case 'best_game_coins_500':
      return tr.quest_desc_best_game_coins(targetValue);
    case 'forest_15':
      return tr.quest_desc_cluster_forest(targetValue);
    case 'water_20':
      return tr.quest_desc_cluster_water(targetValue);
    case 'plain_25':
      return tr.quest_desc_cluster_plain(targetValue);
    case 'mountain_30':
      return tr.quest_desc_cluster_mountain(targetValue);
    case 'village_10':
    case 'daily_village_3':
    case 'daily_village_5':
    case 'daily_village_8':
      return tr.quest_desc_cluster_village(targetValue);
    case 'biomes_50':
    case 'biomes_100':
    case 'biomes_10':
    case 'biomes_25':
    case 'daily_biomes_2':
    case 'daily_biomes_3':
    case 'daily_biomes_5':
      return tr.quest_desc_biomes_closed(targetValue);
    case 'coins_500':
    case 'coins_1000':
    case 'coins_2000':
    case 'coins_3000':
    case 'coins_5000':
      return tr.quest_desc_coins_total(targetValue);
    case 'daily_coins_15':
    case 'daily_coins_30':
    case 'daily_coins_50':
      return tr.quest_desc_coins_simple(targetValue);
    case 'best_streak_20':
    case 'best_streak_40':
    case 'best_streak_60':
    case 'best_streak_80':
    case 'best_streak_100':
      return tr.quest_desc_streak(targetValue);
    case 'connections_triple':
      return tr.quest_desc_triple_connection;
    case 'connections_quad':
      return tr.quest_desc_quad_connection;
    case 'connections_quint':
      return tr.quest_desc_quint_connection;
    case 'connections_sext':
      return tr.quest_desc_sext_connection;
    case 'connections_triple_first':
      return tr.quest_desc_triple_connections_count(targetValue);
    case 'connections_quad_first':
      return tr.quest_desc_quad_connections_count(targetValue);
    case 'connections_quint_first':
      return tr.quest_desc_quint_connections_count(targetValue);
    default:
      return '';
  }
}
