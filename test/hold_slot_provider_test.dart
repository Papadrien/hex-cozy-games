/// Tests pour l'état de l'Emplacement Joker (Hold) — Story B10.
///
/// Vérifie :
///  - aucune tuile en réserve à l'initialisation
///  - [HoldSlot.set] stocke la tuile fournie
///  - [HoldSlot.set] avec `null` vide l'emplacement
///
/// Note : la logique d'échange elle-même ([swapHoldSlot], dans
/// `placement_commit.dart`) opère sur un [WidgetRef] au même titre que
/// [startNewGame] / [undoPlacement], qui ne sont pas couverts par des tests
/// unitaires dans ce projet (nécessiteraient un test widget). Ce fichier se
/// limite donc à l'état géré par [holdSlotProvider] lui-même.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/providers/hold_slot_provider.dart';

import 'fixtures/tile_pool.dart';

void main() {
  group('holdSlotProvider (Story B10)', () {
    test('aucune tuile en réserve à l\'initialisation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(holdSlotProvider);

      expect(state.hasTile, isFalse);
      expect(state.heldTile, isNull);
    });

    test('set stocke la tuile fournie', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tile = kTilePool.first;

      container.read(holdSlotProvider.notifier).set(tile);

      final state = container.read(holdSlotProvider);
      expect(state.hasTile, isTrue);
      expect(state.heldTile, tile);
    });

    test('set(null) vide l\'emplacement', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(holdSlotProvider.notifier).set(kTilePool.first);

      container.read(holdSlotProvider.notifier).set(null);

      final state = container.read(holdSlotProvider);
      expect(state.hasTile, isFalse);
      expect(state.heldTile, isNull);
    });
  });
}
