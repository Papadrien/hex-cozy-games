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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_enums.dart';
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

/// Amélioration débloquée par la quête [questId] (`unlockConditionType ==
/// questId`), s'il y en a une — utilisé pour afficher son nom directement
/// sur la carte de la quête correspondante.
final upgradeForQuestProvider =
    Provider.family<UpgradeRow?, String>((ref, questId) {
  final all = ref.watch(upgradesProvider).maybeWhen(
        data: (list) => list,
        orElse: () => <UpgradeRow>[],
      );
  for (final upgrade in all) {
    if (upgrade.unlockConditionType == questId) return upgrade;
  }
  return null;
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
///   niveau 1→2 (currentLevel 0) → 5 000 pièces
///   niveau 2→3 (currentLevel 1) → 10 000 pièces
/// Total pour maxer une amélioration : 15 000 pièces (voir équilibrage
/// des packs de la boutique dans [kCoinPacks]).
const kUpgradeCosts = [5000, 10000];

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

  /// Parcourt les améliorations verrouillées à condition `tiles_placed`
  /// et les débloque si le seuil est atteint.
  ///
  /// Les améliorations à condition QUEST ne sont PAS traitées ici : elles
  /// sont débloquées individuellement via [checkUnlockForQuest], au moment
  /// où le joueur réclame la récompense de la quête correspondante — jamais
  /// en lot.
  Future<void> checkUnlocks() async {
    final db = _ref.read(appDatabaseProvider);

    final locked = await (db.select(db.upgrades)
          ..where((u) => u.isUnlocked.equals(false))
          ..where((u) => u.unlockConditionType.equals('tiles_placed')))
        .get();

    for (final upgrade in locked) {
      if (await _isTilesPlacedMet(upgrade, db)) {
        await db.update(db.upgrades).replace(
              upgrade.copyWith(isUnlocked: true),
            );
      }
    }
  }

  /// Débloque uniquement l'amélioration (s'il y en a une) dont
  /// `unlockConditionType == questId`, appelée exclusivement au claim
  /// manuel de la récompense d'une quête (Story : 1 quête réclamée = 1
  /// déblocage, jamais plusieurs d'un coup).
  Future<void> checkUnlockForQuest(String questId) async {
    final db = _ref.read(appDatabaseProvider);

    final locked = await (db.select(db.upgrades)
          ..where((u) => u.isUnlocked.equals(false))
          ..where((u) => u.unlockConditionType.equals(questId)))
        .get();

    for (final upgrade in locked) {
      await db.update(db.upgrades).replace(
            upgrade.copyWith(isUnlocked: true),
          );
    }
  }

  Future<bool> _isTilesPlacedMet(UpgradeRow upgrade, AppDatabase db) async {
    final profile =
        await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
            .getSingleOrNull();
    if (profile == null) return false;
    return profile.totalTilesPlaced >= upgrade.unlockConditionValue;
  }

  /// Force toutes les améliorations à être débloquées au niveau 1 — debug.
  ///
  /// Utile pour le développement : permet de tester toutes les améliorations
  /// sans avoir à remplir les conditions de déblocage.
  Future<void> unlockAllUpgrades() async {
    final db = _ref.read(appDatabaseProvider);
    await (db.update(db.upgrades)).write(
      const UpgradesCompanion(
        isUnlocked: Value(true),
        currentLevel: Value(0),
      ),
    );
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

// ── Helpers publics ───────────────────────────────────────────────────────

/// Icône représentant une amélioration selon son [effectType].
IconData upgradeIconData(UpgradeEffectType effectType) {
  switch (effectType) {
    case UpgradeEffectType.startingTilesBonus:
      return Icons.grid_on;
    case UpgradeEffectType.connectionBonusMultiplier:
      return Icons.auto_awesome;
    case UpgradeEffectType.coinsPercentBonus:
      return Icons.monetization_on;
    case UpgradeEffectType.villageCoinsPercentBonus:
    case UpgradeEffectType.forestCoinsPercentBonus:
    case UpgradeEffectType.waterCoinsPercentBonus:
    case UpgradeEffectType.plainCoinsPercentBonus:
    case UpgradeEffectType.mountainCoinsPercentBonus:
      return Icons.circle;
    case UpgradeEffectType.closureBonusTiles:
      return Icons.all_inclusive;
    case UpgradeEffectType.hatedColorExclusion:
      return Icons.block;
    case UpgradeEffectType.extendedPreviewCount:
      return Icons.visibility;
    case UpgradeEffectType.holdSlotUses:
      return Icons.swap_horiz;
    case UpgradeEffectType.secondChanceUses:
      return Icons.undo;
    case UpgradeEffectType.comboBonusTiles:
      return Icons.bolt;
    case UpgradeEffectType.millionaireCoins:
      return Icons.workspace_premium;
    case UpgradeEffectType.warehouseStartingTiles:
      return Icons.inventory_2;
  }
}

/// Couleur de teinte du rond pour les améliorations "couleur" (Rouge+,
/// Vert+, Bleu+, Jaune+, Violet+) — `null` pour les autres améliorations,
/// qui gardent l'icône neutre blanche du badge.
Color? upgradeIconColor(UpgradeEffectType effectType) {
  switch (effectType) {
    case UpgradeEffectType.villageCoinsPercentBonus:
      return const Color(0xFFE53935);
    case UpgradeEffectType.forestCoinsPercentBonus:
      return const Color(0xFF43A047);
    case UpgradeEffectType.waterCoinsPercentBonus:
      return const Color(0xFF1E88E5);
    case UpgradeEffectType.plainCoinsPercentBonus:
      return const Color(0xFFFFD600);
    case UpgradeEffectType.mountainCoinsPercentBonus:
      return const Color(0xFF8E24AA);
    default:
      return null;
  }
}

/// Effet textuel au niveau actuel de l'amélioration.
String upgradeEffectLabel(UpgradeRow upgrade) {
  final all = upgradeAllLevelEffects(UpgradeEffectType.fromDb(upgrade.effectType));
  final idx = upgrade.currentLevel < all.length
      ? upgrade.currentLevel
      : all.length - 1;
  return all[idx];
}

/// Effet textuel de chaque palier pour un [effectType] donné.
List<String> upgradeAllLevelEffects(UpgradeEffectType effectType) {
  switch (effectType) {
    case UpgradeEffectType.startingTilesBonus:
      return ['+2', '+5', '+10'];
    case UpgradeEffectType.connectionBonusMultiplier:
      return ['+1 tuile', '+2 tuiles', '+5 tuiles'];
    case UpgradeEffectType.coinsPercentBonus:
      // Bonus global (Pièces+, Jackpot+) : 1 pièce bonus si le joueur gagne
      // au moins N pièces sur la pose (non-cumulable — une seule pièce bonus
      // par pose, même si baseCoins >> seuil).
      return ['+1 dès 4 pièces', '+1 dès 2 pièces', '+1 dès 1 pièce'];
    case UpgradeEffectType.villageCoinsPercentBonus:
    case UpgradeEffectType.forestCoinsPercentBonus:
    case UpgradeEffectType.waterCoinsPercentBonus:
    case UpgradeEffectType.plainCoinsPercentBonus:
    case UpgradeEffectType.mountainCoinsPercentBonus:
      // Bonus par biome (Rouge+/Vert+/Bleu+/Jaune+/Violet+) : 1 pièce bonus si
      // au moins N côtés du biome sont connectés sur la pose (non-cumulable).
      return ['+1 dès 4 côtés', '+1 dès 2 côtés', '+1 dès 1 côté'];
    case UpgradeEffectType.closureBonusTiles:
      return ['+1/10 tuiles', '+2/10 tuiles', '+3/10 tuiles'];
    case UpgradeEffectType.hatedColorExclusion:
      return ['5 tuiles', '8 tuiles', '10 tuiles'];
    case UpgradeEffectType.extendedPreviewCount:
      return ['4 tuiles', '5 tuiles', '6 tuiles'];
    case UpgradeEffectType.holdSlotUses:
      return ['1 usage/partie', '2 usages/partie', '3 usages/partie'];
    case UpgradeEffectType.secondChanceUses:
      return ['1 usage/partie', '2 usages/partie', '3 usages/partie'];
    case UpgradeEffectType.comboBonusTiles:
      return ['Toutes les 10 tuiles', 'Toutes les 8 tuiles', 'Toutes les 5 tuiles'];
    case UpgradeEffectType.millionaireCoins:
      return ['1 000 000'];
    case UpgradeEffectType.warehouseStartingTiles:
      return ['500 tuiles'];
  }
}

/// Valeur numérique de l'effet au niveau [level] pour un [effectType].
double upgradeEffectValue(UpgradeEffectType effectType, int level) {
  switch (effectType) {
    case UpgradeEffectType.startingTilesBonus:
      return [2.0, 5.0, 10.0][level.clamp(0, 2)];
    case UpgradeEffectType.connectionBonusMultiplier:
      // Palier (1/2/3) transmis à `connectionBonusLevel`, traduit en tuiles
      // bonus supplémentaires (+1/+2/+5) par [GameEffectsService.applyBonusTileUpgrade].
      return [1.0, 2.0, 3.0][level.clamp(0, 2)];
    case UpgradeEffectType.coinsPercentBonus:
      // Seuil (en pièces de base) à partir duquel 1 pièce bonus est accordée.
      // Niveaux : 4 (≈ +25%) / 2 (≈ +50%) / 1 (≈ +100%, doublé quasi systématique).
      return [4.0, 2.0, 1.0][level.clamp(0, 2)];
    case UpgradeEffectType.villageCoinsPercentBonus:
    case UpgradeEffectType.forestCoinsPercentBonus:
    case UpgradeEffectType.waterCoinsPercentBonus:
    case UpgradeEffectType.plainCoinsPercentBonus:
    case UpgradeEffectType.mountainCoinsPercentBonus:
      // Seuil (en côtés du biome connectés sur la pose) à partir duquel 1
      // pièce bonus est accordée. Mêmes équivalences que le bonus global.
      return [4.0, 2.0, 1.0][level.clamp(0, 2)];
    case UpgradeEffectType.closureBonusTiles:
      return [1.0, 2.0, 3.0][level.clamp(0, 2)];
    case UpgradeEffectType.hatedColorExclusion:
      return [5.0, 8.0, 10.0][level.clamp(0, 2)];
    case UpgradeEffectType.extendedPreviewCount:
      return [4.0, 5.0, 6.0][level.clamp(0, 2)];
    case UpgradeEffectType.holdSlotUses:
      return [1.0, 2.0, 3.0][level.clamp(0, 2)];
    case UpgradeEffectType.secondChanceUses:
      return [1.0, 2.0, 3.0][level.clamp(0, 2)];
    case UpgradeEffectType.comboBonusTiles:
      // Représente désormais l'intervalle (en doubles connexions cumulées
      // sur la partie, plus besoin d'être d'affilée) entre deux octrois
      // d'une tuile bonus, et non plus le nombre de tuiles accordées
      // (toujours 1 désormais).
      return [10.0, 8.0, 5.0][level.clamp(0, 2)];
    case UpgradeEffectType.millionaireCoins:
      return [1000000.0][level.clamp(0, 0)];
    case UpgradeEffectType.warehouseStartingTiles:
      return [500.0][level.clamp(0, 0)];
  }
}
