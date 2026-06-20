/// ProgressionService — Story 2.5a.
///
/// Vérifie les conditions de déblocage des améliorations après chaque
/// partie et chaque quête complétée. Deux types de conditions :
///   - QUEST  : quête permanente spécifique complétée
///   - TILES_PLACED : total_tiles_placed >= threshold
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';

// ── Providers ────────────────────────────────────────────────────────────

/// Toutes les améliorations (pour l'UI Améliorations — Story 2.5b).
final upgradesProvider = StreamProvider<List<UpgradeRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.upgrades).watch();
});

/// Améliorations débloquées uniquement.
final unlockedUpgradesProvider = Provider<List<UpgradeRow>>((ref) {
  final all = ref.watch(upgradesProvider).maybeWhen(
        data: (list) => list,
        orElse: () => <UpgradeRow>[],
      );
  return all.where((u) => u.isUnlocked).toList();
});

final progressionServiceProvider = Provider<ProgressionService>((ref) {
  return ProgressionService(ref);
});

// ── Service ──────────────────────────────────────────────────────────────

/// Vérifie et applique les déblocages d'améliorations selon les conditions
/// définies dans la table `upgrades`.
///
/// Utilisé après chaque partie ([QuestService.onGameEnd]) et après chaque
/// complétion de quête ([QuestService._handleCompletion]).
class ProgressionService {
  ProgressionService(this._ref);
  final Ref _ref;

  /// Parcourt toutes les améliorations verrouillées et les débloque si
  /// leur condition est remplie.
  Future<void> checkUnlocks() async {
    final db = _ref.read(appDatabaseProvider);

    final locked = await (db.select(db.upgrades)
          ..where((u) => u.isUnlocked.equals(false)))
        .get();

    for (final upgrade in locked) {
      if (await _isConditionMet(upgrade, db)) {
        await db.update(db.upgrades).replace(
              upgrade.copyWith(isUnlocked: true),
            );
      }
    }
  }

  Future<bool> _isConditionMet(UpgradeRow upgrade, AppDatabase db) async {
    if (upgrade.unlockConditionType == 'tiles_placed') {
      return _isTilesPlacedMet(upgrade, db);
    }
    // Par défaut, traité comme type QUEST : unlockConditionType est l'ID
    // de la quête permanente dont la complétion débloque cette amélioration.
    return _isQuestCompleted(upgrade.unlockConditionType, db);
  }

  Future<bool> _isTilesPlacedMet(UpgradeRow upgrade, AppDatabase db) async {
    final profile =
        await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
            .getSingleOrNull();
    if (profile == null) return false;
    return profile.totalTilesPlaced >= upgrade.unlockConditionValue;
  }

  Future<bool> _isQuestCompleted(String questId, AppDatabase db) async {
    final quest = await (db.select(db.permanentQuests)
          ..where((q) => q.id.equals(questId)))
        .getSingleOrNull();
    return quest?.isCompleted ?? false;
  }
}
