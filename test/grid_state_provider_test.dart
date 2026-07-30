// Tests unitaires pour GridState — Stories 1.5a et 1.6a.
//
// availableCellsFor (1.6a) :
//  - plus de contrainte de compatibilité de biome : toute cellule vide
//    adjacente à une tuile posée est disponible
//  - plateau vide → seule (0, 0) est disponible
//  - une cellule occupée n'est jamais disponible
//
// countConnectedSides (1.6a) :
//  - compte correctement 0 à 6 côtés connectés
//  - pas de faux positif / négatif
//  - fonction pure testable unitairement

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/game/hex_cell.dart';
import 'package:hex_haven/game/hex_coords.dart';
import 'package:hex_haven/game/hex_tile.dart';
import 'package:hex_haven/providers/grid_state_provider.dart';

HexTile _mono(BiomeType biome) => HexTile(sides: List.filled(6, biome));

void main() {
  group('GridState.availableCellsFor', () {
    test('plateau vide → seule la cellule centrale est disponible', () {
      const grid = GridState(placedTiles: {});

      final available = grid.availableCellsFor();

      expect(available, {const HexCoords(0, 0)});
    });

    test('tous les voisins vides d\'une tuile posée sont disponibles '
        'indépendamment du biome', () {
      final grid = GridState(placedTiles: {
        const HexCoords(0, 0): _mono(BiomeType.water),
      });

      final available = grid.availableCellsFor();

      // Les 6 voisins de (0,0) doivent tous être disponibles, même si on
      // n'a aucune tuile compatible en main.
      expect(available, const HexCoords(0, 0).neighbors.toSet());
    });

    test('une cellule déjà occupée n\'est pas disponible', () {
      final grid = GridState(placedTiles: {
        const HexCoords(0, 0): _mono(BiomeType.water),
        const HexCoords(1, -1): _mono(BiomeType.water),
      });

      final available = grid.availableCellsFor();

      expect(available.contains(const HexCoords(1, -1)), isFalse);
    });

    test('cellules disponibles avec plusieurs tuiles posées', () {
      // Deux tuiles côte à côte : (0,0) et (1,0). Les voisins vides
      // doivent être l'union des voisins des deux tuiles, moins les
      // cellules occupées.
      final grid = GridState(placedTiles: {
        const HexCoords(0, 0): _mono(BiomeType.forest),
        const HexCoords(1, 0): _mono(BiomeType.plain),
      });

      final available = grid.availableCellsFor();

      // Voisins de (0,0) : (1,-1), (1,0), (0,1), (-1,1), (-1,0), (0,-1)
      // Voisins de (1,0) : (2,-1), (2,0), (1,1), (0,1), (0,0), (1,-1)
      // Exclus : (0,0) et (1,0) qui sont occupés
      // Union : (1,-1), (0,1), (-1,1), (-1,0), (0,-1), (2,-1), (2,0), (1,1)
      expect(available, {
        const HexCoords(1, -1),
        const HexCoords(0, 1),
        const HexCoords(-1, 1),
        const HexCoords(-1, 0),
        const HexCoords(0, -1),
        const HexCoords(2, -1),
        const HexCoords(2, 0),
        const HexCoords(1, 1),
      });
    });
  });

  group('GridState.countConnectedSides', () {
    test('aucun voisin → 0 connexion', () {
      const grid = GridState(placedTiles: {});
      const coords = HexCoords(0, 0);

      expect(grid.countConnectedSides(coords, _mono(BiomeType.forest)), 0);
    });

    test('tous les 6 voisins matchent → 6 connexions', () {
      final grid = GridState(placedTiles: {
        const HexCoords(1, -1): _mono(BiomeType.forest), // NE
        const HexCoords(1, 0): _mono(BiomeType.forest), // E
        const HexCoords(0, 1): _mono(BiomeType.forest), // SE
        const HexCoords(-1, 1): _mono(BiomeType.forest), // SW
        const HexCoords(-1, 0): _mono(BiomeType.forest), // W
        const HexCoords(0, -1): _mono(BiomeType.forest), // NW
      });

      expect(
        grid.countConnectedSides(
          const HexCoords(0, 0),
          _mono(BiomeType.forest),
        ),
        6,
      );
    });

    test('aucun voisin ne match → 0 connexion', () {
      // Les 6 voisins sont tout-eau, la tuile posée est tout-forêt.
      final grid = GridState(placedTiles: {
        const HexCoords(1, -1): _mono(BiomeType.water),
        const HexCoords(1, 0): _mono(BiomeType.water),
        const HexCoords(0, 1): _mono(BiomeType.water),
        const HexCoords(-1, 1): _mono(BiomeType.water),
        const HexCoords(-1, 0): _mono(BiomeType.water),
        const HexCoords(0, -1): _mono(BiomeType.water),
      });

      expect(
        grid.countConnectedSides(
          const HexCoords(0, 0),
          _mono(BiomeType.forest),
        ),
        0,
      );
    });

    test('seulement certains côtés matchent → nombre correct', () {
      // Tuile au centre avec 3 forêts puis 3 eaux.
      //   NE(0)=forest, E(1)=forest, SE(2)=forest,
      //   SW(3)=water,  W(4)=water,  NW(5)=water
      final placed = HexTile(sides: [
        BiomeType.forest, // NE
        BiomeType.forest, // E
        BiomeType.forest, // SE
        BiomeType.water, // SW
        BiomeType.water, // W
        BiomeType.water, // NW
      ]);
      final grid = GridState(placedTiles: {const HexCoords(0, 0): placed});

      // (1, 0) est à l'est du centre. Son côté W (4) fait face au
      // côté E (1) du centre = forest → 1 connexion.
      expect(
        grid.countConnectedSides(
          const HexCoords(1, 0),
          _mono(BiomeType.forest),
        ),
        1,
      );

      // (-1, 0) est à l'ouest du centre. Son côté E (1) fait face au
      // côté W (4) du centre = water → 0 connexion.
      expect(
        grid.countConnectedSides(
          const HexCoords(-1, 0),
          _mono(BiomeType.forest),
        ),
        0,
      );
    });

    test('côté EN REGARD est correct (opposé, pas le même)', () {
      // La connexion doit vérifier le côté opposé du voisin, pas le
      // même index.
      // Tuile tout-eau en (0,0). Si on place une tuile tout-eau en
      // (1,0), le côté E (1) de (1,0) fait face au côté W (4) de (0,0).
      // Les deux sont EAU → 1 connexion.
      final grid = GridState(placedTiles: {
        const HexCoords(0, 0): _mono(BiomeType.water),
      });

      expect(
        grid.countConnectedSides(
          const HexCoords(1, 0),
          _mono(BiomeType.water),
        ),
        1,
      );
    });

    test('voisins partiels → nombre correct', () {
      // 3 voisins seulement : NE, E, SE. Match forêt → 3.
      final grid = GridState(placedTiles: {
        const HexCoords(1, -1): _mono(BiomeType.forest), // NE
        const HexCoords(1, 0): _mono(BiomeType.forest), // E
        const HexCoords(0, 1): _mono(BiomeType.forest), // SE
      });

      expect(
        grid.countConnectedSides(
          const HexCoords(0, 0),
          _mono(BiomeType.forest),
        ),
        3,
      );
    });

    test('voisins partiels avec certains non-matchants → nombre correct', () {
      // 3 voisins : NE (eau), E (forêt), SE (forêt).
      // Tuile posée tout-forêt → seulement 2 connexions.
      final grid = GridState(placedTiles: {
        const HexCoords(1, -1): _mono(BiomeType.water), // NE
        const HexCoords(1, 0): _mono(BiomeType.forest), // E
        const HexCoords(0, 1): _mono(BiomeType.forest), // SE
      });

      expect(
        grid.countConnectedSides(
          const HexCoords(0, 0),
          _mono(BiomeType.forest),
        ),
        2,
      );
    });
  });

  group('GridState.biomesJustClosed', () {
    test('ferme le cluster de la tuile posée elle-même quand il est '
        'entièrement entouré', () {
      // (0,0) tout-montagne entourée de ses 6 voisins (n'importe quel
      // biome : seule la présence compte pour _isClosed).
      final grid = GridState(placedTiles: {
        const HexCoords(1, -1): _mono(BiomeType.forest),
        const HexCoords(1, 0): _mono(BiomeType.forest),
        const HexCoords(0, 1): _mono(BiomeType.forest),
        const HexCoords(-1, 1): _mono(BiomeType.forest),
        const HexCoords(-1, 0): _mono(BiomeType.forest),
        const HexCoords(0, -1): _mono(BiomeType.forest),
        const HexCoords(0, 0): _mono(BiomeType.mountain),
      });

      final closures = grid.biomesJustClosed(
          const HexCoords(0, 0), _mono(BiomeType.mountain));

      expect(closures, hasLength(1));
      expect(closures[0].key, BiomeType.mountain);
      expect(closures[0].value, 1);
    });

    test(
        'régression Atoll : ferme le cluster d\'une tuile VOISINE même si '
        'la tuile posée a elle-même un autre voisin encore vide (bord de '
        'mer) sur un côté différent — la tuile posée n\'a ici aucune face '
        'montagne', () {
      // T = (1,-1), tout-montagne : ses 5 autres voisins (hors pos) sont
      // déjà remplis, il ne lui manquait que pos pour être fermée.
      final grid = GridState(placedTiles: {
        const HexCoords(1, -1): _mono(BiomeType.mountain), // T
        const HexCoords(2, -2): _mono(BiomeType.forest),
        const HexCoords(2, -1): _mono(BiomeType.forest),
        const HexCoords(1, 0): _mono(BiomeType.forest),
        const HexCoords(0, -1): _mono(BiomeType.forest),
        const HexCoords(1, -2): _mono(BiomeType.forest),
        // pos = (0,0), posée tout-plaine. (0,1), (-1,1) et (-1,0) restent
        // volontairement vides pour simuler un bord de mer sur 3 des
        // autres côtés de pos, sans rapport avec la fermeture de T.
        const HexCoords(0, 0): _mono(BiomeType.plain),
      });

      final closures = grid.biomesJustClosed(
          const HexCoords(0, 0), _mono(BiomeType.plain));

      expect(closures, hasLength(1));
      expect(closures[0].key, BiomeType.mountain);
      expect(closures[0].value, 1);
    });

    test('aucune fermeture si aucun cluster touché n\'est entièrement '
        'entouré', () {
      final grid = GridState(placedTiles: {
        const HexCoords(0, 0): _mono(BiomeType.mountain),
        const HexCoords(1, -1): _mono(BiomeType.forest),
      });

      final closures = grid.biomesJustClosed(
          const HexCoords(0, 0), _mono(BiomeType.mountain));

      expect(closures, isEmpty);
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
