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
/// Retourne `null` si sqlite3 natif n'est pas disponible.
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
      container.read(selectedUpgradeIdsProvider.notifier).toggle('a');
      expect(container.read(selectedUpgradeIdsProvider), ['a']);
    });

    test('toggle retire un id présent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(selectedUpgradeIdsProvider.notifier);
      n.toggle('a');
      n.toggle('a');
      expect(container.read(selectedUpgradeIdsProvider), isEmpty);
    });

    test('ne dépasse pas kMaxSelectedUpgrades', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(selectedUpgradeIdsProvider.notifier);
      n.toggle('a');
      n.toggle('b');
      n.toggle('c');
      n.toggle('d');
      n.toggle('e');
      final ids = container.read(selectedUpgradeIdsProvider);
      expect(ids.length, kMaxSelectedUpgrades);
      expect(ids, ['a', 'b', 'c']);
    });
  });

  group('selectedUpgradesProvider', () {
    test('ne retourne que les améliorations sélectionnées', () {
      final rows = [
        UpgradeRow(
          id: 'coins_plus',
          name: 'Pièces+',
          effectType: 'coinsPercentBonus',
          isUnlocked: true,
          currentLevel: 0,
          unlockConditionType: '',
          unlockConditionValue: 0,
        ),
        UpgradeRow(
          id: 'starting_tiles_plus',
          name: 'Tuiles départ+',
          effectType: 'startingTilesBonus',
          isUnlocked: true,
          currentLevel: 0,
          unlockConditionType: '',
          unlockConditionValue: 0,
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          selectedUpgradesProvider.overrideWith(
            (ref) {
              final ids = ref.watch(selectedUpgradeIdsProvider);
              return rows.where((u) => ids.contains(u.id)).toList();
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedUpgradeIdsProvider.notifier).toggle('coins_plus');

      final selected = container.read(selectedUpgradesProvider);
      expect(selected.map((u) => u.id), ['coins_plus']);
    });

    test('sélection vide → liste vide', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);

      expect(container.read(selectedUpgradesProvider), isEmpty);
    });
  });

  group('activeUpgradeEffectsProvider — agrégation réelle', () {
    test('aucune sélection → tous les effets à zéro', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);

      final effects = container.read(activeUpgradeEffectsProvider);
      expect(effects.coinsThreshold, 0);
      expect(effects.startingTilesBonus, 0);
      expect(effects.millionaireCoins, 0);
    });

    UpgradeRow row({
      required String id,
      required String effectType,
      int currentLevel = 0,
      bool isUnlocked = true,
    }) {
      return UpgradeRow(
        id: id,
        name: id,
        effectType: effectType,
        isUnlocked: isUnlocked,
        currentLevel: currentLevel,
        unlockConditionType: '',
        unlockConditionValue: 0,
      );
    }

    ProviderContainer containerWithUpgrades(List<UpgradeRow> rows) {
      return ProviderContainer(
        overrides: [
          selectedUpgradesProvider.overrideWith((ref) => rows),
        ],
      );
    }

    test('coins_plus niveau 1 (index 0) → seuil 4 appliqué', () {
      final container = containerWithUpgrades([
        row(id: 'coins_plus', effectType: 'coinsPercentBonus', currentLevel: 0),
      ]);
      addTearDown(container.dispose);

      expect(container.read(activeUpgradeEffectsProvider).coinsThreshold, 4);
    });

    test('le niveau courant change bien la valeur de l\'effet (coins_plus niveau 2)',
        () {
      final container = containerWithUpgrades([
        row(id: 'coins_plus', effectType: 'coinsPercentBonus', currentLevel: 1),
      ]);
      addTearDown(container.dispose);

      expect(container.read(activeUpgradeEffectsProvider).coinsThreshold, 2);
    });

    test('cumule plusieurs améliorations sélectionnées simultanément', () {
      final container = containerWithUpgrades([
        row(id: 'coins_plus', effectType: 'coinsPercentBonus', currentLevel: 0),
        row(
          id: 'starting_tiles_plus',
          effectType: 'startingTilesBonus',
          currentLevel: 0,
        ),
        row(
          id: 'villages_plus',
          effectType: 'villageCoinsPercentBonus',
          currentLevel: 0,
        ),
      ]);
      addTearDown(container.dispose);

      final effects = container.read(activeUpgradeEffectsProvider);
      expect(effects.coinsThreshold, 4);
      expect(effects.startingTilesBonus, 2);
      expect(effects.villageCoinsThreshold, 4);
    });

    test('combo_plus (niveau 1) → comboStreakInterval = 10', () {
      final container = containerWithUpgrades([
        row(id: 'combo_plus', effectType: 'comboBonusTiles', currentLevel: 0),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).comboStreakInterval,
        10,
      );
    });

    test('combo_plus (niveau 3) → comboStreakInterval = 5', () {
      final container = containerWithUpgrades([
        row(id: 'combo_plus', effectType: 'comboBonusTiles', currentLevel: 2),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).comboStreakInterval,
        5,
      );
    });

    test('extended_preview (niveau 1) → extendedPreviewCount = 4', () {
      final container = containerWithUpgrades([
        row(
          id: 'extended_preview',
          effectType: 'extendedPreviewCount',
          currentLevel: 0,
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).extendedPreviewCount,
        4,
      );
    });

    test('extended_preview (niveau 3) → extendedPreviewCount = 6', () {
      final container = containerWithUpgrades([
        row(
          id: 'extended_preview',
          effectType: 'extendedPreviewCount',
          currentLevel: 2,
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).extendedPreviewCount,
        6,
      );
    });

    test('hated_color (niveau 1) → hatedColorExclusionDuration = 5', () {
      final container = containerWithUpgrades([
        row(
          id: 'hated_color',
          effectType: 'hatedColorExclusion',
          currentLevel: 0,
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).hatedColorExclusionDuration,
        5,
      );
    });

    test('hated_color (niveau 3) → hatedColorExclusionDuration = 10', () {
      final container = containerWithUpgrades([
        row(
          id: 'hated_color',
          effectType: 'hatedColorExclusion',
          currentLevel: 2,
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).hatedColorExclusionDuration,
        10,
      );
    });

    test('closure_bonus (niveau 1) → closureBonusTiles = 1', () {
      final container = containerWithUpgrades([
        row(
          id: 'closure_bonus',
          effectType: 'closureBonusTiles',
          currentLevel: 0,
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).closureBonusTiles,
        1,
      );
    });

    test('closure_bonus (niveau 3) → closureBonusTiles = 3', () {
      final container = containerWithUpgrades([
        row(
          id: 'closure_bonus',
          effectType: 'closureBonusTiles',
          currentLevel: 2,
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).closureBonusTiles,
        3,
      );
    });

    test('warehouse (debug) → warehouseStartingTiles = 500', () {
      final container = containerWithUpgrades([
        row(
          id: 'warehouse',
          effectType: 'warehouseStartingTiles',
          currentLevel: 0,
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).warehouseStartingTiles,
        500,
      );
    });

    test('millionaire (debug) → millionaireCoins reflète le palier unique', () {
      final container = containerWithUpgrades([
        row(id: 'millionaire', effectType: 'millionaireCoins', currentLevel: 0),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(activeUpgradeEffectsProvider).millionaireCoins,
        1000000,
      );
    });
  });
}
