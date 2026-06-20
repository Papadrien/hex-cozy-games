import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @pause_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get pause_resume;

  /// No description provided for @pause_options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get pause_options;

  /// No description provided for @options_sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get options_sound;

  /// No description provided for @options_vibrations.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get options_vibrations;

  /// No description provided for @pause_saveAndQuit.
  ///
  /// In en, this message translates to:
  /// **'Save and quit'**
  String get pause_saveAndQuit;

  /// No description provided for @pause_abandon.
  ///
  /// In en, this message translates to:
  /// **'Abandon'**
  String get pause_abandon;

  /// No description provided for @pause_abandonConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to abandon this game?'**
  String get pause_abandonConfirmTitle;

  /// No description provided for @pause_abandonConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The coins earned during this game will be lost.'**
  String get pause_abandonConfirmBody;

  /// No description provided for @pause_abandonConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get pause_abandonConfirmCancel;

  /// No description provided for @pause_abandonConfirmConfirm.
  ///
  /// In en, this message translates to:
  /// **'Abandon'**
  String get pause_abandonConfirmConfirm;

  /// No description provided for @home_play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get home_play;

  /// No description provided for @home_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get home_resume;

  /// No description provided for @reward_coins.
  ///
  /// In en, this message translates to:
  /// **' bonus'**
  String get reward_coins;

  /// No description provided for @reward_bonusTiles.
  ///
  /// In en, this message translates to:
  /// **' bonus tiles'**
  String get reward_bonusTiles;

  /// No description provided for @results_title.
  ///
  /// In en, this message translates to:
  /// **'Game Over!'**
  String get results_title;

  /// No description provided for @results_tilesPlaced.
  ///
  /// In en, this message translates to:
  /// **'Tiles placed'**
  String get results_tilesPlaced;

  /// No description provided for @results_connections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get results_connections;

  /// No description provided for @results_coins.
  ///
  /// In en, this message translates to:
  /// **'Coins earned'**
  String get results_coins;

  /// No description provided for @results_connections3.
  ///
  /// In en, this message translates to:
  /// **'3 sides'**
  String get results_connections3;

  /// No description provided for @results_connections4.
  ///
  /// In en, this message translates to:
  /// **'4 sides'**
  String get results_connections4;

  /// No description provided for @results_connections5.
  ///
  /// In en, this message translates to:
  /// **'5 sides'**
  String get results_connections5;

  /// No description provided for @results_connections6.
  ///
  /// In en, this message translates to:
  /// **'6 sides'**
  String get results_connections6;

  /// No description provided for @results_replay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get results_replay;

  /// No description provided for @game_sessionCoins.
  ///
  /// In en, this message translates to:
  /// **'Game coins'**
  String get game_sessionCoins;

  /// No description provided for @home_totalCoins.
  ///
  /// In en, this message translates to:
  /// **'Total coins'**
  String get home_totalCoins;

  /// No description provided for @tutorial_step1.
  ///
  /// In en, this message translates to:
  /// **'Glowing tiles are the spots where you can place your tile'**
  String get tutorial_step1;

  /// No description provided for @tutorial_step2.
  ///
  /// In en, this message translates to:
  /// **'Swipe to rotate it — multiple turns in a single gesture!'**
  String get tutorial_step2;

  /// No description provided for @tutorial_step3.
  ///
  /// In en, this message translates to:
  /// **'Coin icons show you what you’ll earn'**
  String get tutorial_step3;

  /// No description provided for @tutorial_step4.
  ///
  /// In en, this message translates to:
  /// **'Tap again to confirm the placement'**
  String get tutorial_step4;

  /// No description provided for @tutorial_step5.
  ///
  /// In en, this message translates to:
  /// **'Match identical sides to earn bonus tiles and coins'**
  String get tutorial_step5;

  /// No description provided for @tutorial_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tutorial_skip;

  /// No description provided for @quests_title.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get quests_title;

  /// No description provided for @quests_category_tiles.
  ///
  /// In en, this message translates to:
  /// **'Tiles placed'**
  String get quests_category_tiles;

  /// No description provided for @quests_category_village.
  ///
  /// In en, this message translates to:
  /// **'Village'**
  String get quests_category_village;

  /// No description provided for @quests_category_biomes.
  ///
  /// In en, this message translates to:
  /// **'Closed biomes'**
  String get quests_category_biomes;

  /// No description provided for @quests_status_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get quests_status_active;

  /// No description provided for @quests_status_completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get quests_status_completed;

  /// No description provided for @quests_status_locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get quests_status_locked;

  /// No description provided for @quests_reward_coins.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get quests_reward_coins;

  /// No description provided for @quests_reward_upgrade.
  ///
  /// In en, this message translates to:
  /// **'Unlocks upgrade'**
  String get quests_reward_upgrade;

  /// No description provided for @quests_progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get quests_progress;

  /// No description provided for @quests_empty.
  ///
  /// In en, this message translates to:
  /// **'No quests available'**
  String get quests_empty;

  /// No description provided for @quests_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get quests_close;

  /// No description provided for @quests_next_reward.
  ///
  /// In en, this message translates to:
  /// **'Next reward'**
  String get quests_next_reward;

  /// No description provided for @upgrades_title.
  ///
  /// In en, this message translates to:
  /// **'Upgrades'**
  String get upgrades_title;

  /// No description provided for @upgrades_locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get upgrades_locked;

  /// No description provided for @upgrades_hiddenEffect.
  ///
  /// In en, this message translates to:
  /// **'???'**
  String get upgrades_hiddenEffect;

  /// No description provided for @upgrades_unlockCondition.
  ///
  /// In en, this message translates to:
  /// **'Unlock condition'**
  String get upgrades_unlockCondition;

  /// No description provided for @upgrades_upgradeButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrades_upgradeButton;

  /// No description provided for @upgrades_level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get upgrades_level;

  /// No description provided for @upgrades_cost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get upgrades_cost;

  /// No description provided for @upgrades_max.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get upgrades_max;

  /// No description provided for @home_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get home_settings;

  /// No description provided for @home_shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get home_shop;

  /// No description provided for @home_buildSelection.
  ///
  /// In en, this message translates to:
  /// **'Upgrade selection'**
  String get home_buildSelection;

  /// No description provided for @home_quests.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get home_quests;

  /// No description provided for @home_stats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get home_stats;

  /// No description provided for @stats_title.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get stats_title;

  /// No description provided for @stats_totalTiles.
  ///
  /// In en, this message translates to:
  /// **'Total tiles placed'**
  String get stats_totalTiles;

  /// No description provided for @stats_bestScore.
  ///
  /// In en, this message translates to:
  /// **'Best score'**
  String get stats_bestScore;

  /// No description provided for @stats_gamesPlayed.
  ///
  /// In en, this message translates to:
  /// **'Games played'**
  String get stats_gamesPlayed;

  /// No description provided for @stats_totalCoins.
  ///
  /// In en, this message translates to:
  /// **'Total coins earned'**
  String get stats_totalCoins;

  /// No description provided for @stats_biomeMax.
  ///
  /// In en, this message translates to:
  /// **'{biome} max: {value} tiles'**
  String stats_biomeMax(Object biome, Object value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
