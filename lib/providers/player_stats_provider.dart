/// Statistiques joueur persistées — Story 2.2b / 2.9a.
///
/// Met à jour `player_stats` en fin de chaque partie :
///   - total_coins_earned (cumul)
///   - total_games_played
///   - total_tiles_placed (cumul)
///   - best_score (meilleur score en une partie)
///   - max_biome_sizes (taille max atteinte pour chaque biome, JSON)
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../game/hex_cell.dart';
import '../game/hex_coords.dart';
import 'grid_state_provider.dart';

/// Provider Riverpod streamant la ligne unique de [PlayerStats].
/// Retourne une ligne à zéro si aucune statistique n'existe encore.
final playerStatsProvider = StreamProvider<PlayerStatsRow>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.playerStats)..where((t) => t.id.equals(1)))
      .watchSingleOrNull()
      .map((row) => row ?? const PlayerStatsRow(
            id: 1,
            totalTilesPlaced: 0,
            totalGamesPlayed: 0,
            totalCoinsEarned: 0,
            bestScore: 0,
            maxBiomeSizes: '{}',
          ));
});

Future<void> _ensureStatsExist(AppDatabase db) async {
  final existing =
      await (db.select(db.playerStats)..where((t) => t.id.equals(1)))
          .getSingleOrNull();
  if (existing == null) {
    await db.into(db.playerStats).insert(
          PlayerStatsCompanion(id: const Value(1), maxBiomeSizes: const Value('{}')),
        );
  }
}

/// Enregistre la fin d'une partie : met à jour toutes les colonnes de
/// [PlayerStats] avec les données de la partie terminée.
Future<void> recordGameEnd(
  AppDatabase db, {
  required int coinsEarned,
  required int score,
  required int tilesPlacedInGame,
  required Map<String, int> maxBiomeSizes,
}) async {
  await _ensureStatsExist(db);
  final table = db.playerStats;
  final current =
      await (db.select(table)..where((t) => t.id.equals(1))).getSingle();

  // Fusionner les maxBiomeSizes existants avec les nouveaux.
  final existingSizes =
      Map<String, int>.from(jsonDecode(current.maxBiomeSizes) as Map);
  for (final entry in maxBiomeSizes.entries) {
    existingSizes.update(
      entry.key,
      (v) => v > entry.value ? v : entry.value,
      ifAbsent: () => entry.value,
    );
  }

  await (db.update(table)..where((t) => t.id.equals(1))).write(
    PlayerStatsCompanion.custom(
      totalCoinsEarned: table.totalCoinsEarned + Variable(coinsEarned),
      totalGamesPlayed: table.totalGamesPlayed + const Variable(1),
      totalTilesPlaced: table.totalTilesPlaced + Variable(tilesPlacedInGame),
      bestScore: Variable(
        score > current.bestScore ? score : current.bestScore,
      ),
      maxBiomeSizes: Variable(jsonEncode(existingSizes)),
    ),
  );
}

/// Calcule la taille du plus grand groupe connexe pour chaque biome sur le
/// plateau [grid].
///
/// Deux tuiles sont connectées si leur côté en regard partage le même biome.
/// Retourne une map biome_name → taille_max.
Map<String, int> computeMaxBiomeSizes(GridState grid) {
  final result = <String, int>{};
  for (final biome in BiomeType.values) {
    result[biome.name] = _maxClusterSizeFor(grid, biome);
  }
  return result;
}

int _maxClusterSizeFor(GridState grid, BiomeType biome) {
  final visited = <HexCoords>{};
  var maxSize = 0;
  for (final entry in grid.placedTiles.entries) {
    if (visited.contains(entry.key)) continue;
    if (!entry.value.sides.contains(biome)) continue;
    final cluster = _floodBiome(grid, entry.key, biome, visited);
    if (cluster.length > maxSize) maxSize = cluster.length;
  }
  return maxSize;
}

Set<HexCoords> _floodBiome(
  GridState grid,
  HexCoords start,
  BiomeType biome,
  Set<HexCoords> visited,
) {
  final cluster = <HexCoords>{};
  final queue = [start];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    if (!visited.add(current)) continue;
    final tile = grid.tileAt(current);
    if (tile == null || !tile.sides.contains(biome)) continue;
    cluster.add(current);
    for (var side = 0; side < 6; side++) {
      if (tile.sides[side] != biome) continue;
      final neighbor = current.neighbor(side);
      final nTile = grid.tileAt(neighbor);
      if (nTile != null && nTile.sides[(side + 3) % 6] == biome) {
        queue.add(neighbor);
      }
    }
  }
  return cluster;
}
