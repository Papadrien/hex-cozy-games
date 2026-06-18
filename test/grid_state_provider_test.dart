// Tests unitaires pour GridState.availableCellsFor — Story 1.5a.
//
// Vérifie :
//  - plateau vide → seule la cellule centrale (0, 0) est disponible
//  - une cellule vide adjacente à une tuile posée n'est disponible que si
//    elle a au moins un côté compatible avec la tuile testée
//  - une cellule déjà occupée n'est jamais retournée comme disponible

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_cozy_games/game/hex_cell.dart';
import 'package:hex_cozy_games/game/hex_coords.dart';
import 'package:hex_cozy_games/game/hex_tile.dart';
import 'package:hex_cozy_games/providers/grid_state_provider.dart';

HexTile _mono(BiomeType biome) => HexTile(sides: List.filled(6, biome));

void main() {
  group('GridState.availableCellsFor', () {
    test('plateau vide → seule la cellule centrale est disponible', () {
      const grid = GridState(placedTiles: {});

      final available = grid.availableCellsFor(_mono(BiomeType.forest));

      expect(available, {const HexCoords(0, 0)});
    });

    test('une cellule vide adjacente sans côté compatible est exclue', () {
      // Tuile tout-eau posée au centre ; on teste une tuile tout-forêt :
      // aucun côté ne pourra jamais matcher l'eau.
      final grid = GridState(placedTiles: {
        const HexCoords(0, 0): _mono(BiomeType.water),
      });

      final available = grid.availableCellsFor(_mono(BiomeType.forest));

      expect(available, isEmpty);
    });

    test('une cellule vide adjacente avec un côté compatible est incluse', () {
      final grid = GridState(placedTiles: {
        const HexCoords(0, 0): _mono(BiomeType.water),
      });

      final available = grid.availableCellsFor(_mono(BiomeType.water));

      // Les 6 voisins de (0,0) sont tous compatibles (tuile tout-eau).
      expect(available, HexCoords(0, 0).neighbors.toSet());
    });

    test('une cellule déjà occupée n\'est jamais disponible même compatible',
        () {
      final grid = GridState(placedTiles: {
        const HexCoords(0, 0): _mono(BiomeType.water),
        const HexCoords(1, -1): _mono(BiomeType.water),
      });

      final available = grid.availableCellsFor(_mono(BiomeType.water));

      expect(available.contains(const HexCoords(1, -1)), isFalse);
    });

    test('compatibilité tient compte du côté EN REGARD, pas juste "contient"',
        () {
      // Tuile posée au centre : moitié forêt / moitié eau, répartie en
      // arcs contigus. Selon l'orientation testée, seul un sous-ensemble de
      // voisins doit matcher.
      // sides indexés 0=NE,1=E,2=SE,3=SW,4=W,5=NW (voir HexTile doc).
      final placed = HexTile(sides: [
        BiomeType.forest, // NE
        BiomeType.forest, // E
        BiomeType.forest, // SE
        BiomeType.water, // SW
        BiomeType.water, // W
        BiomeType.water, // NW
      ]);
      final grid = GridState(placedTiles: {const HexCoords(0, 0): placed});

      // Tuile testée tout-forêt : ne doit matcher que les voisins situés
      // du côté "forêt" de la tuile posée (NE, E, SE).
      final availableForest = grid.availableCellsFor(_mono(BiomeType.forest));
      expect(availableForest, {
        const HexCoords(0, 0).neighbor(0), // NE
        const HexCoords(0, 0).neighbor(1), // E
        const HexCoords(0, 0).neighbor(2), // SE
      });

      // Tuile testée tout-eau : ne doit matcher que les voisins situés du
      // côté "eau" (SW, W, NW).
      final availableWater = grid.availableCellsFor(_mono(BiomeType.water));
      expect(availableWater, {
        const HexCoords(0, 0).neighbor(3), // SW
        const HexCoords(0, 0).neighbor(4), // W
        const HexCoords(0, 0).neighbor(5), // NW
      });
    });
  });

  group('Grid notifier (gridProvider)', () {
    test('placeTile puis removeTile mettent à jour gridProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const coords = HexCoords(0, 0);
      final tile = _mono(BiomeType.plain);

      container.read(gridProvider.notifier).placeTile(coords, tile);
      expect(container.read(gridProvider).tileAt(coords), tile);

      container.read(gridProvider.notifier).removeTile(coords);
      expect(container.read(gridProvider).tileAt(coords), isNull);
    });
  });
}
