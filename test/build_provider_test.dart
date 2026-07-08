/// Tests pour la sélection d'améliorations et l'agrégation de leurs effets
/// ([build_provider.dart]).
///
/// Ce fichier comble un manque de couverture : les tests d'effets de jeu
/// (`game_effects_test.dart`) surchargent directement [ActiveUpgradeEffects]
/// et n'exercent donc jamais le calcul réel fait par
/// [activeUpgradeEffectsProvider] (somme des effets des améliorations
/// sélectionnées). Vérifie :
///  - [SelectedUpgradeIdsNotifier] : sélection vide au départ, ajout/retrait
///    via [toggle], plafond [kMaxSelectedUpgrades] respecté
///  - [selectedUpgradesProvider] : ne retourne que les améliorations
///    effectivement sélectionnées (et débloquées)
///  - [activeUpgradeEffectsProvider] : agrégation réelle des effets, y
///    compris le cumul de plusieurs améliorations et la prise en compte du
///    niveau courant de chacune
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/core/constants.dart';
import 'package:hex_haven/data/app_database.dart';
import 'package:hex_haven/data/seed_data.dart';
import 'package:hex_haven/providers/build_provider.dart';

/// Installe une base mémoire, seed les données, et retourne un
/// [ProviderContainer] prêt à l'emploi.
///
/// Retourne `null` si sqlite3 natif n'est pas disponible sur cet
/// environnement (même garde que les autres tests de ce dossier).
Future<ProviderContainer?> _makeTestContainer() async {
  try {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDatabase(db);
    return ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  } catch (_) {
    return null;
  }
}

/// Débloque une amélioration existante au niveau demandé (`level` = index
/// `currentLevel`, donc 0 pour le niveau 1 affiché).
Future<void> _unlock(AppDatabase db, String id, {int level = 0}) async {
  await (db.update(db.upgrades)..where((u) => u.id.equals(id))).write(
    UpgradesCompanion(isUnlocked: const Value(true), currentLevel: Value(level)),
  );
}

void main() {
  group('SelectedUpgradeIdsNotifier', () {
    test('sélection vide à l\'initialisation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(selectedUpgradeIdsProvider), isEmpty);
    });

    test('toggle ajoute un id non présent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(selectedUpgradeIdsProvider.notifier).toggle('coins_plus');
      expect(container.read(selectedUpgradeIdsProvider), ['coins_plus']);
      expect(
        container.read(selectedUpgradeIdsProvider.notifier).isSelected('coins_plus'),
        isTrue,
      );
    });

    test('toggle retire un id déjà présent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(selectedUpgradeIdsProvider.notifier);
      notifier.toggle('coins_plus');
      notifier.toggle('coins_plus');
      expect(container.read(selectedUpgradeIdsProvider), isEmpty);
      expect(notifier.isSelected('coins_plus'), isFalse);
    });

    test('respecte le plafond kMaxSelectedUpgrades (3)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(selectedUpgradeIdsProvider.notifier);

      notifier.toggle('a');
      notifier.toggle('b');
      notifier.toggle('c');
      expect(container.read(selectedUpgradeIdsProvider).length, kMaxSelectedUpgrades);

      // Une 4e sélection est ignorée : le plafond est déjà atteint.
      notifier.toggle('d');
      expect(container.read(selectedUpgradeIdsProvider), ['a', 'b', 'c']);
      expect(notifier.isSelected('d'), isFalse);
    });

    test('au plafond, on peut toujours désélectionner puis resélectionner', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(selectedUpgradeIdsProvider.notifier);

      notifier.toggle('a');
      notifier.toggle('b');
      notifier.toggle('c');
      notifier.toggle('a'); // retire 'a' : 2 sélectionnées
      expect(container.read(selectedUpgradeIdsProvider), ['b', 'c']);

      notifier.toggle('d'); // la place libérée peut être reprise
      expect(container.read(selectedUpgradeIdsProvider), ['b', 'c', 'd']);
    });
  });

  group('selectedUpgradesProvider', () {
    test('ne retourne que les améliorations sélectionnées', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await _unlock(db, 'coins_plus');
      await _unlock(db, 'starting_tiles_plus');
      // 'doubled_connections' reste verrouillée et non sélectionnée.

      container.read(selectedUpgradeIdsProvider.notifier).toggle('coins_plus');

      // Laisse le StreamProvider (upgradesProvider) émettre sa première donnée.
      await Future<void>.delayed(Duration.zero);

      final selected = container.read(selectedUpgradesProvider);
      expect(selected.map((u) => u.id), ['coins_plus']);
    });

    test('sélection vide → liste vide', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(selectedUpgradesProvider), isEmpty);
    });
  });

  group('activeUpgradeEffectsProvider — agrégation réelle', () {
    test('aucune sélection → tous les effets à zéro', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final effects = container.read(activeUpgradeEffectsProvider);
      expect(effects.coinsMultiplier, 0.0);
      expect(effects.startingTilesBonus, 0);
      expect(effects.millionaireCoins, 0);
    });

    test('coins_plus niveau 1 (index 0) → +25% appliqué', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await _unlock(db, 'coins_plus', level: 0);
      container.read(selectedUpgradeIdsProvider.notifier).toggle('coins_plus');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(activeUpgradeEffectsProvider).coinsMultiplier, 0.25);
    });

    test('le niveau courant change bien la valeur de l\'effet (coins_plus niveau 2)',
        () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await _unlock(db, 'coins_plus', level: 1); // niveau 2 affiché → +50%
      container.read(selectedUpgradeIdsProvider.notifier).toggle('coins_plus');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(activeUpgradeEffectsProvider).coinsMultiplier, 0.50);
    });

    test('cumule plusieurs améliorations sélectionnées simultanément', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await _unlock(db, 'coins_plus', level: 0); // +25% pièces
      await _unlock(db, 'starting_tiles_plus', level: 0); // +2 tuiles
      await _unlock(db, 'villages_plus', level: 0); // +33% pièces village

      final notifier = container.read(selectedUpgradeIdsProvider.notifier);
      notifier.toggle('coins_plus');
      notifier.toggle('starting_tiles_plus');
      notifier.toggle('villages_plus');
      await Future<void>.delayed(Duration.zero);

      final effects = container.read(activeUpgradeEffectsProvider);
      expect(effects.coinsMultiplier, 0.25);
      expect(effects.startingTilesBonus, 2);
      expect(effects.villageCoinsBonus, 0.33);
    });

    test('n\'agrège pas une amélioration débloquée mais non sélectionnée', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await _unlock(db, 'coins_plus', level: 0);
      await _unlock(db, 'starting_tiles_plus', level: 0);
      // Seule coins_plus est sélectionnée.
      container.read(selectedUpgradeIdsProvider.notifier).toggle('coins_plus');
      await Future<void>.delayed(Duration.zero);

      final effects = container.read(activeUpgradeEffectsProvider);
      expect(effects.coinsMultiplier, 0.25);
      expect(effects.startingTilesBonus, 0,
          reason: 'starting_tiles_plus est débloquée mais pas sélectionnée');
    });

    test('millionaire (debug) → millionaireCoins reflète le palier unique', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await _unlock(db, 'millionaire', level: 0);
      container.read(selectedUpgradeIdsProvider.notifier).toggle('millionaire');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(activeUpgradeEffectsProvider).millionaireCoins, 1000000);
    });
  });
}
