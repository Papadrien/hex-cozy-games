// Tests unitaires pour tileStackProvider — Story 1.4a.
//
// Vérifie :
//  - le shuffle Fisher-Yates produit bien une permutation du pool
//  - exactement kVisibleStackSize tuiles sont visibles (ou moins si le pool
//    en a moins, ce qui n'arrive pas en pratique avec kTilePool)
//  - consommer la tuile active fait avancer la pile correctement
//  - la pile se ré-alimente automatiquement une fois épuisée

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_cozy_games/core/constants.dart';
import 'package:hex_cozy_games/game/hex_tile.dart';
import 'package:hex_cozy_games/providers/tile_stack_provider.dart';

void main() {
  group('tileStackProvider', () {
    test('expose kVisibleStackSize tuiles visibles et le bon "remaining"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(tileStackProvider);

      expect(state.visible.length, kVisibleStackSize);
      expect(state.remaining, kTilePool.length);
      expect(state.activeTile, state.visible.first);
    });

    test('le shuffle est une permutation valide du pool (pas de perte/ajout)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // On consomme toute la pile initiale (avant ré-alimentation) et on
      // vérifie qu'on retrouve exactement les tuiles du pool, dans un ordre
      // potentiellement différent.
      final drawn = <HexTile>[];
      for (var i = 0; i < kTilePool.length; i++) {
        final active = container.read(tileStackProvider).activeTile;
        expect(active, isNotNull);
        drawn.add(active!);
        container.read(tileStackProvider.notifier).consumeActiveTile();
      }

      expect(drawn.length, kTilePool.length);
      // Même multiset de tuiles (comparaison par sides, HexTile n'a pas de ==).
      final drawnSides = drawn.map((t) => t.sides.toList()).toList()
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      final poolSides = kTilePool.map((t) => t.sides.toList()).toList()
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      expect(drawnSides, poolSides);
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

    test('la pile se ré-alimente automatiquement une fois épuisée', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Vide complètement la pile initiale.
      for (var i = 0; i < kTilePool.length; i++) {
        container.read(tileStackProvider.notifier).consumeActiveTile();
      }

      final state = container.read(tileStackProvider);
      // La pile a été ré-alimentée avec un nouveau pool mélangé : on doit
      // toujours avoir des tuiles visibles et un remaining cohérent.
      expect(state.visible.length, kVisibleStackSize);
      expect(state.remaining, kTilePool.length);
    });
  });
}
