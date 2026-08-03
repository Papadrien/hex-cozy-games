import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'seed_data.dart';

part 'app_database.g.dart';

/// Session de jeu persistée après chaque placement — Story 1.7a.
///
/// Contient tout l'état nécessaire pour restaurer fidèlement une partie
/// interrompue.
@DataClassName('ActiveBoardSessionRow')
class ActiveBoardSession extends Table {
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
  DateTimeColumn get lastPremiumDailyCoinsDate => dateTime().nullable()();
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
  // Quête répétable (ex: connexions) — se remet à zéro instantanément après
  // obtention de la récompense, en conservant le même palier (targetValue).
  BoolColumn get isRepeatable => boolean().withDefault(const Constant(false))();
  // Une quête complétée (isCompleted == true) n'octroie pas sa récompense
  // automatiquement : elle reste en attente (point rouge dans l'UI) tant
  // que le joueur n'a pas tapé dessus pour la réclamer.
  BoolColumn get rewardClaimed => boolean().withDefault(const Constant(false))();

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
  TextColumn get rewardClaimedIds =>
      text().withDefault(const Constant('[]'))();   // JSON List<String>
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
  ActiveBoardSession,
  PlayerProfile,
  Upgrades,
  PermanentQuests,
  DailyQuests,
  PlayerStats,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructeur pour les tests — accepte un [QueryExecutor] personnalisé
  /// (ex: `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await seedDatabase(this);
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(
            playerProfile,
            playerProfile.lastPremiumDailyCoinsDate,
          );
        }
        if (from < 3) {
          await m.addColumn(permanentQuests, permanentQuests.rewardClaimed);
          // Les quêtes déjà marquées complétées avant cette version ont
          // déjà reçu leur récompense (ancien comportement automatique) :
          // on les marque comme réclamées pour ne pas réafficher un point
          // rouge ni permettre un double octroi.
          await customStatement(
            'UPDATE permanent_quests SET reward_claimed = 1 WHERE is_completed = 1',
          );
        }
        if (from < 4) {
          await m.addColumn(dailyQuests, dailyQuests.rewardClaimedIds);
          // Les quêtes quotidiennes déjà marquées complétées avant cette
          // version ont déjà reçu leur récompense (ancien comportement
          // automatique) : on les marque comme réclamées pour ne pas
          // réafficher un point rouge ni permettre un double octroi.
          await customStatement(
            'UPDATE daily_quests SET reward_claimed_ids = completed_ids',
          );
        }
        // MetaRunHistory table was removed — safe to ignore since
        // no users in production and DB is recreated on reinstall.
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'hex_haven');
  }
}

/// Provider Riverpod pour l'accès à la base de données Drift.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
