/// Cloud save — Story 2.10a.
///
/// Sérialise la progression (pièces, améliorations débloquées, stats) en JSON
/// et la synchronise via `games_services` (Google Play Games / Game Center).
/// La session active n'est pas incluse.
///
/// Sync déclenchée :
///   - au lancement de l'app (pull depuis le cloud)
///   - après chaque partie (push vers le cloud)
///
/// Pas de compte = pas de sync, tout reste local.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:games_services/games_services.dart';

import '../data/app_database.dart';

class CloudSaveService {
  CloudSaveService(this._ref);
  final Ref _ref;

  static const _saveName = 'progression_v1';

  /// Charge la progression depuis le cloud et l'applique localement.
  /// Silencieux si non connecté ou en erreur.
  Future<void> syncOnLaunch() async {
    if (!await _isSignedIn()) return;
    final cloudData = await _loadFromCloud();
    if (cloudData == null) return;
    final db = _ref.read(appDatabaseProvider);
    await _applyToLocal(db, cloudData);
  }

  /// Sérialise la progression locale et la pousse vers le cloud.
  /// Silencieux si non connecté ou en erreur.
  Future<void> syncAfterGame() async {
    if (!await _isSignedIn()) return;
    final db = _ref.read(appDatabaseProvider);
    final data = await _serialize(db);
    await _saveToCloud(data);
  }

  Future<bool> _isSignedIn() async {
    try {
      return await GamesServices.isSignedIn;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _loadFromCloud() async {
    try {
      final raw = await SaveGame.loadGame(name: _saveName);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToCloud(Map<String, dynamic> data) async {
    try {
      await SaveGame.saveGame(
        name: _saveName,
        data: jsonEncode(data),
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _serialize(AppDatabase db) async {
    final profile = await (db.select(db.playerProfile)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    final upgrades = await db.select(db.upgrades).get();
    final stats = await (db.select(db.playerStats)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();

    final unlockedUpgrades = <String, int>{};
    for (final u in upgrades) {
      if (u.isUnlocked) {
        unlockedUpgrades[u.id] = u.currentLevel;
      }
    }

    return {
      'version': 1,
      'lastUpdated': DateTime.now().toUtc().toIso8601String(),
      'coins': profile?.coins ?? 0,
      'totalTilesPlaced': profile?.totalTilesPlaced ?? 0,
      'isPremium': profile?.isPremium ?? false,
      'unlockedUpgrades': unlockedUpgrades,
      if (stats != null)
        'playerStats': {
          'totalTilesPlaced': stats.totalTilesPlaced,
          'totalGamesPlayed': stats.totalGamesPlayed,
          'totalCoinsEarned': stats.totalCoinsEarned,
          'bestScore': stats.bestScore,
          'maxBiomeSizes': stats.maxBiomeSizes,
        },
    };
  }

  Future<void> _applyToLocal(
    AppDatabase db,
    Map<String, dynamic> data,
  ) async {
    if (data['version'] != 1) return;
    final cloudTime =
        DateTime.tryParse(data['lastUpdated'] as String? ?? '');
    if (cloudTime == null) return;

    // Player profile
    await db.into(db.playerProfile).insertOnConflictUpdate(
          PlayerProfileCompanion(
            id: const Value(1),
            coins: Value(data['coins'] as int? ?? 0),
            totalTilesPlaced: Value(data['totalTilesPlaced'] as int? ?? 0),
            isPremium: Value(data['isPremium'] as bool? ?? false),
          ),
        );

    // Upgrades débloqués
    final unlocked = data['unlockedUpgrades'] as Map<String, dynamic>? ?? {};
    for (final entry in unlocked.entries) {
      await (db.update(db.upgrades)..where((t) => t.id.equals(entry.key)))
          .write(UpgradesCompanion(
        isUnlocked: const Value(true),
        currentLevel: Value(entry.value as int),
      ));
    }

    // Player stats
    final statsData = data['playerStats'] as Map<String, dynamic>?;
    if (statsData != null) {
      await db.into(db.playerStats).insertOnConflictUpdate(
            PlayerStatsCompanion(
              id: const Value(1),
              totalTilesPlaced:
                  Value(statsData['totalTilesPlaced'] as int? ?? 0),
              totalGamesPlayed:
                  Value(statsData['totalGamesPlayed'] as int? ?? 0),
              totalCoinsEarned:
                  Value(statsData['totalCoinsEarned'] as int? ?? 0),
              bestScore: Value(statsData['bestScore'] as int? ?? 0),
              maxBiomeSizes:
                  Value(statsData['maxBiomeSizes'] as String? ?? '{}'),
            ),
          );
    }
  }
}

final cloudSaveServiceProvider = Provider<CloudSaveService>((ref) {
  return CloudSaveService(ref);
});
