/// État du plateau (tuiles posées) et logique de disponibilité des
/// emplacements — Story 1.5a.
///
/// Logique pure et testable, indépendante de Flame : [GridState] ne connaît
/// que les coordonnées et les tuiles, pas les pixels ni le rendu.
///
/// Règles de disponibilité (contexte story 1.6a) :
///  - Au démarrage (plateau vide), seule la cellule centrale (0, 0) est
///    disponible.
///  - Sinon, toute cellule vide adjacente à une tuile posée est disponible,
///    sans contrainte de compatibilité de biome.
///
/// Détection des connexions : [countConnectedSides] compte le nombre de
/// côtés d'une tuile posée dont le biome correspond au biome de la tuile
/// voisine (côté en regard).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../game/hex_cell.dart';
import '../game/hex_coords.dart';
import '../game/hex_tile.dart';

part 'grid_state_provider.g.dart';

/// État immuable du plateau : uniquement les tuiles déjà posées (validées).
/// Les tuiles en cours de prévisualisation ne font PAS partie de cet état
/// (voir [placementProvider]).
class GridState {
  const GridState({required this.placedTiles});

  /// Tuiles posées, indexées par coordonnées.
  final Map<HexCoords, HexTile> placedTiles;

  bool get isEmpty => placedTiles.isEmpty;

  HexTile? tileAt(HexCoords coords) => placedTiles[coords];

  /// Pour chaque côté `i` de [coords], le côté opposé `(i+3)%6` du voisin
  /// dans la direction `i` est le côté qui serait en regard. Retourne le
  /// [BiomeType] de ce côté voisin, ou null si pas de voisin posé dans
  /// cette direction.
  BiomeType? _neighborFacingBiome(HexCoords coords, int side) {
    final neighborCoords = coords.neighbor(side);
    final neighborTile = placedTiles[neighborCoords];
    if (neighborTile == null) return null;
    final facingSide = (side + 3) % 6;
    return neighborTile.sides[facingSide];
  }

  /// Vrai si poser [tile] (déjà tournée) en [coords] aurait au moins un côté
  /// compatible avec une tuile adjacente déjà posée.
  bool hasCompatibleSide(HexCoords coords, HexTile tile) {
    for (var side = 0; side < 6; side++) {
      final neighborBiome = _neighborFacingBiome(coords, side);
      if (neighborBiome != null && neighborBiome == tile.sides[side]) {
        return true;
      }
    }
    return false;
  }

  /// Calcule l'ensemble des emplacements disponibles pour poser une tuile.
  ///
  /// - Plateau vide → uniquement la cellule centrale (0, 0).
  /// - Sinon → toute cellule vide adjacente à une tuile posée (sans
  ///   contrainte de compatibilité de biome — story 1.6a).
  Set<HexCoords> availableCellsFor() {
    if (isEmpty) return {HexCoords(0, 0)};

    final candidates = <HexCoords>{};
    for (final coords in placedTiles.keys) {
      for (final neighbor in coords.neighbors) {
        if (!placedTiles.containsKey(neighbor)) {
          candidates.add(neighbor);
        }
      }
    }

    return candidates;
  }

  /// Compte le nombre de côtés de la tuile [tile] placée en [coords] qui
  /// sont connectés à une tuile adjacente avec un biome correspondant.
  ///
  /// Pour chaque côté `i` de la tuile, on vérifie si la cellule voisine
  /// dans cette direction a une tuile posée, et si le [BiomeType] du côté
  /// en regard de cette tuile voisine (côté `(i + 3) % 6`) correspond au
  /// biome `tile.sides[i]`.
  ///
  /// Retourne un entier entre 0 et 6.
  int countConnectedSides(HexCoords coords, HexTile tile) {
    var count = 0;
    for (var side = 0; side < 6; side++) {
      final neighborBiome = _neighborFacingBiome(coords, side);
      if (neighborBiome != null && neighborBiome == tile.sides[side]) {
        count++;
      }
    }
    return count;
  }
}

@Riverpod(keepAlive: true)
class Grid extends _$Grid {
  @override
  GridState build() => const GridState(placedTiles: {});

  /// Pose [tile] (déjà tournée) en [coords]. Écrase silencieusement une
  /// tuile existante à ces coordonnées (ne devrait pas arriver en pratique,
  /// la validation de l'emplacement est faite avant l'appel).
  void placeTile(HexCoords coords, HexTile tile) {
    state = GridState(
      placedTiles: {...state.placedTiles, coords: tile},
    );
  }

  /// Retire la tuile en [coords] (utilisé par le bouton Annuler — story 1.5b).
  void removeTile(HexCoords coords) {
    final updated = {...state.placedTiles}..remove(coords);
    state = GridState(placedTiles: updated);
  }

  /// Remplace tout l'état du plateau (restauration de session).
  void setState(Map<HexCoords, HexTile> tiles) {
    state = GridState(placedTiles: tiles);
  }
}
