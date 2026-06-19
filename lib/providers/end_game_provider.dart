/// État de fin de partie — Story 1.8a / 1.8b.
///
/// [EndGameStats] contient les statistiques finales calculées quand
/// la pile de tuiles est épuisée. Le provider [isGameOverProvider]
/// permet à l'UI de savoir quand afficher l'écran de résultats.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grid_state_provider.dart';

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

/// Calcule les statistiques finales à partir de l'état du plateau et
/// des pièces accumulées.
EndGameStats computeEndGameStats(
  GridState grid,
  int coins,
) {
  int c3 = 0, c4 = 0, c5 = 0, c6 = 0;

  for (final entry in grid.placedTiles.entries) {
    final connected = grid.countConnectedSides(entry.key, entry.value);
    if (connected == 3) c3++;
    if (connected == 4) c4++;
    if (connected == 5) c5++;
    if (connected == 6) c6++;
  }

  return EndGameStats(
    placedTilesCount: grid.placedTiles.length,
    connections3: c3,
    connections4: c4,
    connections5: c5,
    connections6: c6,
    coins: coins,
  );
}

/// Indique si la partie est terminée (true) ou toujours en cours (false).
final isGameOverProvider = StateProvider<bool>((ref) => false);

/// Dernières statistiques calculées à la fin de la partie.
final endGameStatsProvider = StateProvider<EndGameStats?>((ref) => null);

/// Réinitialise les providers de fin de partie pour une nouvelle partie.
void resetEndGame(WidgetRef ref) {
  ref.read(isGameOverProvider.notifier).state = false;
  ref.read(endGameStatsProvider.notifier).state = null;
}
