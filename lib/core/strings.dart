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
}
