/// Suivi des quêtes permanentes — Story 2.3a.
///
/// [permanentQuestsProvider] expose un stream de toutes les quêtes
/// permanentes. [activeQuestsProvider] filtre les quêtes non terminées
/// (pour l'affichage UI).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../game/hex_cell.dart';
import '../game/hex_coords.dart';
import 'grid_state_provider.dart';
import 'player_profile_provider.dart';

// ── Providers ────────────────────────────────────────────────────────────

final permanentQuestsProvider =
    StreamProvider<List<PermanentQuestRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.permanentQuests).watch();
});

final activeQuestsProvider = Provider<List<PermanentQuestRow>>((ref) {
  final quests = ref.watch(permanentQuestsProvider).maybeWhen(
        data: (list) => list,
        orElse: () => <PermanentQuestRow>[],
      );
  return quests.where((q) => !q.isCompleted).toList();
});

final questServiceProvider = Provider<QuestService>((ref) {
  return QuestService(ref);
});

// ── Quest Service ────────────────────────────────────────────────────────

/// Service de mise à jour des quêtes permanentes — Story 2.3a.
///
/// Écoute les events de jeu (tuile posée, fin de partie) et met à jour
/// la progression des quêtes permanentes dans la base Drift.
/// Vérifie la complétion, accorde les récompenses (pièces / déblocage
/// d'amélioration) et déverrouille la quête suivante.
class QuestService {
  QuestService(this._ref);
  final Ref _ref;

  // ─── Public API ─────────────────────────────────────────────────────────

  /// Appelé après chaque placement de tuile validé.
  Future<void> onTilePlaced() async {
    await _updateTilesPlaced();
    _ref.invalidate(permanentQuestsProvider);
  }

  /// Appelé à la fin d'une partie (pile épuisée).
  Future<void> onGameEnd(GridState grid) async {
    await _updateVillageSize(grid);
    await _updateBiomesClosed(grid);
    _ref.invalidate(permanentQuestsProvider);
  }

  // ─── tiles_placed ───────────────────────────────────────────────────────

  Future<void> _updateTilesPlaced() async {
    final db = _ref.read(appDatabaseProvider);
    final rows = await (db.select(db.permanentQuests)
          ..where((q) => q.category.equals('tiles_placed'))
          ..where((q) => q.isCompleted.equals(false)))
        .get();
    for (final quest in rows) {
      final newValue = quest.currentValue + 1;
      final completed = newValue >= quest.targetValue;
      await db.update(db.permanentQuests).replace(quest.copyWith(
            currentValue: newValue,
            isCompleted: completed,
          ));
      if (completed) await _handleCompletion(quest);
    }
  }

  // ─── village_size ───────────────────────────────────────────────────────

  Future<void> _updateVillageSize(GridState grid) async {
    final largest = _findLargestVillage(grid);
    if (largest == 0) return;
    final db = _ref.read(appDatabaseProvider);
    final rows = await (db.select(db.permanentQuests)
          ..where((q) => q.category.equals('village_size'))
          ..where((q) => q.isCompleted.equals(false)))
        .get();
    for (final quest in rows) {
      if (largest <= quest.currentValue) continue;
      final completed = largest >= quest.targetValue;
      await db.update(db.permanentQuests).replace(quest.copyWith(
            currentValue: largest,
            isCompleted: completed,
          ));
      if (completed) await _handleCompletion(quest);
    }
  }

  int _findLargestVillage(GridState grid) {
    final visited = <HexCoords>{};
    var maxSize = 0;
    for (final entry in grid.placedTiles.entries) {
      if (visited.contains(entry.key)) continue;
      if (!entry.value.sides.contains(BiomeType.village)) continue;
      final cluster = _floodVillage(grid, entry.key, visited);
      if (cluster.length > maxSize) maxSize = cluster.length;
    }
    return maxSize;
  }

  Set<HexCoords> _floodVillage(
    GridState grid,
    HexCoords start,
    Set<HexCoords> visited,
  ) {
    final cluster = <HexCoords>{};
    final queue = [start];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current)) continue;
      final tile = grid.tileAt(current);
      if (tile == null) continue;
      cluster.add(current);
      for (var side = 0; side < 6; side++) {
        if (tile.sides[side] != BiomeType.village) continue;
        final neighbor = current.neighbor(side);
        final nTile = grid.tileAt(neighbor);
        if (nTile != null && nTile.sides[(side + 3) % 6] == BiomeType.village) {
          queue.add(neighbor);
        }
      }
    }
    return cluster;
  }

  // ─── biomes_closed ──────────────────────────────────────────────────────

  Future<void> _updateBiomesClosed(GridState grid) async {
    final closed = _countClosedBiomes(grid);
    if (closed == 0) return;
    final db = _ref.read(appDatabaseProvider);
    final rows = await (db.select(db.permanentQuests)
          ..where((q) => q.category.equals('biomes_closed'))
          ..where((q) => q.isCompleted.equals(false)))
        .get();
    for (final quest in rows) {
      final newValue = quest.currentValue + closed;
      final completed = newValue >= quest.targetValue;
      await db.update(db.permanentQuests).replace(quest.copyWith(
            currentValue: newValue,
            isCompleted: completed,
          ));
      if (completed) await _handleCompletion(quest);
    }
  }

  /// Compte le nombre de biomes complètement fermés sur le plateau.
  ///
  /// Un biome = groupe connexe de tuiles liées par des côtés de même type.
  /// Un biome est fermé quand chaque tuile du groupe a ses 6 voisins
  /// occupés (par n'importe quelle tuile).
  int _countClosedBiomes(GridState grid) {
    final globalVisited = <HexCoords>{};
    var closedCount = 0;
    for (final entry in grid.placedTiles.entries) {
      if (globalVisited.contains(entry.key)) continue;
      final uniqueBiomes = entry.value.sides.toSet();
      for (final biome in uniqueBiomes) {
        if (biome == BiomeType.village) continue;
        final cluster = _floodBiome(grid, entry.key, biome);
        if (cluster.isEmpty) continue;
        globalVisited.addAll(cluster);
        if (_isClosed(grid, cluster)) closedCount++;
      }
    }
    return closedCount;
  }

  Set<HexCoords> _floodBiome(
    GridState grid,
    HexCoords start,
    BiomeType biome,
  ) {
    final visited = <HexCoords>{};
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

  bool _isClosed(GridState grid, Set<HexCoords> cluster) {
    for (final coords in cluster) {
      for (var side = 0; side < 6; side++) {
        if (grid.tileAt(coords.neighbor(side)) == null) return false;
      }
    }
    return true;
  }

  // ─── Completion & rewards ───────────────────────────────────────────────

  Future<void> _handleCompletion(PermanentQuestRow quest) async {
    await _grantReward(quest);
    if (quest.nextQuestId != null) {
      _unlockNextQuest(quest.nextQuestId!);
    }
  }

  Future<void> _grantReward(PermanentQuestRow quest) async {
    if (quest.rewardType == 'coins') {
      final db = _ref.read(appDatabaseProvider);
      await addCoinsToProfile(db, quest.rewardValue);
    } else if (quest.rewardType == 'upgrade_unlock') {
      final db = _ref.read(appDatabaseProvider);
      _unlockUpgradeByQuest(db, quest.id);
    }
  }

  Future<void> _unlockUpgradeByQuest(AppDatabase db, String questId) async {
    final rows = await (db.select(db.upgrades)
          ..where((u) => u.unlockConditionType.equals(questId)))
        .get();
    for (final upgrade in rows) {
      if (!upgrade.isUnlocked) {
        await db.update(db.upgrades).replace(
              upgrade.copyWith(isUnlocked: true),
            );
      }
    }
  }

  void _unlockNextQuest(String nextQuestId) {
    // La quête suivante existe déjà dans la table (seedée).
    // Rien à faire : elle devient visible car isCompleted == false.
    // L'UI l'affichera via [activeQuestsProvider].
  }
}
