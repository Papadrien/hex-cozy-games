/// Profil joueur persisté — Story 2.2b.
///
/// Expose le solde de pièces totales (`player_profile.coins`), distinct
/// des pièces de session ([sessionCoinsProvider]). La ligne id=1 est créée
/// à la première lecture si elle n'existe pas encore (DB pré-2.2b).
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';

/// Watch en continu du profil joueur (ligne unique id=1).
final playerProfileProvider =
    StreamProvider<PlayerProfileRow>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  await _ensureProfileExists(db);
  yield* (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
      .watchSingle();
});

/// Pièces totales détenues — projection simple pour l'UI (accueil/menus).
final totalCoinsProvider = Provider<int>((ref) {
  return ref.watch(playerProfileProvider).maybeWhen(
        data: (row) => row.coins,
        orElse: () => 0,
      );
});

Future<void> _ensureProfileExists(AppDatabase db) async {
  final existing =
      await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
          .getSingleOrNull();
  if (existing == null) {
    await db.into(db.playerProfile).insert(
          const PlayerProfileCompanion(id: Value(1)),
        );
  }
}

/// Ajoute [coins] au solde persisté du joueur (fin de partie — Story 2.2b).
///
/// Incrément atomique via expression SQL (`coins = coins + ?`) pour éviter
/// une lecture-modification-écriture non protégée.
Future<void> addCoinsToProfile(AppDatabase db, int coins) async {
  await _ensureProfileExists(db);
  final table = db.playerProfile;
  await (db.update(table)..where((t) => t.id.equals(1))).write(
    PlayerProfileCompanion.custom(
      coins: table.coins + Variable(coins),
    ),
  );
}

/// Incrémente le compteur global de tuiles posées (Story 2.5a).
///
/// Utilisé pour la condition de déblocage `TILES_PLACED` dans
/// [ProgressionService].
Future<void> incrementTotalTilesPlaced(AppDatabase db) async {
  await _ensureProfileExists(db);
  final table = db.playerProfile;
  await (db.update(table)..where((t) => t.id.equals(1))).write(
    PlayerProfileCompanion.custom(
      totalTilesPlaced: table.totalTilesPlaced + const Variable(1),
    ),
  );
}

/// Met à jour la date du dernier reward quotidien (Story 3.2a).
Future<void> updateLastDailyRewardDate(AppDatabase db) async {
  await _ensureProfileExists(db);
  await (db.update(db.playerProfile)..where((t) => t.id.equals(1))).write(
    PlayerProfileCompanion(
      lastDailyRewardDate: Value(DateTime.now()),
    ),
  );
}

/// Persiste le statut premium du joueur — Story 3.5a.
Future<void> setPremiumStatus(AppDatabase db, bool premium) async {
  await _ensureProfileExists(db);
  await (db.update(db.playerProfile)..where((t) => t.id.equals(1))).write(
    PlayerProfileCompanion(isPremium: Value(premium)),
  );
}

/// Débite [amount] pièces du solde persisté — Story 2.6a.
///
/// Retourne `false` si le solde est insuffisant, `true` si le débit a
/// été effectué. L'appelant doit idéalement encapsuler cette opération
/// dans une transaction Drift pour garantir l'atomicité avec d'autres
/// écritures (ex: montée en niveau).
Future<bool> spendCoins(AppDatabase db, int amount) async {
  await _ensureProfileExists(db);
  final profile =
      await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
          .getSingleOrNull();
  if (profile == null || profile.coins < amount) return false;

  final table = db.playerProfile;
  await (db.update(table)..where((t) => t.id.equals(1))).write(
    PlayerProfileCompanion.custom(
      coins: table.coins - Variable(amount),
    ),
  );
  return true;
}
