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

import 'dart:collection';

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

  Map<String, dynamic> toJson() => {
        for (final entry in placedTiles.entries)
          '${entry.key.q},${entry.key.r}': entry.value.toJson()['sides'],
      };

  factory GridState.fromJson(Map<String, dynamic> json) => GridState(
        placedTiles: {
          for (final entry in json.entries)
            HexCoords(
              int.parse(entry.key.split(',')[0]),
              int.parse(entry.key.split(',')[1]),
            ): HexTile.fromJson({'sides': entry.value}),
        },
      );

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

  /// Vrai si [tile] (dans au moins une rotation) a un côté dont le biome
  /// correspond au côté opposé d'une tuile voisine en [coords].
  /// Utilisé pour la contrainte de continuité des bords (Story 1.9b).
  bool canPlaceTileAt(HexCoords coords, HexTile tile) {
    if (isEmpty) return true; // première tuile toujours autorisée
    for (var rotation = 0; rotation < 6; rotation++) {
      final rotated = tile.rotated(rotation);
      if (hasCompatibleSide(coords, rotated)) return true;
    }
    return false;
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

  // ── BFS commun pour tous les parcours de plateau ──────────────────────────

  /// Parcours en largeur (BFS) depuis [start] en suivant les arêtes contiguës
  /// du biome [biome]. Retourne l'ensemble des [HexCoords] formant le groupe
  /// connexe.
  ///
  /// Utilise une [Queue] pour garantir O(n) au lieu du O(n²) d'une List avec
  /// removeAt(0).
  Set<HexCoords> clusterAt(HexCoords start, BiomeType biome) {
    final visited = <HexCoords>{};
    final cluster = <HexCoords>{};
    final queue = Queue<HexCoords>()..add(start);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (!visited.add(current)) continue;
      final tile = placedTiles[current];
      if (tile == null || !tile.sides.contains(biome)) continue;
      cluster.add(current);
      for (var side = 0; side < 6; side++) {
        if (tile.sides[side] != biome) continue;
        final neighbor = current.neighbor(side);
        final nTile = placedTiles[neighbor];
        if (nTile != null && nTile.sides[(side + 3) % 6] == biome) {
          queue.add(neighbor);
        }
      }
    }
    return cluster;
  }

  /// Taille du plus grand village (cluster de [BiomeType.village]).
  int get largestVillage {
    final visited = <HexCoords>{};
    var maxSize = 0;
    for (final entry in placedTiles.entries) {
      if (visited.contains(entry.key)) continue;
      if (!entry.value.sides.contains(BiomeType.village)) continue;
      final cluster = clusterAt(entry.key, BiomeType.village);
      visited.addAll(cluster);
      if (cluster.length > maxSize) maxSize = cluster.length;
    }
    return maxSize;
  }

  /// Nombre de biomes fermés (groupes connexes dont chaque tuile a ses 6
  /// voisins occupés). [BiomeType.village] est exclu.
  int get closedBiomes {
    final globalVisited = <HexCoords>{};
    var closedCount = 0;
    for (final entry in placedTiles.entries) {
      if (globalVisited.contains(entry.key)) continue;
      final uniqueBiomes = entry.value.sides.toSet();
      for (final biome in uniqueBiomes) {
        if (biome == BiomeType.village) continue;
        final cluster = clusterAt(entry.key, biome);
        if (cluster.isEmpty) continue;
        globalVisited.addAll(cluster);
        if (_isClosed(cluster)) closedCount++;
      }
    }
    return closedCount;
  }

  bool _isClosed(Set<HexCoords> cluster) {
    for (final coords in cluster) {
      for (var side = 0; side < 6; side++) {
        if (!placedTiles.containsKey(coords.neighbor(side))) return false;
      }
    }
    return true;
  }

  /// Taille maximale de cluster pour chaque [BiomeType] (sous forme de Map
  /// nom → taille). Équivalent à [computeMaxBiomeSizes] mais utilisant le
  /// BFS partagé.
  Map<String, int> get maxBiomeSizes {
    final result = <String, int>{};
    for (final biome in BiomeType.values) {
      final visited = <HexCoords>{};
      var maxSize = 0;
      for (final entry in placedTiles.entries) {
        if (visited.contains(entry.key)) continue;
        if (!entry.value.sides.contains(biome)) continue;
        final cluster = clusterAt(entry.key, biome);
        visited.addAll(cluster);
        if (cluster.length > maxSize) maxSize = cluster.length;
      }
      result[biome.name] = maxSize;
    }
    return result;
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
