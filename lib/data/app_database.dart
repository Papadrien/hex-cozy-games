import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'seed_data.dart';

part 'app_database.g.dart';

/// Table minimale de validation du setup Drift.
@DataClassName('SetupCheckRow')
class SetupCheck extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
}

/// Session de jeu persistée après chaque placement — Story 1.7a.
///
/// Contient tout l'état nécessaire pour restaurer fidèlement une partie
/// interrompue.
@DataClassName('GameSessionRow')
class GameSession extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get gridState => text()();       // JSON du plateau (Map<HexCoords, HexTile>)
  TextColumn get tileStack => text()();       // JSON de la pile restante (_queue + remaining)
  IntColumn get coins => integer()();
  IntColumn get totalBonusTiles => integer()();
  TextColumn get lastTilePlaced => text().nullable()(); // JSON du dernier placement (annuler)
  IntColumn get placedTilesCount => integer()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Profil joueur global — Story 2.1a.
@DataClassName('PlayerProfileRow')
class PlayerProfile extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get coins => integer().withDefault(const Constant(0))();
  IntColumn get totalTilesPlaced => integer().withDefault(const Constant(0))();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastDailyRewardDate => dateTime().nullable()();
}

/// Améliorations achetables/débloquables — Story 2.1a.
@DataClassName('UpgradeRow')
class Upgrades extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get effectType => text()();
  BoolColumn get isUnlocked => boolean().withDefault(const Constant(false))();
  IntColumn get currentLevel => integer().withDefault(const Constant(0))(); // 0–3
  TextColumn get unlockConditionType => text()();
  IntColumn get unlockConditionValue => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Quêtes permanentes (chaîne de progression) — Story 2.1a.
@DataClassName('PermanentQuestRow')
class PermanentQuests extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  IntColumn get targetValue => integer()();
  IntColumn get currentValue => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get rewardType => text()();
  IntColumn get rewardValue => integer()();
  TextColumn get nextQuestId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Quêtes journalières — Story 2.1a.
@DataClassName('DailyQuestRow')
class DailyQuests extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get questPoolIds => text()();        // JSON List<String>
  TextColumn get completedIds => text()();         // JSON List<String>
  TextColumn get progressByQuestId => text()();    // JSON Map<String, int>
}

/// Session de jeu méta (Phase 2) — Story 2.1a.
///
/// Distincte de [GameSession] (Phase 1) : ajoute les améliorations
/// sélectionnées et les compteurs de run pour le méta-game.
@DataClassName('MetaGameSessionRow')
class GameSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get tilesRemaining => integer()();
  TextColumn get selectedUpgradeIds => text()();   // JSON List<String>
  IntColumn get coinsEarned => integer().withDefault(const Constant(0))();
  IntColumn get tilesPlaced => integer().withDefault(const Constant(0))();
  TextColumn get gridState => text()();
  TextColumn get tileStack => text()();
  TextColumn get lastTilePlaced => text().nullable()();
  IntColumn get seed => integer()();
}

/// Statistiques cumulées du joueur — Story 2.1a.
@DataClassName('PlayerStatsRow')
class PlayerStats extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get totalTilesPlaced => integer().withDefault(const Constant(0))();
  IntColumn get totalGamesPlayed => integer().withDefault(const Constant(0))();
  IntColumn get totalCoinsEarned => integer().withDefault(const Constant(0))();
  IntColumn get bestScore => integer().withDefault(const Constant(0))();
  TextColumn get maxBiomeSizes => text()(); // JSON Map<String, int>
}

@DriftDatabase(tables: [
  SetupCheck,
  GameSession,
  PlayerProfile,
  Upgrades,
  PermanentQuests,
  DailyQuests,
  GameSessions,
  PlayerStats,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await seedDatabase(this);
      },
      onUpgrade: (m, from, to) async {
        if (from == 1) {
          await m.createTable(gameSession);
        }
        if (from < 3) {
          await m.createTable(playerProfile);
          await m.createTable(upgrades);
          await m.createTable(permanentQuests);
          await m.createTable(dailyQuests);
          await m.createTable(gameSessions);
          await m.createTable(playerStats);
          await seedDatabase(this);
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'hex_cozy_games');
  }
}

/// Provider Riverpod pour l'accès à la base de données Drift.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
