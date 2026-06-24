/// État de fin de partie — Story 1.8a / 1.8b.
///
/// [EndGameStats] contient les statistiques finales calculées quand
/// la pile de tuiles est épuisée. Le provider [isGameOverProvider]
/// permet à l'UI de savoir quand afficher l'écran de résultats.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Statistiques finales d'une partie terminée.
class EndGameStats {
  const EndGameStats({
    required this.placedTilesCount,
    required this.connections3,
    required this.connections4,
    required this.connections5,
    required this.connections6,
    required this.coins,
  });

  final int placedTilesCount;
  final int connections3;
  final int connections4;
  final int connections5;
  final int connections6;
  final int coins;

  int get totalConnections =>
      connections3 + connections4 + connections5 + connections6;
}

/// Calcule les statistiques finales à partir des compteurs de session et
/// du nombre de tuiles posées.
EndGameStats computeEndGameStats({
  required int placedTilesCount,
  required int coins,
  required int connections3,
  required int connections4,
  required int connections5,
  required int connections6,
}) {
  return EndGameStats(
    placedTilesCount: placedTilesCount,
    connections3: connections3,
    connections4: connections4,
    connections5: connections5,
    connections6: connections6,
    coins: coins,
  );
}

class _GameOverNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Indique si la partie est terminée (true) ou toujours en cours (false).
final isGameOverProvider =
    NotifierProvider<_GameOverNotifier, bool>(_GameOverNotifier.new);

class _EndGameStatsNotifier extends Notifier<EndGameStats?> {
  @override
  EndGameStats? build() => null;

  void set(EndGameStats? stats) => state = stats;
}

/// Dernières statistiques calculées à la fin de la partie.
final endGameStatsProvider =
    NotifierProvider<_EndGameStatsNotifier, EndGameStats?>(
        _EndGameStatsNotifier.new);

/// Réinitialise les providers de fin de partie pour une nouvelle partie.
void resetEndGame(WidgetRef ref) {
  ref.read(isGameOverProvider.notifier).set(false);
  ref.read(endGameStatsProvider.notifier).set(null);
}
