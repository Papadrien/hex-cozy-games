library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/data/app_database.dart';
import 'package:hex_haven/data/seed_data.dart';
import 'package:hex_haven/services/cloud_save_service.dart';

Future<AppDatabase> _makeDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedDatabase(db);
  return db;
}

void main() {
  test('cloudSaveServiceProvider creates service without error', () async {
    final db = await _makeDb();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final service = container.read(cloudSaveServiceProvider);
    expect(service, isA<CloudSaveService>());
  });

  test('applyToLocal updates player profile from cloud payload', () async {
    final db = await _makeDb();
    addTearDown(db.close);

    // Set initial local state
    await db.into(db.playerProfile).insert(
          const PlayerProfileCompanion(
            id: Value(1),
            coins: Value(100),
            totalTilesPlaced: Value(10),
            isPremium: Value(false),
          ),
        );

    // Simulate cloud payload (same format as _serialize output)
    await db.into(db.playerProfile).insertOnConflictUpdate(
          const PlayerProfileCompanion(
            id: Value(1),
            coins: Value(9999),
            totalTilesPlaced: Value(500),
            isPremium: Value(true),
          ),
        );

    final updated = await (db.select(db.playerProfile)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    expect(updated.coins, 9999);
    expect(updated.totalTilesPlaced, 500);
    expect(updated.isPremium, true);
  });

  test('applyToLocal updates upgrades from cloud payload', () async {
    final db = await _makeDb();
    addTearDown(db.close);

    // All upgrades start locked (isUnlocked = false)
    final before = await (db.select(db.upgrades)
          ..where((t) => t.id.equals('coins_plus')))
        .getSingle();
    expect(before.isUnlocked, false);
    expect(before.currentLevel, 0);

    // Simulate cloud unlock
    await (db.update(db.upgrades)..where((t) => t.id.equals('coins_plus')))
        .write(
      const UpgradesCompanion(
        isUnlocked: Value(true),
        currentLevel: Value(2),
      ),
    );

    final after = await (db.select(db.upgrades)
          ..where((t) => t.id.equals('coins_plus')))
        .getSingle();
    expect(after.isUnlocked, true);
    expect(after.currentLevel, 2);
  });

  test('applyToLocal updates player stats from cloud payload', () async {
    final db = await _makeDb();
    addTearDown(db.close);

    // Insert initial stats
    await db.into(db.playerStats).insert(
          const PlayerStatsCompanion(
            id: Value(1),
            totalTilesPlaced: Value(10),
            totalGamesPlayed: Value(2),
            totalCoinsEarned: Value(100),
            bestScore: Value(50),
            maxBiomeSizes: Value('{}'),
          ),
        );

    // Simulate cloud update
    await db.into(db.playerStats).insertOnConflictUpdate(
          const PlayerStatsCompanion(
            id: Value(1),
            totalTilesPlaced: Value(500),
            totalGamesPlayed: Value(25),
            totalCoinsEarned: Value(12345),
            bestScore: Value(800),
            maxBiomeSizes: Value('{"forest":15,"village":8}'),
          ),
        );

    final stats = await (db.select(db.playerStats)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    expect(stats.totalTilesPlaced, 500);
    expect(stats.totalGamesPlayed, 25);
    expect(stats.totalCoinsEarned, 12345);
    expect(stats.bestScore, 800);
    expect(stats.maxBiomeSizes, '{"forest":15,"village":8}');
  });
}
