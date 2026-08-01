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

import 'package:flutter/foundation.dart' show debugPrint;
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
          '${entry.key.q},${entry.key.r}': entry.value.toJson(),
      };

  factory GridState.fromJson(Map<String, dynamic> json) => GridState(
        placedTiles: {
          for (final entry in json.entries)
            HexCoords(
              int.parse(entry.key.split(',')[0]),
              int.parse(entry.key.split(',')[1]),
            ): HexTile.fromJson(entry.value as Map<String, dynamic>),
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
    if (isEmpty) return {const HexCoords(0, 0)};

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

  /// Nombre de biomes fermés (groupes connexes dont chaque côté appartenant
  /// au biome du cluster a un voisin occupé — les côtés d'une autre couleur
  /// portée par la même tuile ne comptent pas). Toutes les couleurs sont
  /// éligibles, y compris
  /// [BiomeType.village] (harmonisé avec [biomesJustClosed] et
  /// [allBiomeClusters] : plus aucune couleur n'a de traitement à part).
  ///
  /// Le suivi des positions visitées est fait PAR biome (une `Map<BiomeType,
  /// Set&lt;HexCoords&gt;`), pas dans un set global partagé : une tuile porte
  /// jusqu'à 3 biomes différents (Story 1.3), donc une position déjà
  /// visitée pour un biome (ex: forêt) doit rester explorable pour ses
  /// autres biomes (ex: eau) — sinon certains clusters ne sont jamais
  /// comptés selon l'ordre d'itération des tuiles.
  int get closedBiomes {
    final visitedByBiome = <BiomeType, Set<HexCoords>>{};
    var closedCount = 0;
    for (final entry in placedTiles.entries) {
      final uniqueBiomes = entry.value.sides.toSet();
      for (final biome in uniqueBiomes) {
        final visited = visitedByBiome.putIfAbsent(biome, () => <HexCoords>{});
        if (visited.contains(entry.key)) continue;
        final cluster = clusterAt(entry.key, biome);
        if (cluster.isEmpty) continue;
        visited.addAll(cluster);
        if (_isClosed(cluster, biome)) closedCount++;
      }
    }
    return closedCount;
  }

  /// Après avoir placé une tuile à [pos], retourne les fermetures de biomes
  /// (biome, taille du cluster) qui viennent de se produire en direct (B6).
  ///
  /// Chaque cluster connexe impliquant [pos] OU une tuile voisine directe
  /// est testé ; seuls ceux qui sont complètement entourés (6 voisins
  /// présents) sont considérés comme fermés. Toutes les couleurs sont
  /// éligibles (aucune exclusion : les couleurs n'ont plus de sémantique de
  /// "biome" propre, ce ne sont que des identités visuelles au même titre
  /// les unes que les autres — voir Atoll).
  ///
  /// La fermeture d'un cluster ne dépend que du remplissage des côtés qui
  /// appartiennent à SON biome ([_isClosed]/[_openEdges] ignorent les côtés
  /// d'une autre couleur portée par la même tuile — bug Atoll corrigé) —
  /// pas du biome de la tuile qui vient d'être posée. Une pose peut donc
  /// refermer un cluster voisin (ex. violet) alors que la tuile posée
  /// elle-même n'a aucune face violette : elle ne fait que combler le
  /// dernier trou de sa bordure. Les biomes candidats incluent donc, en plus
  /// de ceux de [tile], celui de chaque tuile voisine sur la face qui fait
  /// face à [pos].
  ///
  /// Logs de diagnostic (préfixe `[Atoll]`) ajoutés temporairement pour
  /// analyser en direct les fermetures manquées — à retirer une fois le
  /// débogage terminé.
  List<MapEntry<BiomeType, int>> biomesJustClosed(
      HexCoords pos, HexTile tile) {
    final closures = <MapEntry<BiomeType, int>>[];
    final visitedByBiome = <BiomeType, Set<HexCoords>>{};

    debugPrint('[Atoll] biomesJustClosed pos=$pos '
        'tileBiomes=${tile.sides.toSet()}');

    void checkCluster(HexCoords anchor, BiomeType biome) {
      final visited = visitedByBiome.putIfAbsent(biome, () => <HexCoords>{});
      if (visited.contains(anchor)) {
        debugPrint('[Atoll]   skip biome=$biome anchor=$anchor '
            '(déjà visité pour ce biome sur cette pose)');
        return;
      }
      final cluster = clusterAt(anchor, biome);
      if (cluster.isEmpty) return;
      visited.addAll(cluster);
      // Auparavant calculé via _missingNeighbors (une fonction séparée,
      // dédupliquée par position) — remplacé par _openEdges (même fonction
      // que celle utilisée par l'overlay de rendu des arêtes ouvertes,
      // hex_grid_component.dart) pour qu'il soit IMPOSSIBLE que le log et
      // ce qui est tracé à l'écran divergent : une seule source de vérité.
      final openEdges = _openEdges(cluster, biome);
      final closed = openEdges.isEmpty;
      debugPrint('[Atoll]   cluster biome=$biome anchor=$anchor '
          'size=${cluster.length} closed=$closed'
          '${closed ? '' : ' openEdges=${openEdges.map((e) => '${e.coords}'
              '/${e.side}').toList()}'}');
      if (closed) {
        closures.add(MapEntry(biome, cluster.length));
      }
    }

    for (final biome in tile.sides.toSet()) {
      checkCluster(pos, biome);
    }
    for (var side = 0; side < 6; side++) {
      final neighborPos = pos.neighbor(side);
      // [pos] peut très bien avoir un voisin encore vide sur un AUTRE côté
      // (ex. bord de mer) sans que cela empêche la fermeture d'un cluster
      // voisin sur ce côté-ci : on ne peut donc plus présumer que tous les
      // voisins de [pos] sont posés (voir suppression du early-exit
      // ci-dessus) et on ignore simplement les côtés encore vides.
      final neighborTile = placedTiles[neighborPos];
      if (neighborTile == null) continue;
      final facingBiome = neighborTile.sides[(side + 3) % 6];
      checkCluster(neighborPos, facingBiome);
    }
    debugPrint('[Atoll] => closures=$closures');
    return closures;
  }

  bool _isClosed(Set<HexCoords> cluster, BiomeType biome) =>
      _openEdges(cluster, biome).isEmpty;

  /// Retourne, pour TOUTE tuile du [cluster], chaque côté (0-5) qui
  /// appartient bien au [biome] du cluster ET n'a pas de voisin posé — liste
  /// vide ⇔ cluster fermé ([_isClosed]). Seule et unique implémentation de
  /// ce calcul (auparavant dupliquée avec `_missingNeighbors`, qui donnait
  /// la position voisine plutôt que l'arête précise — supprimée pour qu'il
  /// n'y ait plus qu'une source de vérité, utilisée à la fois par les logs
  /// [Atoll] et par l'overlay de rendu des arêtes ouvertes,
  /// `hex_grid_component.dart`).
  ///
  /// [biome] est indispensable : une tuile peut porter jusqu'à 3 biomes
  /// différents (Story 1.3), répartis en arcs de côtés. Un côté vide ne
  /// bloque la fermeture QUE s'il fait partie du contour du [biome] suivi —
  /// un côté vide en face d'une autre couleur de la même tuile ne fait pas
  /// partie de la frontière de ce cluster et ne doit pas être compté (bug
  /// Atoll signalé : tuile mixte rouge/bleu comptée comme ouverte côté
  /// rouge à cause d'un côté bleu encore vide ailleurs sur la même tuile).
  List<({HexCoords coords, int side})> _openEdges(
      Set<HexCoords> cluster, BiomeType biome) {
    final edges = <({HexCoords coords, int side})>[];
    for (final coords in cluster) {
      final tile = placedTiles[coords];
      if (tile == null) continue;
      for (var side = 0; side < 6; side++) {
        if (tile.sides[side] != biome) continue;
        if (!placedTiles.containsKey(coords.neighbor(side))) {
          edges.add((coords: coords, side: side));
        }
      }
    }
    return edges;
  }

  /// Énumère TOUS les clusters connexes de biome présents
  /// sur le plateau, fermés ou non — contrairement à [closedBiomes] (qui ne
  /// fait que les compter) ou [biomesJustClosed] (qui ne regarde que les
  /// fermetures d'une pose précise), utilisé pour l'affichage à la demande
  /// des tailles de zone (voir `active_upgrades_hud.dart`, slot "Bonus de
  /// clôture" / `biomeSizeOverlayProvider`). Même logique de suivi PAR
  /// biome que [closedBiomes] — une tuile porte jusqu'à 3 biomes différents,
  /// une position déjà visitée pour l'un doit rester explorable pour les
  /// autres.
  ///
  /// Chaque entrée porte aussi [isClosed] (même définition que
  /// [_isClosed] : chaque côté du cluster appartenant à SON biome a un
  /// voisin occupé — les côtés d'une autre couleur sur une tuile mixte ne
  /// comptent pas) — permet à l'overlay d'afficher un cadenas
  /// sur les zones déjà scellées plutôt que de ne montrer qu'une taille
  /// brute, ambiguë sur le fait qu'elle rapportera ou non un bonus. Et
  /// [openEdges] : les arêtes (tuile + côté) sans voisin posé, qui
  /// empêchent la fermeture (vide si [isClosed]) — overlay debug [Atoll]
  /// pour repérer visuellement, arête par arête, quel côté précis bloque
  /// une fermeture inattendue.
  /// Toutes les couleurs sont éligibles, y compris [BiomeType.village]
  /// (voir Atoll : plus aucune couleur n'a de traitement à part).
  List<
      ({
        Set<HexCoords> cluster,
        bool isClosed,
        List<({HexCoords coords, int side})> openEdges
      })> get allBiomeClusters {
    final visitedByBiome = <BiomeType, Set<HexCoords>>{};
    final clusters = <
        ({
          Set<HexCoords> cluster,
          bool isClosed,
          List<({HexCoords coords, int side})> openEdges
        })>[];
    for (final entry in placedTiles.entries) {
      final uniqueBiomes = entry.value.sides.toSet();
      for (final biome in uniqueBiomes) {
        final visited = visitedByBiome.putIfAbsent(biome, () => <HexCoords>{});
        if (visited.contains(entry.key)) continue;
        final cluster = clusterAt(entry.key, biome);
        if (cluster.isEmpty) continue;
        visited.addAll(cluster);
        final openEdges = _openEdges(cluster, biome);
        clusters.add((
          cluster: cluster,
          isClosed: openEdges.isEmpty,
          openEdges: openEdges
        ));
      }
    }
    return clusters;
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

  /// Remet le plateau à zéro (nouvelle partie).
  void reset() {
    state = const GridState(placedTiles: {});
  }
}
