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
}
