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
/// Distincte de [ActiveBoardSession] (Phase 1) : ajoute les améliorations
/// sélectionnées et les compteurs de run pour le méta-game.
@DataClassName('MetaRunHistoryRow')
class MetaRunHistory extends Table {
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
  ActiveBoardSession,
  PlayerProfile,
  Upgrades,
  PermanentQuests,
  DailyQuests,
  MetaRunHistory,
  PlayerStats,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructeur pour les tests — accepte un [QueryExecutor] personnalisé
  /// (ex: `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await seedDatabase(this);
      },
      onUpgrade: (m, from, to) async {
        if (from == 1) {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS game_session (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              grid_state TEXT NOT NULL,
              tile_stack TEXT NOT NULL,
              coins INTEGER NOT NULL,
              total_bonus_tiles INTEGER NOT NULL,
              last_tile_placed TEXT,
              placed_tiles_count INTEGER NOT NULL,
              is_active INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        }
        if (from < 3) {
          await m.createTable(playerProfile);
          await m.createTable(upgrades);
          await m.createTable(permanentQuests);
          await m.createTable(dailyQuests);
          await customStatement('''
            CREATE TABLE IF NOT EXISTS game_sessions (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              is_active INTEGER NOT NULL DEFAULT 1,
              tiles_remaining INTEGER NOT NULL,
              selected_upgrade_ids TEXT NOT NULL,
              coins_earned INTEGER NOT NULL DEFAULT 0,
              tiles_placed INTEGER NOT NULL DEFAULT 0,
              grid_state TEXT NOT NULL,
              tile_stack TEXT NOT NULL,
              last_tile_placed TEXT,
              seed INTEGER NOT NULL
            )
          ''');
          await m.createTable(playerStats);
          await seedDatabase(this);
        }
        if (from < 4) {
          await customStatement('ALTER TABLE game_session RENAME TO active_board_session');
          await customStatement('ALTER TABLE game_sessions RENAME TO meta_run_history');
        }
        if (from < 5) {
          await m.addColumn(permanentQuests, permanentQuests.isRepeatable);
          // Renomme la quête "village de 100 maisons" en "groupe rouge de
          // plus de 50 tuiles" pour les bases déjà seedées.
          await (update(permanentQuests)..where((q) => q.id.equals('village_100')))
              .write(const PermanentQuestsCompanion(
            description: Value('Faire un groupe rouge de plus de 50 tuiles'),
            targetValue: Value(51),
          ));
          // Ajoute les nouvelles quêtes répétables de connexions si absentes.
          await batch((b) => b.insertAll(
                permanentQuests,
                kConnectionQuests,
                mode: InsertMode.insertOrIgnore,
              ));
        }
        if (from < 6) {
          // Remplace la chaîne "tiles_placed" (poser des tuiles) par la
          // chaîne "coins_earned" (cumul de pièces gagnées), en conservant
          // la progression déjà acquise sur chaque palier.
          const renames = <String, (String, String, String?)>{
            'tiles_50': ('coins_50', 'Gagner 50 pièces au total', 'coins_100'),
            'tiles_100':
                ('coins_100', 'Gagner 100 pièces au total', 'coins_200'),
            'tiles_200':
                ('coins_200', 'Gagner 200 pièces au total', 'coins_300'),
            'tiles_300':
                ('coins_300', 'Gagner 300 pièces au total', 'coins_500'),
            'tiles_500': ('coins_500', 'Gagner 500 pièces au total', null),
          };
          for (final entry in renames.entries) {
            final (newId, description, nextId) = entry.value;
            await (update(permanentQuests)
                  ..where((q) => q.id.equals(entry.key)))
                .write(PermanentQuestsCompanion(
              id: Value(newId),
              category: const Value('coinsEarned'),
              description: Value(description),
              nextQuestId: Value(nextId),
            ));
          }
          // Ajoute la nouvelle quête record "best_game_coins_500" si absente.
          await batch((b) => b.insertAll(
                permanentQuests,
                [kBestGameCoinsQuest],
                mode: InsertMode.insertOrIgnore,
              ));
          // Met à jour les conditions de déblocage des améliorations liées
          // à l'ancienne chaîne "tiles_placed".
          await (update(upgrades)..where((u) => u.unlockConditionType.equals('tiles_200')))
              .write(const UpgradesCompanion(
            unlockConditionType: Value('coins_200'),
          ));
          await (update(upgrades)..where((u) => u.unlockConditionType.equals('tiles_300')))
              .write(const UpgradesCompanion(
            unlockConditionType: Value('coins_300'),
          ));
          // Ajoute la nouvelle amélioration "Jackpot+" si absente.
          await batch((b) => b.insertAll(
                upgrades,
                [kJackpotPlusUpgrade],
                mode: InsertMode.insertOrIgnore,
              ));
          // Les quêtes quotidiennes en cours référencent l'ancien pool
          // (tuiles posées) : on force un nouveau tirage avec le pool
          // "pièces gagnées" dès la prochaine lecture.
          await delete(dailyQuests).go();
        }
        if (from < 7) {
          // Multiplie par 10 les paliers de la chaîne "coins_earned"
          // (500/1000/2000/3000/5000 au lieu de 50/100/200/300/500).
          // Traité dans cet ordre précis (du dernier palier au premier)
          // pour éviter toute collision de clé primaire : le nouvel id
          // 'coins_500' entrerait sinon en conflit avec l'ancien id
          // 'coins_500' (palier 500) tant qu'il n'a pas encore été
          // renommé en 'coins_5000'.
          const renames = <String, (String, int, String, String?)>{
            'coins_500': (
              'coins_5000',
              5000,
              'Gagner 5000 pièces au total',
              null,
            ),
            'coins_300': (
              'coins_3000',
              3000,
              'Gagner 3000 pièces au total',
              'coins_5000',
            ),
            'coins_200': (
              'coins_2000',
              2000,
              'Gagner 2000 pièces au total',
              'coins_3000',
            ),
            'coins_100': (
              'coins_1000',
              1000,
              'Gagner 1000 pièces au total',
              'coins_2000',
            ),
            'coins_50': (
              'coins_500',
              500,
              'Gagner 500 pièces au total',
              'coins_1000',
            ),
          };
          for (final entry in renames.entries) {
            final (newId, target, description, nextId) = entry.value;
            await (update(permanentQuests)
                  ..where((q) => q.id.equals(entry.key)))
                .write(PermanentQuestsCompanion(
              id: Value(newId),
              targetValue: Value(target),
              description: Value(description),
              nextQuestId: Value(nextId),
            ));
          }
          // Met à jour les conditions de déblocage des améliorations liées.
          await (update(upgrades)..where((u) => u.unlockConditionType.equals('coins_200')))
              .write(const UpgradesCompanion(
            unlockConditionType: Value('coins_2000'),
            unlockConditionValue: Value(2000),
          ));
          await (update(upgrades)..where((u) => u.unlockConditionType.equals('coins_300')))
              .write(const UpgradesCompanion(
            unlockConditionType: Value('coins_3000'),
            unlockConditionValue: Value(3000),
          ));
        }
        if (from < 8) {
          // Renomme "Villages+" en "Rouge+" (l'id et l'effet ne changent
          // pas, seul le libellé affiché est mis à jour).
          await (update(upgrades)..where((u) => u.id.equals('villages_plus')))
              .write(const UpgradesCompanion(name: Value('Rouge+')));
        }
        if (from < 9) {
          // Stories A4 + A5 : quêtes record "cluster couleur"
          // (forêt/eau/plaine/montagne) et améliorations associées
          // (Vert+/Bleu+/Jaune+/Violet+). insertOrIgnore : n'ajoute rien si
          // déjà présent (idempotent, comme les autres migrations).
          await batch((b) => b.insertAll(
                permanentQuests,
                kClusterColorQuests,
                mode: InsertMode.insertOrIgnore,
              ));
          await batch((b) => b.insertAll(
                upgrades,
                kClusterColorUpgrades,
                mode: InsertMode.insertOrIgnore,
              ));
        }
        if (from < 11) {
          // Debug uniquement : améliorations Millionnaire et Entrepôt de
          // tuiles, déblocables uniquement via le bouton "Tout débloquer"
          // (`unlockConditionType: 'debug_only'`). insertOrIgnore idempotent.
          await batch((b) => b.insertAll(
                upgrades,
                [kMillionaireUpgrade, kWarehouseUpgrade],
                mode: InsertMode.insertOrIgnore,
              ));
        }
        if (from < 10) {
          // Story A12 — migration unique regroupant les Stories A6 à A11
          // (nouvelles améliorations "upgrades" : extension de la chaîne
          // biomes_closed, quêtes one-shot connexions, catégorie/quête
          // best_streak_10, et toutes les améliorations de déblocage
          // associées). insertOrIgnore partout : idempotent, comme les
          // autres migrations.

          // Story A6 : extension de la chaîne "biomes_closed" avec
          // biomes_50 (débloque Bonus de clôture) et biomes_100 (débloque
          // Couleur détestée). Rattache biomes_25 -> biomes_50 pour les
          // bases déjà seedées (nextQuestId absent jusqu'ici).
          await (update(permanentQuests)..where((q) => q.id.equals('biomes_25')))
              .write(const PermanentQuestsCompanion(
            nextQuestId: Value('biomes_50'),
          ));
          await batch((b) => b.insertAll(
                permanentQuests,
                kBiomesClosedExtensionQuests,
                mode: InsertMode.insertOrIgnore,
              ));

          // Story A7 : améliorations liées à l'extension "biomes_closed"
          // (Bonus de clôture, Couleur détestée) — déblocage uniquement.
          await batch((b) => b.insertAll(
                upgrades,
                kBiomesClosedExtensionUpgrades,
                mode: InsertMode.insertOrIgnore,
              ));

          // Story A8 : quêtes one-shot de connexions multiples
          // (débloquent Aperçu prolongé / Emplacement Joker / Deuxième
          // chance en Story A9).
          await batch((b) => b.insertAll(
                permanentQuests,
                kOneShotConnectionQuests,
                mode: InsertMode.insertOrIgnore,
              ));

          // Story A9 : améliorations liées aux quêtes one-shot de
          // connexions (Aperçu prolongé, Emplacement Joker, Deuxième
          // chance) — déblocage uniquement.
          await batch((b) => b.insertAll(
                upgrades,
                kExtendedActionsUpgrades,
                mode: InsertMode.insertOrIgnore,
              ));

          // Story A10 : nouvelle catégorie "bestConnectionStreak" et sa
          // quête record (débloque Combo+ en Story A11).
          await batch((b) => b.insertAll(
                permanentQuests,
                [kBestConnectionStreakQuest],
                mode: InsertMode.insertOrIgnore,
              ));

          // Story A11 : amélioration Combo+ (déblocage uniquement).
          await batch((b) => b.insertAll(
                upgrades,
                [kComboPlusUpgrade],
                mode: InsertMode.insertOrIgnore,
              ));
        }
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
