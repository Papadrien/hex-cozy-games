/// Tests pour le déblocage des améliorations
/// ([ProgressionService.checkUnlocks] et [ProgressionService.unlockAllUpgrades]).
///
/// Ces deux fonctions n'avaient aucun test avant ce fichier — en particulier
/// [unlockAllUpgrades] a été corrigée récemment (débloquait au niveau 3 au
/// lieu du niveau 1 attendu pour le bouton debug) sans qu'aucun test ne
/// protège cette logique contre une régression future.
///
/// Vérifie :
///  - [checkUnlocks] débloque une amélioration dont la quête permanente
///    liée est complétée
///  - [checkUnlocks] débloque une amélioration selon `tiles_placed` quand le
///    seuil est atteint, et ne la débloque pas sinon
///  - [checkUnlocks] ne débloque jamais une amélioration `debug_only`
///  - [checkUnlocks] ne touche pas aux améliorations déjà débloquées
///  - [unlockAllUpgrades] débloque TOUTES les améliorations (y compris
///    debug) et les place au niveau 1 (`currentLevel` = 0), pas au niveau 3
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/core/game_enums.dart';
import 'package:hex_haven/data/app_database.dart';
import 'package:hex_haven/data/seed_data.dart';
import 'package:hex_haven/providers/progression_provider.dart';

/// Installe une base mémoire, seed les données, et retourne un
/// [ProviderContainer] prêt à l'emploi.
///
/// Retourne `null` si sqlite3 natif n'est pas disponible sur cet
/// environnement (même garde que les autres tests de ce dossier).
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

Future<bool> _isUnlocked(AppDatabase db, String id) async {
  final row =
      await (db.select(db.upgrades)..where((u) => u.id.equals(id))).getSingle();
  return row.isUnlocked;
}

void main() {
  group('ProgressionService.checkUnlocks — condition quête', () {
    test('débloque une amélioration dont la quête liée est complétée',
        () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      // Amélioration verrouillée dont la condition est la quête 'coins_2000'
      // (voir seed_data.dart) — non complétée par défaut.
      expect(await _isUnlocked(db, 'starting_tiles_plus'), isFalse);

      await db.into(db.permanentQuests).insert(
            const PermanentQuestsCompanion.insert(
              id: 'coins_2000',
              category: 'coins',
              description: 'test',
              targetValue: 2000,
              rewardType: 'coins',
              rewardValue: 0,
              isCompleted: Value(true),
            ),
          );

      await container.read(progressionServiceProvider).checkUnlocks();

      expect(await _isUnlocked(db, 'starting_tiles_plus'), isTrue);
    });

    test('ne débloque pas si la quête liée n\'est pas complétée', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await db.into(db.permanentQuests).insert(
            const PermanentQuestsCompanion.insert(
              id: 'coins_2000',
              category: 'coins',
              description: 'test',
              targetValue: 2000,
              rewardType: 'coins',
              rewardValue: 0,
              isCompleted: Value(false),
            ),
          );

      await container.read(progressionServiceProvider).checkUnlocks();

      expect(await _isUnlocked(db, 'starting_tiles_plus'), isFalse);
    });

    test('sans quête correspondante en base, reste verrouillée (pas de crash)',
        () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await container.read(progressionServiceProvider).checkUnlocks();

      expect(await _isUnlocked(db, 'starting_tiles_plus'), isFalse);
    });
  });

  group('ProgressionService.checkUnlocks — condition tiles_placed', () {
    test('débloque quand le seuil de tuiles placées est atteint', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await db.into(db.upgrades).insert(
            UpgradesCompanion.insert(
              id: 'test_tiles_placed_upgrade',
              name: 'Test',
              effectType: UpgradeEffectType.startingTilesBonus.dbValue,
              unlockConditionType: 'tiles_placed',
              unlockConditionValue: 50,
            ),
          );
      await (db.update(db.playerProfile)..where((t) => t.id.equals(1)))
          .write(const PlayerProfileCompanion(totalTilesPlaced: Value(50)));

      await container.read(progressionServiceProvider).checkUnlocks();

      expect(await _isUnlocked(db, 'test_tiles_placed_upgrade'), isTrue);
    });

    test('ne débloque pas tant que le seuil n\'est pas atteint', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await db.into(db.upgrades).insert(
            UpgradesCompanion.insert(
              id: 'test_tiles_placed_upgrade',
              name: 'Test',
              effectType: UpgradeEffectType.startingTilesBonus.dbValue,
              unlockConditionType: 'tiles_placed',
              unlockConditionValue: 50,
            ),
          );
      await (db.update(db.playerProfile)..where((t) => t.id.equals(1)))
          .write(const PlayerProfileCompanion(totalTilesPlaced: Value(49)));

      await container.read(progressionServiceProvider).checkUnlocks();

      expect(await _isUnlocked(db, 'test_tiles_placed_upgrade'), isFalse);
    });
  });

  group('ProgressionService.checkUnlocks — debug_only', () {
    test('ne débloque jamais une amélioration debug_only', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      // 'millionaire' et 'warehouse' sont debug_only dans seed_data.dart —
      // même avec une quête du même nom complétée par coïncidence, elles ne
      // doivent jamais passer par checkUnlocks (unlockAllUpgrades reste
      // l'unique voie de déblocage).
      await container.read(progressionServiceProvider).checkUnlocks();

      expect(await _isUnlocked(db, 'millionaire'), isFalse);
      expect(await _isUnlocked(db, 'warehouse'), isFalse);
    });
  });

  group('ProgressionService.checkUnlocks — idempotence', () {
    test('ne modifie pas une amélioration déjà débloquée', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await (db.update(db.upgrades)..where((u) => u.id.equals('coins_plus')))
          .write(const UpgradesCompanion(
        isUnlocked: Value(true),
        currentLevel: Value(1),
      ));

      await container.read(progressionServiceProvider).checkUnlocks();

      final row = await (db.select(db.upgrades)
            ..where((u) => u.id.equals('coins_plus')))
          .getSingle();
      expect(row.isUnlocked, isTrue);
      expect(row.currentLevel, 1,
          reason: 'checkUnlocks ne doit pas toucher au niveau déjà atteint');
    });
  });

  group('ProgressionService.unlockAllUpgrades — debug', () {
    test('débloque absolument toutes les améliorations, y compris debug',
        () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await container.read(progressionServiceProvider).unlockAllUpgrades();

      final all = await db.select(db.upgrades).get();
      expect(all, isNotEmpty);
      expect(all.every((u) => u.isUnlocked), isTrue,
          reason: 'toutes les améliorations doivent être débloquées, '
              'y compris millionaire/warehouse (debug)');
    });

    test('place chaque amélioration au niveau 1 (currentLevel 0), pas au '
        'niveau 3', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      // Une amélioration déjà à un niveau avancé doit être ramenée à 0.
      await (db.update(db.upgrades)..where((u) => u.id.equals('coins_plus')))
          .write(const UpgradesCompanion(
        isUnlocked: Value(true),
        currentLevel: Value(2),
      ));

      await container.read(progressionServiceProvider).unlockAllUpgrades();

      final all = await db.select(db.upgrades).get();
      expect(
        all.every((u) => u.currentLevel == 0),
        isTrue,
        reason: 'régression : le bouton debug doit déverrouiller au '
            'niveau 1 (index 0), pas au niveau 3 (index 2)',
      );
    });
  });
}
