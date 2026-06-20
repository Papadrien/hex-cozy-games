/// Localisation minimaliste — FR / EN.
///
/// En attendant une vraie solution i18n (flutter_localizations), on centralise
/// ici toutes les chaînes affichées dans l'UI pour faciliter la traduction.
library;

import 'dart:io' show Platform;

// ignore_for_file: non_constant_identifier_names

/// Classe de traduction utilisable partout.
abstract class Str {
  Str._();

  /// Retourne `true` si la locale système est le français.
  static bool get _isFr {
    try {
      return Platform.localeName.startsWith('fr');
    } catch (_) {
      return false;
    }
  }

  static String get pause_resume => _isFr ? 'Reprendre' : 'Resume';
  static String get pause_options => _isFr ? 'Options' : 'Options';
  static String get options_sound => _isFr ? 'Son' : 'Sound';
  static String get options_vibrations => _isFr ? 'Vibrations' : 'Vibration';

  // Story 1.5bis-b — Pause modal actions
  static String get pause_saveAndQuit =>
      _isFr ? 'Sauvegarder et quitter' : 'Save and quit';
  static String get pause_abandon => _isFr ? 'Abandonner' : 'Abandon';
  static String get pause_abandonConfirmTitle =>
      _isFr ? 'Es-tu sûr de vouloir abandonner cette partie ?'
            : 'Are you sure you want to abandon this game?';
  static String get pause_abandonConfirmBody =>
      _isFr ? 'Tes pièces gagnées durant cette partie seront perdues.'
            : 'The coins earned during this game will be lost.';
  static String get pause_abandonConfirmCancel =>
      _isFr ? 'Annuler' : 'Cancel';
  static String get pause_abandonConfirmConfirm =>
      _isFr ? 'Abandonner' : 'Abandon';

  // Story 1.7b — Reprise de partie
  static String get home_play => _isFr ? 'Jouer' : 'Play';
  static String get home_resume => _isFr ? 'Reprendre' : 'Resume';

  // Story 1.7g — Récompenses de placement
  static String get reward_coins => _isFr ? ' bonus' : ' bonus';
  static String get reward_bonusTiles => _isFr ? ' tuiles bonus' : ' bonus tiles';

  // Story 1.8b — Écran de résultats
  static String get results_title => _isFr ? 'Partie terminée !' : 'Game Over!';
  static String get results_tilesPlaced => _isFr ? 'Tuiles posées' : 'Tiles placed';
  static String get results_connections => _isFr ? 'Connexions' : 'Connections';
  static String get results_coins => _isFr ? 'Pièces gagnées' : 'Coins earned';
  static String get results_connections3 => _isFr ? '3 côtés' : '3 sides';
  static String get results_connections4 => _isFr ? '4 côtés' : '4 sides';
  static String get results_connections5 => _isFr ? '5 côtés' : '5 sides';
  static String get results_connections6 => _isFr ? '6 côtés' : '6 sides';
  static String get results_replay => _isFr ? 'Rejouer' : 'Replay';

  // Story 2.2b — Double compteur pièces (session vs total)
  static String get game_sessionCoins =>
      _isFr ? 'Pièces de la partie' : 'Game coins';
  static String get home_totalCoins => _isFr ? 'Pièces totales' : 'Total coins';

  // Story 1.10b — Tutoriel first-launch
  static String get tutorial_step1 =>
      _isFr ? 'Les cases brillantes sont les endroits où tu peux poser ta tuile'
            : 'Glowing tiles are the spots where you can place your tile';
  static String get tutorial_step2 =>
      _isFr ? 'Swipe pour la faire pivoter — plusieurs rotations d\'un seul geste !'
            : 'Swipe to rotate it — multiple turns in a single gesture!';
  static String get tutorial_step3 =>
      _isFr ? 'Les icônes pièce te montrent ce que tu vas gagner'
            : 'Coin icons show you what you\'ll earn';
  static String get tutorial_step4 =>
      _isFr ? 'Tape à nouveau pour valider le placement'
            : 'Tap again to confirm the placement';
  static String get tutorial_step5 =>
      _isFr ? 'Connecte les côtés identiques pour gagner des tuiles et des pièces bonus'
            : 'Match identical sides to earn bonus tiles and coins';
  static String get tutorial_skip => _isFr ? 'Passer' : 'Skip';

  // Story 2.3b — Écran Quêtes
  static String get quests_title => _isFr ? 'Quêtes' : 'Quests';
  static String get quests_category_tiles =>
      _isFr ? 'Tuiles posées' : 'Tiles placed';
  static String get quests_category_village =>
      _isFr ? 'Village' : 'Village';
  static String get quests_category_biomes =>
      _isFr ? 'Biomes fermés' : 'Closed biomes';
  static String get quests_status_active => _isFr ? 'En cours' : 'Active';
  static String get quests_status_completed => _isFr ? 'Terminée' : 'Completed';
  static String get quests_status_locked => _isFr ? 'Verrouillée' : 'Locked';
  static String get quests_reward_coins => _isFr ? 'Récompense' : 'Reward';
  static String get quests_reward_upgrade =>
      _isFr ? 'Débloque amélioration' : 'Unlocks upgrade';
  static String get quests_progress => _isFr ? 'Progression' : 'Progress';
  static String get quests_empty =>
      _isFr ? 'Aucune quête disponible' : 'No quests available';
  static String get quests_close => _isFr ? 'Fermer' : 'Close';
  static String get quests_next_reward =>
      _isFr ? 'Prochaine récompense' : 'Next reward';

  // Story 2.5b — Écran Améliorations
  static String get upgrades_title => _isFr ? 'Améliorations' : 'Upgrades';
  static String get upgrades_locked => _isFr ? 'Verrouillée' : 'Locked';
  static String get upgrades_hiddenEffect => _isFr ? '???' : '???';
  static String get upgrades_unlockCondition =>
      _isFr ? 'Condition de déblocage' : 'Unlock condition';
  static String get upgrades_upgradeButton =>
      _isFr ? 'Améliorer' : 'Upgrade';
  static String get upgrades_level => _isFr ? 'Niveau' : 'Level';
}
