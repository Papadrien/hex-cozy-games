/// Tests pour la montée en niveau des améliorations — Story 2.6a.
///
/// Vérifie :
///  - [spendCoins] retourne false si solde insuffisant
///  - [spendCoins] débite correctement si solde suffisant
///  - [ProgressionService.levelUpUpgrade] réussit et met à jour le niveau
///  - [ProgressionService.levelUpUpgrade] retourne insufficientCoins
///  - [ProgressionService.levelUpUpgrade] retourne maxLevelReached
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_cozy_games/data/app_database.dart';
import 'package:hex_cozy_games/data/seed_data.dart';
import 'package:hex_cozy_games/providers/player_profile_provider.dart';
import 'package:hex_cozy_games/providers/progression_provider.dart';

/// Installe une base mémoire, seed les données, et retourne un
/// [ProviderContainer] prêt à l'emploi.
///
/// Retourne `null` si sqlite3 natif n'est pas disponible.
Future<ProviderContainer?> _makeTestContainer() async {
  try {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDatabase(db);
    await db.into(db.playerProfile).insert(
          const PlayerProfileCompanion(id: Value(1)),
        );
    return ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  } catch (_) {
    return null;
  }
}

void main() {
  group('kUpgradeCosts', () {
    test('contient 2 paliers de coût', () {
      expect(kUpgradeCosts, [100, 250]);
    });
  });

  group('UpgradeResult', () {
    test('a 3 états', () {
      expect(UpgradeResult.values.length, 3);
    });
  });

  group('spendCoins', () {
    late AppDatabase db;
    setUp(() async {
      db = (await _makeTestContainer())!.read(appDatabaseProvider);
    });

    test('retourne false si solde insuffisant', () async {
      final ok = await spendCoins(db, 1);
      expect(ok, isFalse);
    });

    test('retourne true et débite si solde suffisant', () async {
      await addCoinsToProfile(db, 100);
      final ok = await spendCoins(db, 40);
      expect(ok, isTrue);

      final profile =
          await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
              .getSingle();
      expect(profile.coins, 60);
    });

    test('laisse le solde inchangé si insuffisant', () async {
      await addCoinsToProfile(db, 10);
      final ok = await spendCoins(db, 20);
      expect(ok, isFalse);

      final profile =
          await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
              .getSingle();
      expect(profile.coins, 10);
    });
  });

  group('levelUpUpgrade', () {
    late AppDatabase db;
    late ProgressionService service;

    setUp(() async {
      final c = (await _makeTestContainer())!;
      db = c.read(appDatabaseProvider);
      service = c.read(progressionServiceProvider);
    });

    test('retourne maxLevelReached si currentLevel 2', () async {
      await _setUpgrade(db, 'coins_plus', isUnlocked: true, level: 2);
      expect(await service.levelUpUpgrade('coins_plus'),
          UpgradeResult.maxLevelReached);
    });

    test('retourne maxLevelReached si currentLevel 3', () async {
      await _setUpgrade(db, 'coins_plus', isUnlocked: true, level: 3);
      expect(await service.levelUpUpgrade('coins_plus'),
          UpgradeResult.maxLevelReached);
    });

    test('retourne maxLevelReached si ID inconnue', () async {
      expect(await service.levelUpUpgrade('unknown_id'),
          UpgradeResult.maxLevelReached);
    });

    test('retourne maxLevelReached si non débloquée', () async {
      expect(await service.levelUpUpgrade('coins_plus'),
          UpgradeResult.maxLevelReached);
    });

    test('retourne insufficientCoins si pas assez de pièces', () async {
      await _setUpgrade(db, 'coins_plus', isUnlocked: true, level: 0);
      expect(await service.levelUpUpgrade('coins_plus'),
          UpgradeResult.insufficientCoins);
    });

    test('réussit et met à jour niveau + débite les pièces', () async {
      await addCoinsToProfile(db, 200);
      await _setUpgrade(db, 'coins_plus', isUnlocked: true, level: 0);

      expect(await service.levelUpUpgrade('coins_plus'),
          UpgradeResult.success);

      expect((await _getUpgrade(db, 'coins_plus')).currentLevel, 1);
      expect((await _getProfile(db)).coins, 100);
    });

    test('deux montées successives 0→1→2', () async {
      await addCoinsToProfile(db, 500);
      await _setUpgrade(db, 'coins_plus', isUnlocked: true, level: 0);

      expect(await service.levelUpUpgrade('coins_plus'),
          UpgradeResult.success);
      expect((await _getUpgrade(db, 'coins_plus')).currentLevel, 1);

      expect(await service.levelUpUpgrade('coins_plus'),
          UpgradeResult.success);
      expect((await _getUpgrade(db, 'coins_plus')).currentLevel, 2);

      expect((await _getProfile(db)).coins, 150);
    });

    test('troisième montée échoue (maxLevelReached)', () async {
      await addCoinsToProfile(db, 1000);
      await _setUpgrade(db, 'coins_plus', isUnlocked: true, level: 0);

      await service.levelUpUpgrade('coins_plus');
      await service.levelUpUpgrade('coins_plus');

      expect(await service.levelUpUpgrade('coins_plus'),
          UpgradeResult.maxLevelReached);
      expect((await _getUpgrade(db, 'coins_plus')).currentLevel, 2);
    });
  });
}

Future<void> _setUpgrade(
  AppDatabase db,
  String id, {
  required bool isUnlocked,
  required int level,
}) async {
  await (db.update(db.upgrades)..where((u) => u.id.equals(id))).write(
    UpgradesCompanion(
      isUnlocked: Value(isUnlocked),
      currentLevel: Value(level),
    ),
  );
}

Future<UpgradeRow> _getUpgrade(AppDatabase db, String id) async {
  return (db.select(db.upgrades)..where((u) => u.id.equals(id))).getSingle();
}

Future<PlayerProfileRow> _getProfile(AppDatabase db) async {
  return (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
      .getSingle();
}
