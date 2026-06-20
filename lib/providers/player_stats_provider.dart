/// Statistiques joueur persistées — Story 2.2b.
///
/// Met à jour `player_stats.total_coins_earned` (cumul, jamais remis à
/// zéro) et `player_stats.best_score` (meilleur score, score = pièces
/// gagnées dans une partie) en fin de partie.
library;

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';

Future<void> _ensureStatsExist(AppDatabase db) async {
  final existing =
      await (db.select(db.playerStats)..where((t) => t.id.equals(1)))
          .getSingleOrNull();
  if (existing == null) {
    await db.into(db.playerStats).insert(
          PlayerStatsCompanion(id: const Value(1), maxBiomeSizes: const Value('{}')),
        );
  }
}

/// Enregistre la fin d'une partie : ajoute [coinsEarned] au cumul total,
/// incrémente le nombre de parties jouées, et met à jour [bestScore] si
/// dépassé.
Future<void> recordGameEnd(
  AppDatabase db, {
  required int coinsEarned,
  required int score,
}) async {
  await _ensureStatsExist(db);
  final table = db.playerStats;
  final current =
      await (db.select(table)..where((t) => t.id.equals(1))).getSingle();

  await (db.update(table)..where((t) => t.id.equals(1))).write(
    PlayerStatsCompanion.custom(
      totalCoinsEarned: table.totalCoinsEarned + Variable(coinsEarned),
      totalGamesPlayed: table.totalGamesPlayed + const Variable(1),
      bestScore: Variable(
        score > current.bestScore ? score : current.bestScore,
      ),
    ),
  );
}
