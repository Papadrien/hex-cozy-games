// Tests unitaires pour HexTile — Story 1.3.
//
// Vérifie :
//  - rotated préserve les biomes (multiset) et décale correctement
//  - rotation complète (6 steps) redonne la tuile d'origine
//  - biomeCount pour 1, 2, 3 biomes différents

import 'package:flutter_test/flutter_test.dart';

import 'package:hex_cozy_games/game/hex_cell.dart';
import 'package:hex_cozy_games/game/hex_tile.dart';

void main() {
  group('HexTile', () {
    test('rotated(1) décale les côtés d\'un cran vers la droite', () {
      final tile = HexTile(sides: [
        BiomeType.forest,  // 0
        BiomeType.water,   // 1
        BiomeType.plain,   // 2
        BiomeType.forest,  // 3
        BiomeType.water,   // 4
        BiomeType.plain,   // 5
      ]);
      final rotated = tile.rotated(1);
      expect(rotated.sides, [
        BiomeType.plain,   // l'ancien 5 vient en 0
        BiomeType.forest,  // 0 → 1
        BiomeType.water,   // 1 → 2
        BiomeType.plain,   // 2 → 3
        BiomeType.forest,  // 3 → 4
        BiomeType.water,   // 4 → 5
      ]);
    });

    test('rotated(6) redonne la tuile originale', () {
      final tile = HexTile(sides: [
        BiomeType.forest,
        BiomeType.water,
        BiomeType.plain,
        BiomeType.mountain,
        BiomeType.village,
        BiomeType.forest,
      ]);
      expect(tile.rotated(6).sides, tile.sides);
    });

    test('rotated préserve le multiset des biomes', () {
      final tile = HexTile(sides: [
        BiomeType.forest,
        BiomeType.forest,
        BiomeType.water,
        BiomeType.water,
        BiomeType.plain,
        BiomeType.plain,
      ]);
      for (var steps = 0; steps < 12; steps++) {
        final rotated = tile.rotated(steps);
        expect(rotated.sides.toSet(), tile.sides.toSet());
      }
    });

    test('rotated accepte les valeurs négatives (sens inverse)', () {
      final tile = HexTile(sides: [
        BiomeType.forest,  // 0
        BiomeType.water,   // 1
        BiomeType.plain,   // 2
        BiomeType.forest,  // 3
        BiomeType.water,   // 4
        BiomeType.plain,   // 5
      ]);
      // -1 = rotation antihoraire d'1 cran = l'ancien 1 vient en 0
      final rotated = tile.rotated(-1);
      expect(rotated.sides[0], BiomeType.water);
    });

    test('biomeCount pour une tuile monochrome vaut 1', () {
      final tile = HexTile(sides: List.filled(6, BiomeType.forest));
      expect(tile.biomeCount, 1);
    });

    test('biomeCount pour 3 biomes (2+2+2) vaut 3', () {
      final tile = HexTile(sides: [
        BiomeType.forest,
        BiomeType.forest,
        BiomeType.water,
        BiomeType.water,
        BiomeType.plain,
        BiomeType.plain,
      ]);
      expect(tile.biomeCount, 3);
    });
  });
}
