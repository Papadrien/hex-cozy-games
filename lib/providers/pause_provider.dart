/// État de pause du jeu — Story 1.5bis-a.
///
/// [PauseState] distingue le simple affichage de la modale (isPaused) de
/// l'affichage du sous-écran Options (showOptions), qui reste dans la même
/// modale plutôt que de naviguer vers un écran dédié.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PauseState {
  const PauseState({this.isPaused = false, this.showOptions = false});

  final bool isPaused;
  final bool showOptions;

  PauseState copyWith({bool? isPaused, bool? showOptions}) {
    return PauseState(
      isPaused: isPaused ?? this.isPaused,
      showOptions: showOptions ?? this.showOptions,
    );
  }
}

class PauseStateNotifier extends Notifier<PauseState> {
  @override
  PauseState build() => const PauseState();

  void pause() => state = const PauseState(isPaused: true);

  void resume() => state = const PauseState();

  void toggleOptions() {
    state = state.copyWith(showOptions: !state.showOptions);
  }
}

final pauseProvider = NotifierProvider<PauseStateNotifier, PauseState>(
  PauseStateNotifier.new,
);
