/// Tests pour l'écran de sélection des améliorations (BuildScreen).
///
/// Couvre, pour 3 améliorations non-debug (starting_tiles_plus,
/// doubled_connections, coins_plus — volontairement hors millionaire /
/// warehouse qui sont réservées au debug) :
///  - leur ajout à la sélection (jusqu'au maximum [kMaxSelectedUpgrades]) ;
///  - leur affichage avec la description propre à chacune une fois la
///    carte dépliée ;
///  - la montée de niveau de chacune (confirmation en deux temps, débit
///    des pièces, mise à jour de `currentLevel` en base).
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/data/app_database.dart';
import 'package:hex_haven/data/seed_data.dart';
import 'package:hex_haven/l10n/app_localizations.dart';
import 'package:hex_haven/providers/build_provider.dart';
import 'package:hex_haven/ui/build_screen.dart';
import 'package:hex_haven/ui/glass_container.dart';

/// Les 3 améliorations couvertes par ces tests, avec leur nom tel que
/// défini dans `seed_data.dart`. Choisies car non-debug (contrairement à
/// `millionaire` et `warehouse`, réservées au bouton "débloquer tout" de
/// debug) et disposant chacune de plusieurs paliers de montée de niveau.
const Map<String, String> _testUpgrades = {
  'starting_tiles_plus': 'Tuiles de départ+',
  'doubled_connections': 'Connexions doublées',
  'coins_plus': 'Pièces+',
};

/// Installe une base mémoire, seed les données, débloque les 3 améliorations
/// de test au niveau 1 (currentLevel 0), et crédite le joueur en pièces.
///
/// Retourne `null` si sqlite3 natif n'est pas disponible sur cet
/// environnement (même garde que `upgrade_level_up_test.dart`).
Future<ProviderContainer?> _makeTestContainer({int coins = 200000}) async {
  try {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDatabase(db);
    await db.into(db.playerProfile).insert(
          PlayerProfileCompanion(id: const Value(1), coins: Value(coins)),
        );
    for (final id in _testUpgrades.keys) {
      await (db.update(db.upgrades)..where((u) => u.id.equals(id))).write(
        const UpgradesCompanion(
          isUnlocked: Value(true),
          currentLevel: Value(0),
        ),
      );
    }
    return ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  } catch (_) {
    return null;
  }
}

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BuildScreen(),
    ),
  );
}

/// Trouve la carte glass entière d'une amélioration à partir de son nom
/// affiché — c'est le plus proche ancêtre [GlassContainer] du texte.
Finder _cardFinder(String name) => find
    .ancestor(of: find.text(name), matching: find.byType(GlassContainer))
    .first;

/// Trouve la pastille de sélection (cercle coche/anneau) d'une carte donnée.
/// C'est le seul [AnimatedContainer] présent dans une carte.
Finder _selectionCheckFinder(String name) => find.descendant(
      of: _cardFinder(name),
      matching: find.byType(AnimatedContainer),
    );

void main() {
  // Surface large pour que les 3 cartes (repliées ou avec une carte
  // dépliée) tiennent entièrement dans le viewport testé, sans dépendre
  // du scroll pour que les widgets soient effectivement construits.
  Future<void> setSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'ajoute 3 améliorations à la sélection (hors debug)',
    (tester) async {
      final container = await _makeTestContainer();
      if (container == null) return; // sqlite3 natif indisponible ici
      addTearDown(container.dispose);
      await setSurface(tester);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      expect(container.read(selectedUpgradeIdsProvider), isEmpty);
      expect(find.text('0 / 3'), findsOneWidget);

      for (final name in _testUpgrades.values) {
        await tester.tap(_selectionCheckFinder(name));
        await tester.pumpAndSettle();
      }

      expect(
        container.read(selectedUpgradeIdsProvider).toSet(),
        _testUpgrades.keys.toSet(),
      );
      expect(find.text('3 / 3'), findsOneWidget);
    },
  );

  testWidgets(
    'affiche la description propre à chaque amélioration une fois dépliée',
    (tester) async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      await setSurface(tester);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      final tr = AppLocalizations.of(
        tester.element(find.byType(BuildScreen)),
      )!;
      final expectedDescriptions = {
        'starting_tiles_plus': tr.upgrade_desc_starting_tiles_plus,
        'doubled_connections': tr.upgrade_desc_doubled_connections,
        'coins_plus': tr.upgrade_desc_coins_plus,
      };

      for (final entry in _testUpgrades.entries) {
        final description = expectedDescriptions[entry.key]!;

        // Repliée : la description n'est pas encore affichée.
        expect(find.text(description), findsNothing);

        // Dépliage — tap sur la ligne nom/icône de la carte.
        await tester.tap(find.text(entry.value));
        await tester.pumpAndSettle();

        expect(find.text(description), findsOneWidget);

        // Replie avant de passer à la suivante pour garder un rendu léger.
        await tester.tap(find.text(entry.value));
        await tester.pumpAndSettle();
        expect(find.text(description), findsNothing);
      }
    },
  );

  testWidgets(
    'monte de niveau chacune des 3 améliorations',
    (tester) async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      await setSurface(tester);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      final tr = AppLocalizations.of(
        tester.element(find.byType(BuildScreen)),
      )!;
      final db = container.read(appDatabaseProvider);

      for (final entry in _testUpgrades.entries) {
        final id = entry.key;
        final name = entry.value;

        // Déplie la carte pour révéler le bouton "Améliorer".
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();

        final upgradeButton = find.text(
          '${tr.upgrades_cost} : 20000  ${tr.upgrades_upgradeButton}',
        );
        expect(upgradeButton, findsOneWidget);

        // Premier tap → passe en confirmation.
        await tester.tap(upgradeButton);
        await tester.pumpAndSettle();
        expect(find.text(tr.upgrades_confirmButton), findsOneWidget);

        // Second tap → confirme et déclenche la montée de niveau.
        await tester.tap(find.text(tr.upgrades_confirmButton));
        await tester.pumpAndSettle();

        final row = await (db.select(db.upgrades)
              ..where((u) => u.id.equals(id)))
            .getSingle();
        expect(row.currentLevel, 1,
            reason: '$id devrait être passé au niveau 2 (index 1)');

        // Replie avant de passer à la suivante.
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }

      // Vérifie que les 3 pièces ont bien été débitées (3 × 20000).
      final profile =
          await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
              .getSingle();
      expect(profile.coins, 200000 - 3 * 20000);
    },
  );
}
