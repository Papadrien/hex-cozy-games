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
  String get game_sessionCoins => 'Game coins';

  @override
  String get home_totalCoins => 'Total coins';

  @override
  String get tutorial_step1 =>
      'Glowing tiles are the spots where you can place your tile';

  @override
  String get tutorial_step2 =>
      'Swipe to rotate it — multiple turns in a single gesture!';

  @override
  String get tutorial_step3 => 'Coin icons show you what you’ll earn';

  @override
  String get tutorial_step4 => 'Tap again to confirm the placement';

  @override
  String get tutorial_step5 =>
      'Match identical sides to earn bonus tiles and coins';

  @override
  String get tutorial_skip => 'Skip';

  @override
  String get quests_title => 'Quests';

  @override
  String get quests_category_tiles => 'Tiles placed';

  @override
  String get quests_category_village => 'Village';

  @override
  String get quests_category_biomes => 'Closed biomes';

  @override
  String get quests_status_active => 'Active';

  @override
  String get quests_status_completed => 'Completed';

  @override
  String get quests_status_locked => 'Locked';

  @override
  String get quests_reward_coins => 'Reward';

  @override
  String get quests_reward_upgrade => 'Unlocks upgrade';

  @override
  String get quests_progress => 'Progress';

  @override
  String get quests_empty => 'No quests available';

  @override
  String get quests_close => 'Close';

  @override
  String get quests_next_reward => 'Next reward';

  @override
  String get upgrades_title => 'Upgrades';

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
  String get home_settings => 'Settings';

  @override
  String get home_shop => 'Shop';

  @override
  String get home_buildSelection => 'Upgrade selection';

  @override
  String get home_quests => 'Quests';

  @override
  String get home_stats => 'Statistics';

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
  String stats_biomeMax(Object biome, Object value) {
    return '$biome max: $value tiles';
  }
}
