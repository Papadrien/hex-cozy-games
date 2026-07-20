/// Réglages son et vibrations — Story 1.5bis-a.
///
/// Provider persisté via `shared_preferences` pour que les choix du joueur
/// survivent aux redémarrages de l'app. Les valeurs par défaut sont
/// `true` (son activé, vibrations activées).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OptionsState {
  const OptionsState({this.soundEnabled = true, this.vibrationEnabled = true});

  final bool soundEnabled;
  final bool vibrationEnabled;
}

/// Instance SharedPreferences pré-chargée au démarrage de l'app (voir
/// [main]). Utilisée par [OptionsStateNotifier] pour lire/écrire les
/// préférences sans appels asynchrones dans `build()`.
/// `null` avant l'initialisation (tests) — fallback sur valeurs par défaut.
SharedPreferences? _prefs;

Future<void> initOptionsPrefs() async {
  _prefs = await SharedPreferences.getInstance();
}

class OptionsStateNotifier extends Notifier<OptionsState> {
  static const _kSoundKey = 'options_sound_enabled';
  static const _kVibrationKey = 'options_vibration_enabled';

  @override
  OptionsState build() {
    final p = _prefs;
    final sound = p?.getBool(_kSoundKey) ?? true;
    final vibration = p?.getBool(_kVibrationKey) ?? true;
    return OptionsState(soundEnabled: sound, vibrationEnabled: vibration);
  }

  void toggleSound() {
    state = OptionsState(
      soundEnabled: !state.soundEnabled,
      vibrationEnabled: state.vibrationEnabled,
    );
    _prefs?.setBool(_kSoundKey, state.soundEnabled);
  }

  void toggleVibration() {
    state = OptionsState(
      soundEnabled: state.soundEnabled,
      vibrationEnabled: !state.vibrationEnabled,
    );
    _prefs?.setBool(_kVibrationKey, state.vibrationEnabled);
  }
}

final optionsProvider = NotifierProvider<OptionsStateNotifier, OptionsState>(
  OptionsStateNotifier.new,
);
