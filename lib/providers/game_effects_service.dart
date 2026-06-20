/// GameEffectsService — Story 2.8a.
///
/// Centralise les effets des améliorations dans le game loop :
///   - STARTING_TILES : modifie le stock initial
///   - CONNECTION_BONUS_MULTIPLIER : multiplie les tuiles bonus des connexions
///
/// Les effets liés aux pièces (coins_percent_bonus,
/// village_coins_percent_bonus) sont traités en Story 2.8b.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'build_provider.dart';

final gameEffectsServiceProvider =
    Provider<GameEffectsService>((ref) => GameEffectsService(ref));

class GameEffectsService {
  GameEffectsService(this._ref);
  final Ref _ref;

  /// Nombre de tuiles supplémentaires à ajouter dans la pioche de départ.
  int getStartingTilesBonus() {
    return _ref.read(activeUpgradeEffectsProvider).startingTilesBonus;
  }

  /// Applique le multiplicateur de connexions aux [bonusTiles].
  ///
  /// Retourne le nombre de tuiles bonus après application de
  /// [ActiveUpgradeEffects.connectionMultiplier].
  int applyConnectionMultiplier(int bonusTiles) {
    final mult = _ref.read(activeUpgradeEffectsProvider).connectionMultiplier;
    return (bonusTiles * mult).round();
  }
}
