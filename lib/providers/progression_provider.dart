/// ProgressionService — Story 2.5a / 2.6a.
///
/// Vérifie les conditions de déblocage des améliorations après chaque
/// partie et chaque quête complétée. Deux types de conditions :
///   - QUEST  : quête permanente spécifique complétée
///   - TILES_PLACED : total_tiles_placed >= threshold
///
/// Montée en niveau (2.6a) : transaction atomique qui débite les pièces
/// et met à jour le niveau courant.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import 'player_profile_provider.dart';

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

// ── Résultat de montée en niveau ────────────────────────────────────────

/// Résultat d'une tentative de montée en niveau d'amélioration — Story 2.6a.
enum UpgradeResult {
  /// La montée en niveau a réussi : pièces débitées, niveau mis à jour.
  success,

  /// Le joueur n'a pas assez de pièces.
  insufficientCoins,

  /// L'amélioration a déjà atteint son niveau maximum.
  maxLevelReached,
}

// ── Coûts de montée en niveau ────────────────────────────────────────────

/// Coût en pièces pour chaque niveau.
/// L'index correspond au `currentLevel` avant la montée :
///   niveau 0→1 (currentLevel 0) → 100 pièces
///   niveau 1→2 (currentLevel 1) → 250 pièces
const kUpgradeCosts = [100, 250];

// ── Service ──────────────────────────────────────────────────────────────

/// Vérifie et applique les déblocages d'améliorations selon les conditions
/// définies dans la table `upgrades`.
///
/// Utilisé après chaque partie ([QuestService.onGameEnd]) et après chaque
/// complétion de quête ([QuestService._handleCompletion]).
///
/// Montée en niveau (Story 2.6a) : [levelUpUpgrade] exécute une transaction
/// atomique qui débite les pièces et met à jour `currentLevel`.
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

  /// Monte l'amélioration [upgradeId] d'un niveau — Story 2.6a.
  ///
  /// Transaction atomique :
  /// 1. Vérifie que l'amélioration est débloquée et n'a pas atteint le max
  /// 2. Calcule le coût selon [kUpgradeCosts] (défini par niveau courant)
  /// 3. Vérifie que `player.coins >= cost`
  /// 4. Débite les pièces et incrémente `current_level`
  ///
  /// Retourne [UpgradeResult] selon l'issue.
  Future<UpgradeResult> levelUpUpgrade(String upgradeId) async {
    final db = _ref.read(appDatabaseProvider);

    final upgrade = await (db.select(db.upgrades)
          ..where((u) => u.id.equals(upgradeId)))
        .getSingleOrNull();

    if (upgrade == null || !upgrade.isUnlocked) {
      return UpgradeResult.maxLevelReached;
    }
    if (upgrade.currentLevel >= kUpgradeCosts.length) {
      return UpgradeResult.maxLevelReached;
    }

    final cost = kUpgradeCosts[upgrade.currentLevel];

    return db.transaction<UpgradeResult>(() async {
      final enough = await spendCoins(db, cost);
      if (!enough) return UpgradeResult.insufficientCoins;

      await (db.update(db.upgrades)..where((u) => u.id.equals(upgradeId)))
          .write(UpgradesCompanion(
        currentLevel: Value(upgrade.currentLevel + 1),
      ));

      return UpgradeResult.success;
    });
  }
}
