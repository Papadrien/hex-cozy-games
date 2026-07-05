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

  /// Calcule les pièces finales après application des bonus — Story 2.8b / B1.
  ///
  /// Chaque biome dispose de son propre bonus par côté connecté :
  /// [villageSides] × [villageCoinsBonus], [forestSides] × [forestCoinsBonus],
  /// etc. Le total des bonus est ajouté aux pièces de base, puis le tout est
  /// multiplié par (1 + [coinsMultiplier]).
  int applyCoinBonuses({
    required int baseCoins,
    required int villageSides,
    int forestSides = 0,
    int waterSides = 0,
    int plainSides = 0,
    int mountainSides = 0,
  }) {
    final effects = _ref.read(activeUpgradeEffectsProvider);
    final villageExtra = (villageSides * effects.villageCoinsBonus).round();
    final forestExtra = (forestSides * effects.forestCoinsBonus).round();
    final waterExtra = (waterSides * effects.waterCoinsBonus).round();
    final plainExtra = (plainSides * effects.plainCoinsBonus).round();
    final mountainExtra = (mountainSides * effects.mountainCoinsBonus).round();
    final withBiomeBonus =
        baseCoins + villageExtra + forestExtra + waterExtra + plainExtra + mountainExtra;
    return (withBiomeBonus * (1.0 + effects.coinsMultiplier)).round();
  }

  /// Nombre de tuiles bonus ajoutées à chaque pallier de 5 dans la série de
  /// connexions consécutives (Combo+ — Story B3).
  int getComboBonusTiles() {
    return _ref.read(activeUpgradeEffectsProvider).comboBonusTiles;
  }

  /// Compte le nombre de côtés connectés dont le biome est [biome].
  int countBiomeSides(BiomeType biome, HexTile tile, List<int> connectedSides) {
    return connectedSides
        .where((side) => tile.sides[side] == biome)
        .length;
  }
}
