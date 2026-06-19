import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

@DriftDatabase(tables: [SetupCheck, GameSession])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from == 1) {
          await m.createTable(gameSession);
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
