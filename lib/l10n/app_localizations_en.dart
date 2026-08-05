// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get pause_resume => 'Resume';

  @override
  String get pause_options => 'Options';

  @override
  String get options_sound => 'Sound';

  @override
  String get options_music => 'Music';

  @override
  String get options_sfx => 'Sound effects';

  @override
  String get options_musicVolume => 'Music volume';

  @override
  String get options_sfxVolume => 'Sound effects volume';

  @override
  String get options_vibrations => 'Vibration';

  @override
  String get pause_saveAndQuit => 'Save and quit';

  @override
  String get pause_abandon => 'Abandon';

  @override
  String get pause_abandonConfirmTitle =>
      'Are you sure you want to abandon this game?';

  @override
  String get pause_abandonConfirmBody =>
      'The coins earned during this game will be lost.';

  @override
  String get pause_abandonConfirmCancel => 'Cancel';

  @override
  String get pause_abandonConfirmConfirm => 'Abandon';

  @override
  String get home_play => 'Play';

  @override
  String get home_resume => 'Resume';

  @override
  String get reward_coins => ' bonus';

  @override
  String get reward_bonusTiles => ' bonus tiles';

  @override
  String get results_title => 'Game Over!';

  @override
  String get results_tilesPlaced => 'Tiles placed';

  @override
  String get results_connections => 'Connections';

  @override
  String get results_coins => 'Coins earned';

  @override
  String get results_connections3 => '3 sides';

  @override
  String get results_connections4 => '4 sides';

  @override
  String get results_connections5 => '5 sides';

  @override
  String get results_connections6 => '6 sides';

  @override
  String get results_replay => 'Replay';

  @override
  String get results_home => 'Home';

  @override
  String get game_sessionCoins => 'Game coins';

  @override
  String get game_undo_semanticLabel => 'Undo last tile placement';

  @override
  String get game_holdSlot_tooltip => 'Hold slot: swap with your active tile';

  @override
  String get game_secondChance_tooltip =>
      'Second chance: take back a placed tile';

  @override
  String get game_secondChance_tooltipActive =>
      'Tap a placed tile to take it back';

  @override
  String get home_totalCoins => 'Total coins';

  @override
  String get tutorial_step1 =>
      'Glowing tiles are the spots where you can place your tile';

  @override
  String get tutorial_step2 => 'Swipe to rotate it';

  @override
  String get tutorial_step3 => 'Coin icons show you what you’ll earn';

  @override
  String get tutorial_step4 =>
      'Tap anywhere on the screen to confirm the placement';

  @override
  String get tutorial_step5 =>
      'The cross on the tile stack removes the preview.';

  @override
  String get tutorial_step6 =>
      'Use the Undo button to undo the last placed tile.';

  @override
  String get tutorial_step7 =>
      'Match identical sides to earn bonus tiles and coins';

  @override
  String get tutorial_skip => 'Skip';

  @override
  String get quests_title => 'Quests';

  @override
  String get quests_category_coins => 'Coins earned';

  @override
  String get quests_category_record => 'Coins record';

  @override
  String get quests_category_village => 'Red';

  @override
  String get quests_category_biomes => 'Closed color zones';

  @override
  String get quests_category_connections => 'Multi-side connections';

  @override
  String get quests_category_biome_colors => 'Color groups';

  @override
  String get quests_category_streak => 'Connection streak';

  @override
  String get quests_category_daily => 'Daily quests';

  @override
  String get quests_status_active => 'Active';

  @override
  String get quests_status_completed => 'Completed';

  @override
  String get quests_status_locked => 'Locked';

  @override
  String get quests_tap_to_claim => 'Tap to claim';

  @override
  String get quests_reward_coins => 'Reward';

  @override
  String get quests_reward_upgrade => 'Unlocks power-up';

  @override
  String get quests_progress => 'Progress';

  @override
  String get quests_empty => 'No quests available';

  @override
  String get quests_close => 'Close';

  @override
  String get quests_next_reward => 'Next reward';

  @override
  String quest_desc_best_game_coins(Object value) {
    return 'Earn $value coins in a single game';
  }

  @override
  String quest_desc_cluster_forest(Object value) {
    return 'Make a green group of $value tiles';
  }

  @override
  String quest_desc_cluster_water(Object value) {
    return 'Make a blue group of $value tiles';
  }

  @override
  String quest_desc_cluster_plain(Object value) {
    return 'Make a yellow group of $value tiles';
  }

  @override
  String quest_desc_cluster_mountain(Object value) {
    return 'Make a purple group of $value tiles';
  }

  @override
  String quest_desc_cluster_village(Object value) {
    return 'Make a red group of $value tiles';
  }

  @override
  String quest_desc_biomes_closed(Object value) {
    return 'Close $value color zones';
  }

  @override
  String quest_desc_coins_total(Object value) {
    return 'Earn $value coins total';
  }

  @override
  String quest_desc_coins_simple(Object value) {
    return 'Earn $value coins';
  }

  @override
  String quest_desc_streak(Object value) {
    return 'Reach a streak of $value consecutive connections';
  }

  @override
  String get quest_desc_triple_connection => 'Triple connection made';

  @override
  String get quest_desc_quad_connection => 'Quadruple connection made';

  @override
  String get quest_desc_quint_connection => 'Quintuple connection made';

  @override
  String get quest_desc_sext_connection => 'Sextuple connection made';

  @override
  String quest_desc_triple_connections_count(Object value) {
    return 'Make $value triple connections';
  }

  @override
  String quest_desc_quad_connections_count(Object value) {
    return 'Make $value quadruple connections';
  }

  @override
  String quest_desc_quint_connections_count(Object value) {
    return 'Make $value quintuple connections';
  }

  @override
  String get upgrades_title => 'Power-ups';

  @override
  String get upgrades_locked => 'Locked';

  @override
  String get upgrades_hiddenEffect => '???';

  @override
  String get upgrades_unlockCondition => 'Unlock condition';

  @override
  String get upgrades_upgradeButton => 'Upgrade';

  @override
  String get upgrades_level => 'Level';

  @override
  String get upgrades_cost => 'Cost';

  @override
  String get upgrades_max => 'MAX';

  @override
  String get upgrades_noneUnlocked => 'No power-ups unlocked yet';

  @override
  String get upgrades_confirmButton => 'Confirm?';

  @override
  String get upgrade_desc_starting_tiles_plus =>
      'Increases the number of tiles you start each game with.';

  @override
  String get upgrade_desc_doubled_connections =>
      'Increases the bonus tiles earned from five-side and six-side connections.';

  @override
  String get upgrade_desc_coins_plus =>
      'Grants 1 bonus coin whenever you earn at least N coins on a placement.';

  @override
  String get upgrade_desc_villages_plus =>
      'Grants 1 bonus coin whenever you connect at least N red sides on a placement.';

  @override
  String get upgrade_desc_combo_plus =>
      'Grants 1 bonus tile every N double connections made during the game.';

  @override
  String get upgrade_desc_extended_preview =>
      'Reveals more upcoming tiles in the stack, so you can plan further ahead.';

  @override
  String get upgrade_desc_hold_slot =>
      'Lets you store a tile and put it back into the tile stack later.';

  @override
  String get upgrade_desc_second_chance =>
      'Lets you take back a tile you\'ve already placed.';

  @override
  String get upgrade_desc_forest_plus =>
      'Grants 1 bonus coin whenever you connect at least N green sides on a placement.';

  @override
  String get upgrade_desc_water_plus =>
      'Grants 1 bonus coin whenever you connect at least N blue sides on a placement.';

  @override
  String get upgrade_desc_plain_plus =>
      'Grants 1 bonus coin whenever you connect at least N yellow sides on a placement.';

  @override
  String get upgrade_desc_mountain_plus =>
      'Grants 1 bonus coin whenever you connect at least N purple sides on a placement.';

  @override
  String get upgrade_desc_closure_bonus =>
      'Grants bonus tiles every time a color zone closes completely.';

  @override
  String get upgrade_desc_hated_color =>
      'Tap this power-up during the game to choose a color to temporarily exclude from the tile stack, a limited number of times per game. Wait for the current exclusion to end before you can trigger a new one.';

  @override
  String get upgrade_hated_color_picker_title => 'Choose the color to exclude';

  @override
  String get upgrade_desc_millionaire =>
      'Instantly credits 1,000,000 coins to your profile (developer tool).';

  @override
  String get upgrade_desc_warehouse =>
      'Starts a game with 500 tiles in reserve (developer tool).';

  @override
  String get upgrade_name_starting_tiles_plus => 'Cargo';

  @override
  String get upgrade_name_doubled_connections => 'Generous Tide';

  @override
  String get upgrade_name_coins_plus => 'Loot';

  @override
  String get upgrade_name_villages_plus => 'Red';

  @override
  String get upgrade_name_combo_plus => 'Trade Winds';

  @override
  String get upgrade_name_extended_preview => 'Spyglass';

  @override
  String get upgrade_name_hold_slot => 'Pouch';

  @override
  String get upgrade_name_second_chance => 'Undertow';

  @override
  String get upgrade_name_forest_plus => 'Green';

  @override
  String get upgrade_name_water_plus => 'Blue';

  @override
  String get upgrade_name_plain_plus => 'Yellow';

  @override
  String get upgrade_name_mountain_plus => 'Purple';

  @override
  String get upgrade_name_closure_bonus => 'Atoll';

  @override
  String get upgrade_name_hated_color => 'Exile';

  @override
  String get upgrade_name_millionaire => 'Millionaire';

  @override
  String get upgrade_name_warehouse => 'Warehouse';

  @override
  String get upgrade_effect_startingTilesBonus_0 => '+2 starting tiles';

  @override
  String get upgrade_effect_startingTilesBonus_1 => '+5 starting tiles';

  @override
  String get upgrade_effect_startingTilesBonus_2 => '+10 starting tiles';

  @override
  String get upgrade_effect_connectionBonusMultiplier_0 =>
      '+1 bonus tile (5-6 connection)';

  @override
  String get upgrade_effect_connectionBonusMultiplier_1 =>
      '+2 bonus tiles (5-6 connection)';

  @override
  String get upgrade_effect_connectionBonusMultiplier_2 =>
      '+5 bonus tiles (5-6 connection)';

  @override
  String get upgrade_effect_coinsPercentBonus_0 =>
      '+1 coin per 8 coins earned';

  @override
  String get upgrade_effect_coinsPercentBonus_1 =>
      '+1 coin per 4 coins earned';

  @override
  String get upgrade_effect_coinsPercentBonus_2 =>
      '+1 coin per 2 coins earned';

  @override
  String get upgrade_effect_biomeCoinsBonus_0 => '+1 coin per 4 sides';

  @override
  String get upgrade_effect_biomeCoinsBonus_1 => '+1 coin per 2 sides';

  @override
  String get upgrade_effect_biomeCoinsBonus_2 => '+1 coin per side';

  @override
  String get upgrade_effect_closureBonusTiles_0 =>
      '+1 bonus tile / 8 zone tiles';

  @override
  String get upgrade_effect_closureBonusTiles_1 =>
      '+2 bonus tiles / 8 zone tiles';

  @override
  String get upgrade_effect_closureBonusTiles_2 =>
      '+3 bonus tiles / 8 zone tiles';

  @override
  String get upgrade_effect_hatedColorExclusion_0 =>
      'Excludes a color (5 tiles), 1 use';

  @override
  String get upgrade_effect_hatedColorExclusion_1 =>
      'Excludes a color (8 tiles), 2 uses';

  @override
  String get upgrade_effect_hatedColorExclusion_2 =>
      'Excludes a color (10 tiles), 3 uses';

  @override
  String get upgrade_effect_extendedPreviewCount_0 => 'See 4 upcoming tiles';

  @override
  String get upgrade_effect_extendedPreviewCount_1 => 'See 5 upcoming tiles';

  @override
  String get upgrade_effect_extendedPreviewCount_2 => 'See 6 upcoming tiles';

  @override
  String get upgrade_effect_holdSlotUses_0 => 'Stores a tile, 1 use';

  @override
  String get upgrade_effect_holdSlotUses_1 => 'Stores a tile, 2 uses';

  @override
  String get upgrade_effect_holdSlotUses_2 => 'Stores a tile, 3 uses';

  @override
  String get upgrade_effect_secondChanceUses_0 =>
      'Removes a placed tile, 1 use';

  @override
  String get upgrade_effect_secondChanceUses_1 =>
      'Removes a placed tile, 2 uses';

  @override
  String get upgrade_effect_secondChanceUses_2 =>
      'Removes a placed tile, 3 uses';

  @override
  String get upgrade_effect_comboBonusTiles_0 =>
      'Bonus tile every 10 double connections';

  @override
  String get upgrade_effect_comboBonusTiles_1 =>
      'Bonus tile every 8 double connections';

  @override
  String get upgrade_effect_comboBonusTiles_2 =>
      'Bonus tile every 5 double connections';

  @override
  String get upgrade_effect_millionaireCoins_0 => '+1,000,000 coins';

  @override
  String get upgrade_effect_warehouseStartingTiles_0 => '+500 starting tiles';

  @override
  String get shop_title => 'Shop';

  @override
  String get shop_coinPacks => 'Coin packs';

  @override
  String get shop_comingSoon => 'Coming soon';

  @override
  String shop_coinCount(Object count) {
    return '$count coins';
  }

  @override
  String get shop_bestValueBadge => 'Best value';

  @override
  String get shop_adRemovalIncludedBadge => 'Premium included';

  @override
  String get shop_premium => 'Premium';

  @override
  String get shop_premiumDescription =>
      'Removes all ads + 100 coins/day automatically';

  @override
  String get shop_buy => 'Buy';

  @override
  String shop_buyForPrice(Object price) {
    return 'Buy — $price';
  }

  @override
  String get shop_alreadyPremium => 'Already Premium';

  @override
  String get shop_purchasePending => 'Purchase pending...';

  @override
  String get shop_purchaseError => 'Purchase failed. Please try again.';

  @override
  String get shop_purchaseCanceled => 'Purchase canceled';

  @override
  String get shop_restorePurchases => 'Restore purchases';

  @override
  String get shop_restoreCompleted => 'Purchases restored';

  @override
  String get shop_restoreError => 'Could not restore purchases';

  @override
  String get home_settings => 'Settings';

  @override
  String get home_shop => 'Shop';

  @override
  String get home_buildSelection => 'Power-up selection';

  @override
  String get home_buildSelectionLockedResume =>
      'Finish or abandon your current run before picking new power-ups.';

  @override
  String get home_quests => 'Quests';

  @override
  String get home_stats => 'Statistics';

  @override
  String get ads_watchForCoins => 'Watch an ad (+100 coins)';

  @override
  String get ads_comeBackTomorrow => 'Come back tomorrow';

  @override
  String get ads_loading => 'Loading…';

  @override
  String get premium_dailyCoinsButton => 'Your daily coins';

  @override
  String get stats_title => 'Statistics';

  @override
  String get stats_totalTiles => 'Total tiles placed';

  @override
  String get stats_bestScore => 'Best score';

  @override
  String get stats_gamesPlayed => 'Games played';

  @override
  String get stats_totalCoins => 'Total coins earned';

  @override
  String get stats_colorGroups => 'COLOR GROUPS';

  @override
  String get stats_error => 'Error';

  @override
  String get stats_noData => 'No data';

  @override
  String stats_biomeMax(Object value) {
    return 'Max: $value tiles';
  }

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_sectionAudio => 'Audio';

  @override
  String get settings_sectionAbout => 'About';

  @override
  String get settings_rateApp => 'Rate the app';

  @override
  String get settings_rateAppSubtitle => 'Share your feedback on the Store';

  @override
  String get review_title => 'Enjoying HexHaven?';

  @override
  String get review_body =>
      'A review helps us a lot to grow the game and get discovered by other players!';

  @override
  String get review_rateNow => 'Rate now';

  @override
  String get review_later => 'Maybe later';
}
