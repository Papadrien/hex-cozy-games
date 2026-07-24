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

import '../core/game_enums.dart';
import '../data/app_database.dart';
import '../data/seed_data.dart';
import 'player_profile_provider.dart';
import 'progression_provider.dart';

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

/// Quêtes terminées dont la récompense n'a pas encore été réclamée par le
/// joueur (Story : point rouge / claim manuel).
final unclaimedQuestsProvider = Provider<List<PermanentQuestRow>>((ref) {
  final quests = ref.watch(permanentQuestsProvider).maybeWhen(
        data: (list) => list,
        orElse: () => <PermanentQuestRow>[],
      );
  return quests.where((q) => q.isCompleted && !q.rewardClaimed).toList();
});

/// Vrai s'il existe au moins une quête complétée en attente de réclamation
/// — pilote le point rouge sur le bouton "Quêtes" de l'écran d'accueil.
final hasUnclaimedQuestProvider = Provider<bool>((ref) {
  return ref.watch(unclaimedQuestsProvider).isNotEmpty;
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

  return ids
      .map((id) => kDailyQuestDefMap[id])
      .whereType<DailyQuestDef>()
      .map((def) => DailyQuestWithProgress(
            def: def,
            currentValue: progress[def.id] ?? 0,
            isCompleted: completed.contains(def.id),
          ))
      .toList();
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
  ///
  /// [connectedSidesCount] : nombre de côtés connectés obtenus par la tuile
  /// posée (0 à 6), utilisé pour progresser les quêtes de connexions
  /// multiples (triple/quadruple/quintuple/sextuple).
  Future<void> onTilePlaced({int connectedSidesCount = 0}) async {
    await _updateConnectionQuests(connectedSidesCount);
    final db = _ref.read(appDatabaseProvider);
    await incrementTotalTilesPlaced(db);
    // Les améliorations à condition `tiles_placed` ne dépendent d'aucune
    // quête : on les vérifie ici, en temps réel, indépendamment du claim.
    await _ref.read(progressionServiceProvider).checkUnlocks();
    _ref.invalidate(permanentQuestsProvider);
  }

  /// Appelé à la fin d'une partie (pile épuisée).
  /// [coinsEarned] : total de pièces gagnées pendant cette partie, utilisé
  /// pour progresser le cumul de pièces gagnées et le record de la
  /// meilleure partie. [largestVillage], [closedBiomes] et [maxBiomeSizes]
  /// sont pré-calculés par [BoardAnalysis] pour éviter les traversées
  /// redondantes du plateau. [maxBiomeSizes] alimente les quêtes "cluster
  /// couleur" (forêt/eau/plaine/montagne — Story A4). [bestStreak] est la
  /// meilleure série de connexions consécutives atteinte dans cette partie
  /// (Story B2).
  Future<void> onGameEnd({
    required int coinsEarned,
    required int largestVillage,
    required int closedBiomes,
    Map<String, int> maxBiomeSizes = const {},
    int bestStreak = 0,
  }) async {
    await _updateCoinsEarned(coinsEarned);
    await _updateBestGameCoins(coinsEarned);
    await _updateVillageSize(largestVillage);
    await _updateBiomesClosed(closedBiomes);
    await _updateClusterSizeQuests(
      QuestCategory.forestClusterSize,
      maxBiomeSizes['forest'] ?? 0,
    );
    await _updateClusterSizeQuests(
      QuestCategory.waterClusterSize,
      maxBiomeSizes['water'] ?? 0,
    );
    await _updateClusterSizeQuests(
      QuestCategory.plainClusterSize,
      maxBiomeSizes['plain'] ?? 0,
    );
    await _updateClusterSizeQuests(
      QuestCategory.mountainClusterSize,
      maxBiomeSizes['mountain'] ?? 0,
    );
    await _updateBestConnectionStreak(bestStreak);
    await _updateDailyCoinsEarned(coinsEarned);
    await _updateDailyVillageSize(largestVillage);
    await _updateDailyBiomesClosed(closedBiomes);
    _ref.invalidate(permanentQuestsProvider);
  }

  // ─── coins_earned (cumul toutes parties confondues) ────────────────────

  Future<void> _updateCoinsEarned(int coinsEarned) async {
    if (coinsEarned <= 0) return;
    final db = _ref.read(appDatabaseProvider);
    final rows = await (db.select(db.permanentQuests)
      ..where((q) => q.category.equals(QuestCategory.coinsEarned.dbValue))
      ..where((q) => q.isCompleted.equals(false)))
        .get();
    await db.transaction(() async {
      for (final quest in rows) {
        final newValue = quest.currentValue + coinsEarned;
        final completed = newValue >= quest.targetValue;
        await db.update(db.permanentQuests).replace(quest.copyWith(
              currentValue: newValue,
              isCompleted: completed,
            ));
        if (completed) await _handleCompletion(quest);
      }
    });
  }

  // ─── best_game_coins (record d'une seule partie) ───────────────────────

  Future<void> _updateBestGameCoins(int coinsEarned) async {
    if (coinsEarned <= 0) return;
    final db = _ref.read(appDatabaseProvider);
    final rows = await (db.select(db.permanentQuests)
      ..where((q) => q.category.equals(QuestCategory.bestGameCoins.dbValue))
      ..where((q) => q.isCompleted.equals(false)))
        .get();
    await db.transaction(() async {
      for (final quest in rows) {
        if (coinsEarned <= quest.currentValue) continue;
        final completed = coinsEarned >= quest.targetValue;
        await db.update(db.permanentQuests).replace(quest.copyWith(
              currentValue: coinsEarned,
              isCompleted: completed,
            ));
        if (completed) await _handleCompletion(quest);
      }
    });
  }

  // ─── connexions multiples (répétables) ─────────────────────────────────

  /// Fait progresser d'un cran la quête de connexions correspondant à
  /// [connectedCount] (3, 4, 5 ou 6 côtés). Aucune quête n'existe pour les
  /// valeurs 0, 1 ou 2.
  Future<void> _updateConnectionQuests(int connectedCount) async {
    final category = _connectionCategoryFor(connectedCount);
    if (category == null) return;

    final db = _ref.read(appDatabaseProvider);
    final rows = await (db.select(db.permanentQuests)
          ..where((q) => q.category.equals(category.dbValue))
          ..where((q) => q.isCompleted.equals(false)))
        .get();
    await db.transaction(() async {
      for (final quest in rows) {
        final newValue = quest.currentValue + 1;
        final completed = newValue >= quest.targetValue;
        await db.update(db.permanentQuests).replace(quest.copyWith(
              currentValue: newValue,
              isCompleted: completed,
            ));
        if (completed) await _handleCompletion(quest);
      }
    });
  }

  QuestCategory? _connectionCategoryFor(int connectedCount) {
    switch (connectedCount) {
      case 3:
        return QuestCategory.tripleConnections;
      case 4:
        return QuestCategory.quadConnections;
      case 5:
        return QuestCategory.quintConnections;
      case 6:
        return QuestCategory.sextConnections;
      default:
        return null;
    }
  }

  // ─── village_size / cluster couleur (Story A4) ─────────────────────────
  //
  // Toutes les quêtes "record de plus grand amas connecté" (village, et
  // désormais forêt/eau/plaine/montagne) partagent le même mécanisme de
  // progression : on ne retient que le maximum jamais atteint.

  Future<void> _updateVillageSize(int largest) =>
      _updateClusterSizeQuests(QuestCategory.villageSize, largest);

  Future<void> _updateClusterSizeQuests(
    QuestCategory category,
    int largest,
  ) async {
    if (largest == 0) return;
    final db = _ref.read(appDatabaseProvider);
    final rows = await (db.select(db.permanentQuests)
          ..where((q) => q.category.equals(category.dbValue))
          ..where((q) => q.isCompleted.equals(false)))
        .get();
    await db.transaction(() async {
      for (final quest in rows) {
        if (largest <= quest.currentValue) continue;
        final completed = largest >= quest.targetValue;
        await db.update(db.permanentQuests).replace(quest.copyWith(
              currentValue: largest,
              isCompleted: completed,
            ));
        if (completed) await _handleCompletion(quest);
      }
    });
  }

  // ─── biomes_closed ──────────────────────────────────────────────────────

  Future<void> _updateBiomesClosed(int closed) async {
    if (closed == 0) return;
    final db = _ref.read(appDatabaseProvider);
    final rows = await (db.select(db.permanentQuests)
          ..where((q) => q.category.equals(QuestCategory.biomesClosed.dbValue))
          ..where((q) => q.isCompleted.equals(false)))
        .get();
    await db.transaction(() async {
      for (final quest in rows) {
        final newValue = quest.currentValue + closed;
        final completed = newValue >= quest.targetValue;
        await db.update(db.permanentQuests).replace(quest.copyWith(
              currentValue: newValue,
              isCompleted: completed,
            ));
        if (completed) await _handleCompletion(quest);
      }
    });
  }

  // ─── bestConnectionStreak (Story B2) ────────────────────────────────────

  /// Met à jour les quêtes `bestConnectionStreak` (paliers 20/40/60/80/100)
  /// si [streak] dépasse leur valeur actuelle. Même logique record que
  /// `_updateBestGameCoins` : on ne retient que le maximum jamais atteint,
  /// toutes parties confondues.
  Future<void> _updateBestConnectionStreak(int streak) async {
    if (streak <= 0) return;
    final db = _ref.read(appDatabaseProvider);
    final rows = await (db.select(db.permanentQuests)
          ..where((q) =>
              q.category.equals(QuestCategory.bestConnectionStreak.dbValue))
          ..where((q) => q.isCompleted.equals(false)))
        .get();
    await db.transaction(() async {
      for (final quest in rows) {
        if (streak <= quest.currentValue) continue;
        final completed = streak >= quest.targetValue;
        await db.update(db.permanentQuests).replace(quest.copyWith(
              currentValue: streak,
              isCompleted: completed,
            ));
        if (completed) await _handleCompletion(quest);
      }
    });
  }

  // ─── Completion & rewards ───────────────────────────────────────────────
  //
  // La progression atteint son objectif : la quête est marquée `isCompleted`
  // mais sa récompense reste en attente (`rewardClaimed == false`). Rien
  // n'est débloqué automatiquement — ni pièces, ni quête suivante, ni
  // amélioration — tant que le joueur n'a pas tapé sur la quête (point
  // rouge) pour la réclamer via [claimReward].

  Future<void> _handleCompletion(PermanentQuestRow quest) async {
    // isCompleted a déjà été mis à jour par l'appelant. La quête apparaît
    // désormais comme "terminée" côté UI (point rouge), mais rien n'est
    // débloqué automatiquement ici — ni pièces, ni amélioration : tout
    // attend le tap du joueur sur la quête, géré dans [claimReward].
  }

  Future<void> _grantReward(PermanentQuestRow quest) async {
    if (quest.rewardType == RewardType.coins.dbValue) {
      final db = _ref.read(appDatabaseProvider);
      await addCoinsToProfile(db, quest.rewardValue);
    }
  }

  void _unlockNextQuest(String nextQuestId) {
    // La quête suivante existe déjà dans la table (seedée).
    // Rien à faire : elle devient visible car isCompleted == false.
    // L'UI l'affichera via [activeQuestsProvider].
  }

  /// Réclame la récompense d'une quête terminée (tap du joueur sur la
  /// quête / le point rouge). Octroie la récompense, puis :
  /// - si répétable : remise à zéro instantanée (même palier) ;
  /// - sinon : déverrouille la quête suivante et vérifie les déblocages
  ///   d'améliorations.
  ///
  /// Ne fait rien si la quête n'existe pas, n'est pas terminée, ou a déjà
  /// été réclamée (protège contre un double-tap).
  Future<void> claimReward(String questId) async {
    final db = _ref.read(appDatabaseProvider);
    final quest = await (db.select(db.permanentQuests)
          ..where((q) => q.id.equals(questId)))
        .getSingleOrNull();
    if (quest == null || !quest.isCompleted || quest.rewardClaimed) return;

    await _grantReward(quest);

    if (quest.isRepeatable) {
      // Quête répétable (ex: connexions multiples) : remise à zéro
      // instantanée, même palier, pas de chaîne ni de déblocage.
      await db.update(db.permanentQuests).replace(quest.copyWith(
            currentValue: 0,
            isCompleted: false,
            rewardClaimed: false,
          ));
    } else {
      await db.update(db.permanentQuests).replace(quest.copyWith(
            rewardClaimed: true,
          ));
      if (quest.nextQuestId != null) {
        _unlockNextQuest(quest.nextQuestId!);
      }
      // Débloquer uniquement l'amélioration liée à CETTE quête (Story
      // 2.5a) — pas de sweep global : si plusieurs quêtes sont terminées
      // en attente de claim, chaque claim ne débloque que sa propre
      // amélioration.
      await _ref
          .read(progressionServiceProvider)
          .checkUnlockForQuest(quest.id);
    }
    _ref.invalidate(permanentQuestsProvider);
  }

  // ─── Daily quests (Story 2.4a) ──────────────────────────────────────────

  Future<void> _updateDailyCoinsEarned(int coinsEarned) async {
    if (coinsEarned <= 0) return;
    final db = _ref.read(appDatabaseProvider);
    final rows =
        await (db.select(db.dailyQuests)..where((t) => t.id.equals(1))).get();
    if (rows.isEmpty) return;
    await _applyDailyDelta(rows.first, db, QuestCategory.coinsEarned,
        increment: coinsEarned);
  }

  Future<void> _updateDailyVillageSize(int largest) async {
    if (largest == 0) return;

    final db = _ref.read(appDatabaseProvider);
    final rows =
        await (db.select(db.dailyQuests)..where((t) => t.id.equals(1))).get();
    if (rows.isEmpty) return;
    await _applyDailyDelta(rows.first, db, QuestCategory.villageSize,
        absoluteValue: largest);
  }

  Future<void> _updateDailyBiomesClosed(int closed) async {

    final db = _ref.read(appDatabaseProvider);
    final rows =
        await (db.select(db.dailyQuests)..where((t) => t.id.equals(1))).get();
    if (rows.isEmpty) return;
    await _applyDailyDelta(rows.first, db, QuestCategory.biomesClosed, increment: closed);
  }

  /// Applique une progression aux quêtes quotidiennes d'une catégorie.
  ///
  /// [increment] : valeur ajoutée à chaque quête (ex: +1 tuile posée).
  /// [absoluteValue] : valeur absolue à utiliser si > currentValue
  /// (ex: plus grand village trouvé). Un seul des deux doit être fourni.
  Future<void> _applyDailyDelta(
    DailyQuestRow row,
    AppDatabase db,
    QuestCategory category, {
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

    await db.transaction(() async {
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
    });
  }

  Future<void> _grantDailyReward(DailyQuestDef def) async {
    if (def.rewardType == RewardType.coins) {
      final db = _ref.read(appDatabaseProvider);
      await addCoinsToProfile(db, def.rewardValue);
    }
  }
}
