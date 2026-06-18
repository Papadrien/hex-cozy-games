/// Réglages son et vibrations — Story 1.5bis-a.
///
/// Provider persisté via [keepAlive] pour que l'état survive aux changements
/// d'écran. Les valeurs par défaut sont true (son activé, vibrations activées).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class OptionsState {
  const OptionsState({this.soundEnabled = true, this.vibrationEnabled = true});

  final bool soundEnabled;
  final bool vibrationEnabled;
}

class OptionsStateNotifier extends Notifier<OptionsState> {
  @override
  OptionsState build() => const OptionsState();

  void toggleSound() {
    state = OptionsState(
      soundEnabled: !state.soundEnabled,
      vibrationEnabled: state.vibrationEnabled,
    );
  }

  void toggleVibration() {
    state = OptionsState(
      soundEnabled: state.soundEnabled,
      vibrationEnabled: !state.vibrationEnabled,
    );
  }
}

final optionsProvider = NotifierProvider<OptionsStateNotifier, OptionsState>(
  OptionsStateNotifier.new,
);
