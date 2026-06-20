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
