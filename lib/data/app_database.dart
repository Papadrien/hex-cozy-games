import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Table minimale de validation du setup Drift.
///
/// Les vraies tables (`Player`, `Upgrade`, `Quest`, `DailyQuest`,
/// `GameSession`, `PlayerStats` — voir 01_contexte_architecture.md
/// section 8.3) seront ajoutées au fil des stories de la Phase 2.
@DataClassName('SetupCheckRow')
class SetupCheck extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
}

@DriftDatabase(tables: [SetupCheck])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'hex_cozy_games');
  }
}
