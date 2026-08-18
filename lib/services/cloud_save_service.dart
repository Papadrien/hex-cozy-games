/// Cloud save — Story 2.10a / 2.10b.
///
/// Sérialise la progression (pièces, améliorations débloquées, stats,
/// quêtes permanentes, quêtes journalières, dates de pièces quotidiennes)
/// en JSON et la synchronise via `games_services` (Google Play Games /
/// Game Center). La session active n'est pas incluse.
///
/// Sync déclenchée :
///   - au lancement de l'app (pull depuis le cloud)
///   - après chaque partie (push vers le cloud)
///
/// Résolution de conflits (2.10b) : last-write-wins. La progression la plus
/// récente gagne. La progression locale n'est jamais écrasée par une version
/// cloud plus ancienne (comparaison via timestamp partagé dans le payload).
///
/// Pas de compte = pas de sync, tout reste local.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';

const _logTag = '[CloudSave]';

class CloudSaveService {
  CloudSaveService(this._ref);
  final Ref _ref;

  static const _saveName = 'progression_v1';
  static const _prefsLastSyncKey = 'cloud_last_sync_timestamp';
  static const _prefsLastSyncTilesKey = 'cloud_last_sync_tiles';
  static const _prefsLastSyncCoinsKey = 'cloud_last_sync_coins';

  /// Charge la progression depuis le cloud et l'applique localement
  /// seulement si elle est plus récente que notre dernier timestamp de sync.
  /// En cas d'horloges désynchronisées (écart < 60 s), compare les
  /// métriques de progression (tiles, coins) pour départager.
  /// Tente une connexion Play Games silencieuse avant la sync.
  /// Silencieux si non connecté, refusé, ou en erreur (aucune UI bloquante).
  Future<void> syncOnLaunch() async {
    debugPrint('$_logTag syncOnLaunch: début');
    await _trySignIn();
    final signedIn = await _isSignedIn();
    debugPrint('$_logTag syncOnLaunch: connecté=$signedIn');
    if (!signedIn) return;
    final cloudData = await _loadFromCloud();
    if (cloudData == null) {
      debugPrint('$_logTag syncOnLaunch: aucune sauvegarde cloud trouvée');
      return;
    }

    final cloudTime =
        DateTime.tryParse(cloudData['lastUpdated'] as String? ?? '');
    if (cloudTime == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_prefsLastSyncKey);

    bool cloudIsNewer = true;
    if (lastSync != null) {
      final localTime = DateTime.tryParse(lastSync);
      if (localTime != null) {
        final diff = cloudTime.difference(localTime).inSeconds;
        if (diff > 60) {
          // Cloud plus récent d'au moins 60 s → gagne.
          cloudIsNewer = true;
        } else if (diff < -60) {
          // Local plus récent d'au moins 60 s → garde le local.
          cloudIsNewer = false;
        } else {
          // Horloges proches (écart < 60 s) → départage par progression.
          final cloudTiles =
              cloudData['totalTilesPlaced'] as int? ?? 0;
          final cloudCoins = cloudData['coins'] as int? ?? 0;
          final localTiles =
              prefs.getInt(_prefsLastSyncTilesKey) ?? 0;
          final localCoins =
              prefs.getInt(_prefsLastSyncCoinsKey) ?? 0;
          // La save avec le plus de progression gagne.
          final cloudScore = cloudTiles * 1000 + cloudCoins;
          final localScore = localTiles * 1000 + localCoins;
          cloudIsNewer = cloudScore >= localScore;
        }
      }
    }

    if (!cloudIsNewer) {
      debugPrint('$_logTag syncOnLaunch: local plus récent, cloud ignoré');
      return;
    }

    final db = _ref.read(appDatabaseProvider);
    await _applyToLocal(db, cloudData);
    await prefs.setString(_prefsLastSyncKey, cloudData['lastUpdated'] as String);
    await prefs.setInt(
        _prefsLastSyncTilesKey, cloudData['totalTilesPlaced'] as int? ?? 0);
    await prefs.setInt(
        _prefsLastSyncCoinsKey, cloudData['coins'] as int? ?? 0);
    debugPrint('$_logTag syncOnLaunch: données cloud appliquées localement');
  }

  /// Sérialise la progression locale et la pousse vers le cloud, puis
  /// met à jour le timestamp local de dernière sync.
  /// Silencieux si non connecté ou en erreur.
  Future<void> syncAfterGame() async {
    final signedIn = await _isSignedIn();
    debugPrint('$_logTag syncAfterGame: connecté=$signedIn');
    if (!signedIn) return;
    final db = _ref.read(appDatabaseProvider);
    final data = await _serialize(db);
    await _saveToCloud(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsLastSyncKey,
      data['lastUpdated'] as String,
    );
    await prefs.setInt(
        _prefsLastSyncTilesKey, data['totalTilesPlaced'] as int? ?? 0);
    await prefs.setInt(
        _prefsLastSyncCoinsKey, data['coins'] as int? ?? 0);
    debugPrint('$_logTag syncAfterGame: poussé vers le cloud');
  }

  Future<bool> _isSignedIn() async {
    try {
      return await GamesServices.isSignedIn;
    } catch (e) {
      debugPrint('$_logTag _isSignedIn: erreur $e');
      return false;
    }
  }

  /// Déclenche la connexion Play Games (Android) / Game Center (iOS).
  /// Si le joueur est déjà connecté au niveau OS, ceci est silencieux
  /// (pas de popup). Si un compte doit être choisi/autorisé, l'OS affiche
  /// sa propre UI native de consentement.
  /// Aucune exception ne remonte : un échec ou un refus laisse simplement
  /// l'app en mode "non connecté" (cloud save désactivé, tout reste local).
  Future<void> _trySignIn() async {
    try {
      await GamesServices.signIn();
      debugPrint('$_logTag _trySignIn: signIn() terminé sans exception');
    } catch (e, st) {
      debugPrint('$_logTag _trySignIn: échec — $e');
      debugPrint('$_logTag _trySignIn: stack — $st');
    }
  }

  Future<Map<String, dynamic>?> _loadFromCloud() async {
    try {
      final raw = await SaveGame.loadGame(name: _saveName);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('$_logTag _loadFromCloud: erreur $e');
      return null;
    }
  }

  Future<void> _saveToCloud(Map<String, dynamic> data) async {
    try {
      await SaveGame.saveGame(
        name: _saveName,
        data: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('$_logTag _saveToCloud: erreur $e');
    }
  }

  Future<Map<String, dynamic>> _serialize(AppDatabase db) async {
    final profile = await (db.select(db.playerProfile)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    final upgrades = await db.select(db.upgrades).get();
    final stats = await (db.select(db.playerStats)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    final permanentQuests = await db.select(db.permanentQuests).get();
    final dailyQuests = await (db.select(db.dailyQuests)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();

    final unlockedUpgrades = <String, int>{};
    for (final u in upgrades) {
      if (u.isUnlocked) {
        unlockedUpgrades[u.id] = u.currentLevel;
      }
    }

    // Seuls les champs mutables sont synchronisés : les quêtes permanentes
    // elles-mêmes (description, palier, récompense, chaînage) sont
    // pré-seedées localement et identiques sur tous les appareils.
    final permanentQuestsState = <String, dynamic>{
      for (final q in permanentQuests)
        q.id: {
          'currentValue': q.currentValue,
          'isCompleted': q.isCompleted,
          'rewardClaimed': q.rewardClaimed,
        },
    };

    return {
      'version': 1,
      'lastUpdated': DateTime.now().toUtc().toIso8601String(),
      'coins': profile?.coins ?? 0,
      'totalTilesPlaced': profile?.totalTilesPlaced ?? 0,
      'isPremium': profile?.isPremium ?? false,
      'lastDailyRewardDate':
          profile?.lastDailyRewardDate?.toUtc().toIso8601String(),
      'lastPremiumDailyCoinsDate':
          profile?.lastPremiumDailyCoinsDate?.toUtc().toIso8601String(),
      'unlockedUpgrades': unlockedUpgrades,
      'permanentQuestsState': permanentQuestsState,
      if (dailyQuests != null)
        'dailyQuests': {
          'date': dailyQuests.date.toUtc().toIso8601String(),
          'questPoolIds': dailyQuests.questPoolIds,
          'completedIds': dailyQuests.completedIds,
          'progressByQuestId': dailyQuests.progressByQuestId,
          'rewardClaimedIds': dailyQuests.rewardClaimedIds,
        },
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

    // Player profile — pièces, tuiles, premium, et dates de pièces
    // quotidiennes (bouton pub + bonus premium) en un seul écrit.
    // Champs de date nullable : on applique explicitement `null` si absent
    // du payload cloud, pour ne pas garder une ancienne date locale
    // incohérente avec un profil cloud qui n'a jamais réclamé la pièce.
    await db.into(db.playerProfile).insertOnConflictUpdate(
          PlayerProfileCompanion(
            id: const Value(1),
            coins: Value(data['coins'] as int? ?? 0),
            totalTilesPlaced: Value(data['totalTilesPlaced'] as int? ?? 0),
            isPremium: Value(data['isPremium'] as bool? ?? false),
            lastDailyRewardDate: Value(
              DateTime.tryParse(
                  data['lastDailyRewardDate'] as String? ?? ''),
            ),
            lastPremiumDailyCoinsDate: Value(
              DateTime.tryParse(
                  data['lastPremiumDailyCoinsDate'] as String? ?? ''),
            ),
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

    // Quêtes permanentes : on applique uniquement l'état mutable
    // (progression / complétion / réclamation) sur les quêtes déjà
    // pré-seedées localement, par id.
    final permanentQuestsState =
        data['permanentQuestsState'] as Map<String, dynamic>? ?? {};
    for (final entry in permanentQuestsState.entries) {
      final questState = entry.value as Map<String, dynamic>;
      await (db.update(db.permanentQuests)
            ..where((t) => t.id.equals(entry.key)))
          .write(
        PermanentQuestsCompanion(
          currentValue: Value(questState['currentValue'] as int? ?? 0),
          isCompleted: Value(questState['isCompleted'] as bool? ?? false),
          rewardClaimed:
              Value(questState['rewardClaimed'] as bool? ?? false),
        ),
      );
    }

    // Quêtes journalières : on applique le lot cloud uniquement s'il
    // correspond au jour courant sur cet appareil. Si le cloud vient d'un
    // autre jour (device pas encore ouvert aujourd'hui, décalage horaire),
    // on laisse `_ensureDailyQuestsExist` tirer un nouveau lot local :
    // appliquer un lot d'un autre jour serait immédiatement écrasé par ce
    // mécanisme et ferait perdre la progression locale du jour en cours.
    final dailyQuestsData = data['dailyQuests'] as Map<String, dynamic>?;
    if (dailyQuestsData != null) {
      final cloudDate =
          DateTime.tryParse(dailyQuestsData['date'] as String? ?? '');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (cloudDate != null && _isSameLocalDay(cloudDate.toLocal(), today)) {
        await db.into(db.dailyQuests).insertOnConflictUpdate(
              DailyQuestsCompanion(
                id: const Value(1),
                date: Value(today),
                questPoolIds: Value(
                    dailyQuestsData['questPoolIds'] as String? ?? '[]'),
                completedIds: Value(
                    dailyQuestsData['completedIds'] as String? ?? '[]'),
                progressByQuestId: Value(
                    dailyQuestsData['progressByQuestId'] as String? ?? '{}'),
                rewardClaimedIds: Value(
                    dailyQuestsData['rewardClaimedIds'] as String? ?? '[]'),
              ),
            );
      }
    }
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

final cloudSaveServiceProvider = Provider<CloudSaveService>((ref) {
  return CloudSaveService(ref);
});
