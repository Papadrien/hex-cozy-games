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
      expect(effects.connectionBonusLevel, 0);
      expect(effects.coinsMultiplier, 0.0);
      expect(effects.villageCoinsBonus, 0.0);
      expect(effects.forestCoinsBonus, 0.0);
      expect(effects.waterCoinsBonus, 0.0);
      expect(effects.plainCoinsBonus, 0.0);
      expect(effects.mountainCoinsBonus, 0.0);
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

  group('GameEffectsService.applyBonusTileUpgrade', () {
    test('aucune amélioration → inchangé', () {
      final container = _makeContainer();
      final service = container.read(gameEffectsServiceProvider);
      expect(service.applyBonusTileUpgrade(5, 5), 5);
    });

    test('niveau 1 → quint+sext +1, triple+quad inchangés', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(connectionBonusLevel: 1),
      );
      final service = container.read(gameEffectsServiceProvider);
      // 3 côtés (triple) : base 1 → inchangé
      expect(service.applyBonusTileUpgrade(3, 1), 1);
      // 4 côtés (quad) : base 2 → inchangé
      expect(service.applyBonusTileUpgrade(4, 2), 2);
      // 5 côtés (quint) : base 5 → +1
      expect(service.applyBonusTileUpgrade(5, 5), 6);
      // 6 côtés (sext) : base 10 → +1
      expect(service.applyBonusTileUpgrade(6, 10), 11);
    });

    test('niveau 2 → quint+sext +2, triple+quad inchangés', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(connectionBonusLevel: 2),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.applyBonusTileUpgrade(3, 1), 1);
      expect(service.applyBonusTileUpgrade(4, 2), 2);
      expect(service.applyBonusTileUpgrade(5, 5), 7);
      expect(service.applyBonusTileUpgrade(6, 10), 12);
    });

    test('niveau 3 → quint+sext +5, triple+quad inchangés', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(connectionBonusLevel: 3),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.applyBonusTileUpgrade(3, 1), 1);
      expect(service.applyBonusTileUpgrade(4, 2), 2);
      expect(service.applyBonusTileUpgrade(5, 5), 10);
      expect(service.applyBonusTileUpgrade(6, 10), 15);
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

    test('forestCoinsBonus 25% → +1 pour 3 côtés forêt', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(forestCoinsBonus: 0.25),
      );
      final service = container.read(gameEffectsServiceProvider);
      final coins = service.applyCoinBonuses(
        baseCoins: 10, villageSides: 0, forestSides: 3,
      );
      expect(coins, 11);
    });

    test('waterCoinsBonus 50% → +1 pour 2 côtés eau', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(waterCoinsBonus: 0.50),
      );
      final service = container.read(gameEffectsServiceProvider);
      final coins = service.applyCoinBonuses(
        baseCoins: 10, villageSides: 0, waterSides: 2,
      );
      expect(coins, 11);
    });

    test('plainCoinsBonus 100% → +2 pour 2 côtés plaine', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(plainCoinsBonus: 1.00),
      );
      final service = container.read(gameEffectsServiceProvider);
      final coins = service.applyCoinBonuses(
        baseCoins: 10, villageSides: 0, plainSides: 2,
      );
      expect(coins, 12);
    });

    test('mountainCoinsBonus 25% → 0 pour 0 côté montagne', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(mountainCoinsBonus: 0.25),
      );
      final service = container.read(gameEffectsServiceProvider);
      final coins = service.applyCoinBonuses(
        baseCoins: 10, villageSides: 0, mountainSides: 0,
      );
      expect(coins, 10);
    });

    test('tous les bonus biome cumulés', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(
          villageCoinsBonus: 0.33,
          forestCoinsBonus: 0.25,
          waterCoinsBonus: 0.25,
          plainCoinsBonus: 0.25,
          mountainCoinsBonus: 0.25,
        ),
      );
      final service = container.read(gameEffectsServiceProvider);
      // village: 3 * 0.33 = 0.99 → 1
      // forest: 2 * 0.25 = 0.50 → 1 (0.5 arrondi → 1)
      // water: 1 * 0.25 = 0.25 → 0
      // plain: 0 * 0.25 = 0 → 0
      // mountain: 1 * 0.25 = 0.25 → 0
      // total biome bonus = 1 + 1 + 0 + 0 + 0 = 2
      // withBiomeBonus = 10 + 2 = 12
      final coins = service.applyCoinBonuses(
        baseCoins: 10,
        villageSides: 3,
        forestSides: 2,
        waterSides: 1,
        plainSides: 0,
        mountainSides: 1,
      );
      expect(coins, 12);
    });
  });

  group('GameEffectsService.getComboStreakInterval', () {
    test('aucune amélioration → 0', () {
      final container = _makeContainer();
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getComboStreakInterval(), 0);
    });

    test('niveau 1 → intervalle de 15', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(comboStreakInterval: 15),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getComboStreakInterval(), 15);
    });

    test('niveau 3 → intervalle de 10', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(comboStreakInterval: 10),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getComboStreakInterval(), 10);
    });
  });

  group('GameEffectsService.getClosureBonusTiles', () {
    test('aucune amélioration → 0', () {
      final container = _makeContainer();
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getClosureBonusTiles(), 0);
    });

    test('niveau 1 → 1 tuile/10', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(closureBonusTiles: 1),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getClosureBonusTiles(), 1);
    });

    test('niveau 3 → 3 tuiles/10', () {
      final container = _makeContainer(
        const ActiveUpgradeEffects(closureBonusTiles: 3),
      );
      final service = container.read(gameEffectsServiceProvider);
      expect(service.getClosureBonusTiles(), 3);
    });
  });

  group('GameEffectsService.countBiomeSides', () {
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
      expect(service.countBiomeSides(BiomeType.village, tile, [0, 1, 2]), 0);
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
      expect(service.countBiomeSides(BiomeType.village, tile, [0, 1, 2]), 2);
    });

    test('tous les côtés village → 6', () {
      final tile = HexTile(sides: List.filled(6, BiomeType.village));
      expect(service.countBiomeSides(BiomeType.village, tile, [0, 1, 2, 3, 4, 5]), 6);
    });

    test('compte forêt correctement', () {
      final tile = HexTile(sides: [
        BiomeType.forest,
        BiomeType.plain,
        BiomeType.forest,
        BiomeType.water,
        BiomeType.forest,
        BiomeType.mountain,
      ]);
      expect(service.countBiomeSides(BiomeType.forest, tile, [0, 2, 4]), 3);
    });

    test('compte eau correctement', () {
      final tile = HexTile(sides: [
        BiomeType.water,
        BiomeType.plain,
        BiomeType.forest,
        BiomeType.water,
        BiomeType.water,
        BiomeType.mountain,
      ]);
      expect(service.countBiomeSides(BiomeType.water, tile, [0, 3, 4]), 3);
    });

    test('compte plaine correctement', () {
      final tile = HexTile(sides: [
        BiomeType.plain,
        BiomeType.plain,
        BiomeType.forest,
        BiomeType.water,
        BiomeType.mountain,
        BiomeType.plain,
      ]);
      expect(service.countBiomeSides(BiomeType.plain, tile, [0, 1, 5]), 3);
    });

    test('compte montagne correctement', () {
      final tile = HexTile(sides: [
        BiomeType.mountain,
        BiomeType.plain,
        BiomeType.forest,
        BiomeType.water,
        BiomeType.mountain,
        BiomeType.mountain,
      ]);
      expect(service.countBiomeSides(BiomeType.mountain, tile, [0, 4, 5]), 3);
    });
  });
}
