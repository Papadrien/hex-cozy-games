/// Suivi des quêtes permanentes et quotidiennes — Story 2.3a / 2.4a.
///
/// [permanentQuestsProvider] expose un stream de toutes les quêtes
/// permanentes. [activeQuestsProvider] filtre les quêtes non terminées
/// (pour l'affichage UI). [dailyQuestsProvider] expose les quêtes
/// du jour avec tirage automatique au premier lancement.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/seed_data.dart';
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

// ── Daily quests (Story 2.4a / 2.4b) ─────────────────────────────────────

/// Quête quotidienne avec sa définition et sa progression parsées.
class DailyQuestWithProgress {
  final DailyQuestDef def;
  final int currentValue;
  final bool isCompleted;

  const DailyQuestWithProgress({
    required this.def,
    required this.currentValue,
    required this.isCompleted,
  });
}

/// Quêtes quotidiennes brutes depuis la base Drift.
///
/// S'assure à chaque souscription qu'un tirage existe pour le jour courant.
/// Le tirage est reproductible (seed = hash("playerId" + date)).
final dailyQuestsProvider = StreamProvider<DailyQuestRow?>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  await _ensureDailyQuestsExist(db);
  yield* db.select(db.dailyQuests).watch().map(
        (rows) => rows.isEmpty ? null : rows.first,
      );
});

/// Quêtes quotidiennes parsées (définition + progression + complétion).
///
/// Transforme le JSON brut de [dailyQuestsProvider] en une liste structurée
/// prête pour l'UI. La progression est conservée entre les relances du même
/// jour (persistance base Drift).
final todayDailyQuestsProvider =
    Provider<List<DailyQuestWithProgress>>((ref) {
  final row = ref.watch(dailyQuestsProvider).maybeWhen(
        data: (r) => r,
        orElse: () => null,
      );
  if (row == null) return [];

  final ids = (jsonDecode(row.questPoolIds) as List).cast<String>();
  final completed =
      (jsonDecode(row.completedIds) as List).cast<String>();
  final progress = (jsonDecode(row.progressByQuestId) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as int));

  return ids.map((id) {
    final def = kDailyQuestDefMap[id]!;
    return DailyQuestWithProgress(
      def: def,
      currentValue: progress[id] ?? 0,
      isCompleted: completed.contains(id),
    );
  }).toList();
});

// ── Helpers ───────────────────────────────────────────────────────────────

/// Hachage déterministe d'une chaîne (Java String.hashCode).
int _stringHash(String s) {
  var hash = 0;
  for (var i = 0; i < s.length; i++) {
    hash = 31 * hash + s.codeUnitAt(i);
  }
  return hash;
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Tire 3 quêtes quotidiennes depuis [kDailyQuestPool] avec un seed
/// reproductible basé sur l'ID du joueur et la date du jour.
List<String> _drawDailyQuestIds() {
  final now = DateTime.now();
  final dateStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final seed = _stringHash('1$dateStr'); // playerId=1 + date
  final rng = Random(seed);

  final pool = List<DailyQuestDef>.from(kDailyQuestPool);
  for (var i = pool.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.take(3).map((d) => d.id).toList();
}

/// Vérifie si les quêtes quotidiennes du jour existent en base.
/// Si la date stockée ≠ date actuelle, tire un nouveau lot et remet
/// la progression à zéro.
Future<void> _ensureDailyQuestsExist(AppDatabase db) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final existing =
      await (db.select(db.dailyQuests)..where((t) => t.id.equals(1)))
          .getSingleOrNull();

  if (existing != null && _isSameDay(existing.date, today)) {
    return;
  }

  final drawnIds = _drawDailyQuestIds();
  final initialProgress = {for (final id in drawnIds) id: 0};

  await db.into(db.dailyQuests).insert(
        DailyQuestsCompanion.insert(
          id: const Value(1),
          date: today,
          questPoolIds: jsonEncode(drawnIds),
          completedIds: jsonEncode(<String>[]),
          progressByQuestId: jsonEncode(initialProgress),
        ),
        mode: InsertMode.replace,
      );
}

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
    await _updateDailyTilesPlaced();
    _ref.invalidate(permanentQuestsProvider);
  }

  /// Appelé à la fin d'une partie (pile épuisée).
  Future<void> onGameEnd(GridState grid) async {
    await _updateVillageSize(grid);
    await _updateBiomesClosed(grid);
    await _updateDailyVillageSize(grid);
    await _updateDailyBiomesClosed(grid);
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

  // ─── Daily quests (Story 2.4a) ──────────────────────────────────────────

  Future<void> _updateDailyTilesPlaced() async {
    final db = _ref.read(appDatabaseProvider);
    final rows =
        await (db.select(db.dailyQuests)..where((t) => t.id.equals(1))).get();
    if (rows.isEmpty) return;
    await _applyDailyDelta(rows.first, db, 'tiles_placed', increment: 1);
  }

  Future<void> _updateDailyVillageSize(GridState grid) async {
    final largest = _findLargestVillage(grid);
    if (largest == 0) return;

    final db = _ref.read(appDatabaseProvider);
    final rows =
        await (db.select(db.dailyQuests)..where((t) => t.id.equals(1))).get();
    if (rows.isEmpty) return;
    await _applyDailyDelta(rows.first, db, 'village_size',
        absoluteValue: largest);
  }

  Future<void> _updateDailyBiomesClosed(GridState grid) async {
    final closed = _countClosedBiomes(grid);
    if (closed == 0) return;

    final db = _ref.read(appDatabaseProvider);
    final rows =
        await (db.select(db.dailyQuests)..where((t) => t.id.equals(1))).get();
    if (rows.isEmpty) return;
    await _applyDailyDelta(rows.first, db, 'biomes_closed', increment: closed);
  }

  /// Applique une progression aux quêtes quotidiennes d'une catégorie.
  ///
  /// [increment] : valeur ajoutée à chaque quête (ex: +1 tuile posée).
  /// [absoluteValue] : valeur absolue à utiliser si > currentValue
  /// (ex: plus grand village trouvé). Un seul des deux doit être fourni.
  Future<void> _applyDailyDelta(
    DailyQuestRow row,
    AppDatabase db,
    String category, {
    int increment = 0,
    int? absoluteValue,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!_isSameDay(row.date, today)) return;

    final progress = Map<String, int>.from(
      (jsonDecode(row.progressByQuestId) as Map)
          .map((k, v) => MapEntry(k as String, v as int)),
    );
    final completed = List<String>.from(
      (jsonDecode(row.completedIds) as List).cast<String>(),
    );
    final poolIds = List<String>.from(
      (jsonDecode(row.questPoolIds) as List).cast<String>(),
    );

    var changed = false;
    for (final id in poolIds) {
      if (completed.contains(id)) continue;
      final def = kDailyQuestDefMap[id];
      if (def == null || def.category != category) continue;

      int newValue;
      if (absoluteValue != null) {
        final current = progress[id] ?? 0;
        if (absoluteValue <= current) continue;
        newValue = absoluteValue;
      } else {
        newValue = (progress[id] ?? 0) + increment;
      }

      progress[id] = newValue;
      if (newValue >= def.targetValue) {
        completed.add(id);
        await _grantDailyReward(def);
      }
      changed = true;
    }

    if (changed) {
      await db.update(db.dailyQuests).replace(row.copyWith(
            progressByQuestId: jsonEncode(progress),
            completedIds: jsonEncode(completed),
          ));
    }
  }

  Future<void> _grantDailyReward(DailyQuestDef def) async {
    if (def.rewardType == 'coins') {
      final db = _ref.read(appDatabaseProvider);
      await addCoinsToProfile(db, def.rewardValue);
    }
  }
}
