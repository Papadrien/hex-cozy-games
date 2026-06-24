/// Tests pour GameEffectsService et le cumul des effets — Story 2.8b.
///
/// Vérifie :
///  - COINS_MULTIPLIER (coins_percent_bonus)
///  - BIOME_COINS_BONUS (village_coins_percent_bonus)
///  - Cumul de plusieurs améliorations (jusqu'à 3)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/game/hex_cell.dart';
import 'package:hex_haven/game/hex_tile.dart';
import 'package:hex_haven/providers/build_provider.dart';
import 'package:hex_haven/providers/game_effects_service.dart';

/// [activeUpgradeEffectsProvider] surchargé avec les valeurs passées.
ProviderContainer _makeContainer([ActiveUpgradeEffects? effects]) {
  return ProviderContainer(
    overrides: [
      activeUpgradeEffectsProvider.overrideWithValue(
        effects ?? const ActiveUpgradeEffects(),
      ),
    ],
  );
}

void main() {
  group('ActiveUpgradeEffects — provider', () {
    test('aucune amélioration → tous les bonus à zéro', () {
      final container = _makeContainer();
      final effects = container.read(activeUpgradeEffectsProvider);
      expect(effects.startingTilesBonus, 0);
      expect(effects.connectionMultiplier, 1.0);
      expect(effects.coinsMultiplier, 0.0);
      expect(effects.villageCoinsBonus, 0.0);
    });
  });

  group('GameEffectsService.getStartingTilesBonus', () {
    test('aucune amélioration → 0 tuile bonus', () {
      final container = _makeContainer();
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getStartingTilesBonus(), 0);
    });

    test('niveau 1 → +2 tuiles', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(startingTilesBonus: 2),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getStartingTilesBonus(), 2);
    });

    test('niveau 2 → +5 tuiles', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(startingTilesBonus: 5),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getStartingTilesBonus(), 5);
    });

    test('niveau d amélioration max → +10 tuiles', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(startingTilesBonus: 10),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getStartingTilesBonus(), 10);
    });
  });

  group('GameEffectsService.applyConnectionMultiplier', () {
    test('aucune amélioration → facteur 1.0 (inchangé)', () {
      final container = _makeContainer();
      final service = container.read(gameEffectsServiceProvider);
      expect(service.applyConnectionMultiplier(5), 5);
    });

    test('multiplicateur 2.0 → double les tuiles bonus', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(connectionMultiplier: 2.0),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.applyConnectionMultiplier(3), 6);
    });

    test('multiplicateur 2.0 → 1 tuile → 2', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(connectionMultiplier: 2.0),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.applyConnectionMultiplier(1), 2);
    });

    test('multiplicateur 2.0 → 0 tuile → 0', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(connectionMultiplier: 2.0),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.applyConnectionMultiplier(0), 0);
    });
  });

  group('GameEffectsService.applyCoinBonuses', () {
    test('aucun effet → baseCoins inchangé', () {
      final container = _makeContainer();
      final service = container.read(gameEffectsServiceProvider);
      final coins = service.applyCoinBonuses(
        baseCoins: 10,
        villageSides: 3,
      );
      expect(coins, 10);
    });

    test('coinsMultiplier 10% → 10% de bonus', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(coinsMultiplier: 0.10),
      );
      final service = container.read(gameEffectsServiceProvider);
      final coins = service.applyCoinBonuses(
        baseCoins: 10,
        villageSides: 0,
      );
      expect(coins, 11); // 10 * 1.10 = 11
    });

    test('coinsMultiplier 20% → +20%', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(coinsMultiplier: 0.20),
      );
      final service = container.read(gameEffectsServiceProvider);
      final coins = service.applyCoinBonuses(baseCoins: 10, villageSides: 0);
      expect(coins, 12);
    });

    test('villageCoinsBonus 33% → +1 pour 3 côtés village', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(villageCoinsBonus: 0.33),
      );
      final service = container.read(gameEffectsServiceProvider);
      // 3 côtés village × 0.33 = 0.99 → arrondi à 1
      final coins = service.applyCoinBonuses(baseCoins: 10, villageSides: 3);
      expect(coins, 11); // 10 + (3 * 0.33).round() = 10 + 1 = 11
    });

    test('cumul coinsMultiplier + villageCoinsBonus', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(
          coinsMultiplier: 0.10,
          villageCoinsBonus: 0.33,
        ),
      );
      final service = container.read(gameEffectsServiceProvider);
      // base 10, 3 côtés village
      // villageExtra = (3 * 0.33).round() = 1
      // withBiomeBonus = 10 + 1 = 11
      // total = (11 * 1.10).round() = 12.1 → 12
      final coins = service.applyCoinBonuses(baseCoins: 10, villageSides: 3);
      expect(coins, 12);
    });

    test('max 3 upgrades cumulés (100% village + 30% coins)', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(
          coinsMultiplier: 0.30,
          villageCoinsBonus: 1.00,
        ),
      );
      final service = container.read(gameEffectsServiceProvider);
      // base 10, 2 côtés village
      // villageExtra = (2 * 1.00).round() = 2
      // withBiomeBonus = 10 + 2 = 12
      // total = (12 * 1.30).round() = 15.6 → 16
      final coins = service.applyCoinBonuses(baseCoins: 10, villageSides: 2);
      expect(coins, 16);
    });
  });

  group('GameEffectsService.countVillageSides', () {
    late GameEffectsService service;

    setUp(() {
      service = _makeContainer().read(gameEffectsServiceProvider);
    });

    test('aucun côté village → 0', () {
      final tile = HexTile(sides: [
        BiomeType.forest,
        BiomeType.plain,
        BiomeType.water,
        BiomeType.mountain,
        BiomeType.forest,
        BiomeType.plain,
      ]);
      expect(service.countVillageSides(tile, [0, 1, 2]), 0);
    });

    test('2 côtés village sur 3 connectés → 2', () {
      final tile = HexTile(sides: [
        BiomeType.village,
        BiomeType.forest,
        BiomeType.village,
        BiomeType.plain,
        BiomeType.water,
        BiomeType.mountain,
      ]);
      expect(service.countVillageSides(tile, [0, 1, 2]), 2);
    });

    test('tous les côtés village → 6', () {
      final tile = HexTile(sides: List.filled(6, BiomeType.village));
      expect(service.countVillageSides(tile, [0, 1, 2, 3, 4, 5]), 6);
    });
  });
}
