// Tests unitaires pour tileStackProvider — Story 1.4a / 1.9a.
//
// Vérifie :
//  - le pool généré a la taille de kStartingTiles
//  - chaque tuile respecte max 3 biomes et arcs contigus
//  - exactement kVisibleStackSize tuiles sont visibles
//  - consommer la tuile active fait avancer la pile correctement
//  - la pile épuisée n'est pas ré-alimentée (fin de partie)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_cozy_games/core/constants.dart';
import 'package:hex_cozy_games/game/hex_cell.dart';
import 'package:hex_cozy_games/game/hex_tile.dart';
import 'package:hex_cozy_games/providers/tile_stack_provider.dart';

void main() {
  group('tileStackProvider', () {
    test('expose kVisibleStackSize tuiles visibles et le bon "remaining"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(tileStackProvider);

      expect(state.visible.length, kVisibleStackSize);
      expect(state.remaining, kStartingTiles);
      expect(state.activeTile, state.visible.first);
    });

    test('le pool généré respecte max 3 biomes et arcs contigus', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final drawn = <HexTile>[];
      for (var i = 0; i < kStartingTiles; i++) {
        final active = container.read(tileStackProvider).activeTile;
        expect(active, isNotNull);
        drawn.add(active!);
        container.read(tileStackProvider.notifier).consumeActiveTile();
      }

      expect(drawn.length, kStartingTiles);

      for (final tile in drawn) {
        // Max 3 biomes par tuile.
        expect(tile.biomeCount, lessThanOrEqualTo(kMaxBiomeTypesPerTile));

        // Arcs contigus : après rotation, les biomes identiques sont groupés.
        // On dédouble la liste pour gérer le wrap-around, et on vérifie
        // que chaque biome n'apparaît que dans un seul bloc continu.
        final sides = tile.sides;
        final doubled = [...sides, ...sides];
        final firsts = <BiomeType, int>{};
        for (var i = 0; i < 6; i++) {
          firsts.putIfAbsent(sides[i], () => i);
        }
        for (final entry in firsts.entries) {
          final start = entry.value;
          final count = sides.where((b) => b == entry.key).length;
          // Tous les count exemplaires doivent être consécutifs à partir
          // de [start].
          for (var i = 0; i < count; i++) {
            expect(doubled[start + i], entry.key);
          }
        }
      }
    });

    test('consumeActiveTile fait avancer la pile et décrémente remaining', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final before = container.read(tileStackProvider);
      final firstTile = before.visible[0];
      final secondTile = before.visible[1];

      container.read(tileStackProvider.notifier).consumeActiveTile();

      final after = container.read(tileStackProvider);
      expect(after.remaining, before.remaining - 1);
      // L'ancienne 2e tuile devient la nouvelle active.
      expect(after.visible.first, secondTile);
      expect(after.visible.first, isNot(firstTile));
    });

    test('la pile épuisée ne se ré-alimente pas (fin de partie)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Vide complètement la pile initiale.
      for (var i = 0; i < kStartingTiles; i++) {
        container.read(tileStackProvider.notifier).consumeActiveTile();
      }

      final state = container.read(tileStackProvider);
      // La pile est vide : plus de tuiles visibles, remaining = 0.
      expect(state.visible.length, 0);
      expect(state.remaining, 0);
      expect(state.activeTile, isNull);
    });
  });
}
