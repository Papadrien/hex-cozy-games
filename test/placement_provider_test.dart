// Tests unitaires pour placementProvider — Story 1.5a.
//
// Vérifie :
//  - aucune sélection initiale, pas de previewTile
//  - selectCell sur un emplacement disponible crée la prévisualisation
//  - selectCell sur un emplacement indisponible est ignoré
//  - selectCell sur une AUTRE cellule disponible déplace la prévisualisation
//    et réinitialise la rotation
//  - rotate fait avancer rotationSteps modulo 6, dans les deux sens
//  - rotate ne fait rien sans sélection active

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/game/hex_cell.dart';
import 'package:hex_haven/game/hex_coords.dart';
import 'package:hex_haven/game/hex_tile.dart';
import 'package:hex_haven/providers/grid_state_provider.dart';
import 'package:hex_haven/providers/placement_provider.dart';
import 'package:hex_haven/providers/tile_stack_provider.dart';

import 'fixtures/tile_pool.dart';

void main() {
  group('placementProvider', () {
    test('aucune sélection initiale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(placementProvider);

      expect(state.hasSelection, isFalse);
      expect(
        container.read(placementProvider.notifier).previewTile,
        isNull,
      );
    });

    test('plateau vide → seule (0,0) est disponible, sélectionnable', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(placementProvider.notifier);
      expect(notifier.availableCells, {const HexCoords(0, 0)});

      notifier.selectCell(const HexCoords(0, 0));

      final state = container.read(placementProvider);
      expect(state.selected, const HexCoords(0, 0));
      expect(state.rotationSteps, 0);
      expect(notifier.previewTile, isNotNull);
    });

    test('selectCell sur un emplacement indisponible est ignoré', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(placementProvider.notifier);
      // (1, 0) n'est pas disponible sur plateau vide : seule (0,0) l'est.
      notifier.selectCell(const HexCoords(1, 0));

      expect(container.read(placementProvider).hasSelection, isFalse);
    });

    test('sélectionner une autre cellule disponible déplace la preview et '
        'réinitialise la rotation', () {
      // On force la tuile active à tout-forêt (kTilePool[0]) pour que les 6
      // voisins soient toujours compatibles avec une tuile-forêt au centre.
      final container = ProviderContainer(overrides: [
        tileStackProvider.overrideWith(
          () => _ForcedTileStack(kTilePool[0]),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(gridProvider.notifier).placeTile(
            const HexCoords(0, 0),
            HexTile(sides: List.filled(6, BiomeType.forest)),
          );

      final notifier = container.read(placementProvider.notifier);
      final available = notifier.availableCells.toList();
      expect(available.length, greaterThanOrEqualTo(2));

      notifier.selectCell(available[0]);
      notifier.rotate(2);
      expect(container.read(placementProvider).rotationSteps, 2);

      notifier.selectCell(available[1]);
      final state = container.read(placementProvider);
      expect(state.selected, available[1]);
      expect(state.rotationSteps, 0);
    });

    test('rotate fait avancer rotationSteps modulo 6 (sens horaire et '
        'inverse)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(placementProvider.notifier);
      notifier.selectCell(const HexCoords(0, 0));

      notifier.rotate(4);
      expect(container.read(placementProvider).rotationSteps, 4);

      // +3 → 7 % 6 = 1
      notifier.rotate(3);
      expect(container.read(placementProvider).rotationSteps, 1);

      // Rotation négative (sens inverse) doit rester dans [0, 5].
      notifier.rotate(-2);
      expect(container.read(placementProvider).rotationSteps, 5);
    });

    test('rotate ne fait rien sans sélection active', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(placementProvider.notifier);
      notifier.rotate(3);

      expect(container.read(placementProvider).hasSelection, isFalse);
      expect(container.read(placementProvider).rotationSteps, 0);
    });

    test('previewTile reflète la tuile active tournée de rotationSteps', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(placementProvider.notifier);
      final activeTile = container.read(tileStackProvider).activeTile!;

      notifier.selectCell(const HexCoords(0, 0));
      notifier.rotate(1);

      final preview = notifier.previewTile;
      expect(preview, isNotNull);
      expect(preview!.sides, activeTile.rotated(1).sides);
    });

    test('clearSelection retire la sélection en cours', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(placementProvider.notifier);
      notifier.selectCell(const HexCoords(0, 0));
      expect(container.read(placementProvider).hasSelection, isTrue);

      notifier.clearSelection();
      expect(container.read(placementProvider).hasSelection, isFalse);
    });
  });
}

class _ForcedTileStack extends TileStack {
  _ForcedTileStack(this._forcedTile);
  final HexTile _forcedTile;

  @override
  TileStackState build() {
    return TileStackState(remaining: 12, visible: [_forcedTile]);
  }
}

