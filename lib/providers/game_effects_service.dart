/// GameEffectsService — Story 2.8a / 2.8b.
///
/// Centralise les effets des améliorations dans le game loop :
///   - STARTING_TILES : modifie le stock initial
///   - CONNECTION_BONUS_MULTIPLIER : multiplie les tuiles bonus des connexions
///   - COINS_MULTIPLIER : multiplie les pièces générées
///   - BIOME_COINS_BONUS : bonus de pièces pour le biome village
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_cell.dart';
import '../game/hex_tile.dart';
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

  /// Calcule les pièces finales après application des bonus — Story 2.8b.
  ///
  /// 1. [villageSides] reçoivent un bonus de [villageCoinsBonus] en sus de
  ///    leur pièce de base.
  /// 2. Le total (pièces de base + bonus village) est multiplié par
  ///    [coinsMultiplier].
  int applyCoinBonuses({
    required int baseCoins,
    required int villageSides,
  }) {
    final effects = _ref.read(activeUpgradeEffectsProvider);
    final villageExtra = (villageSides * effects.villageCoinsBonus).round();
    final withBiomeBonus = baseCoins + villageExtra;
    return (withBiomeBonus * (1.0 + effects.coinsMultiplier)).round();
  }

  /// Compte le nombre de côtés connectés dont le biome est village.
  int countVillageSides(HexTile tile, List<int> connectedSides) {
    return connectedSides
        .where((side) => tile.sides[side] == BiomeType.village)
        .length;
  }
}
