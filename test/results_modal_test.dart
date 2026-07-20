/// Tests pour la modale de résultats (ResultsModal).
///
/// Couvre :
///  - le rendu vide quand la partie n'est pas terminée ;
///  - l'affichage complet avec les stats et boutons quand game over ;
///  - la vérification des valeurs affichées (coins, tuiles, connexions).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/l10n/app_localizations.dart';
import 'package:hex_haven/providers/end_game_provider.dart';
import 'package:hex_haven/ui/results_modal.dart';

const _testStats = EndGameStats(
  placedTilesCount: 42,
  connections3: 5,
  connections4: 3,
  connections5: 2,
  connections6: 1,
  coins: 1200,
);

void main() {
  testWidgets('n\'affiche rien quand la partie n\'est pas terminée',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResultsModal(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ResultsModal), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('affiche les stats et les boutons quand game over',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResultsModal(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(isGameOverProvider.notifier).set(true);
    container.read(endGameStatsProvider.notifier).set(_testStats);
    await tester.pumpAndSettle();

    final tr = AppLocalizations.of(
      tester.element(find.byType(ResultsModal)),
    )!;

    expect(find.text(tr.results_title), findsOneWidget);
    expect(find.text('${_testStats.coins}'), findsOneWidget);
    expect(find.text(tr.results_replay), findsOneWidget);
    expect(find.text(tr.results_home), findsOneWidget);
  });

  testWidgets('affiche les valeurs correctes de chaque stat',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResultsModal(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(isGameOverProvider.notifier).set(true);
    container.read(endGameStatsProvider.notifier).set(_testStats);
    await tester.pumpAndSettle();

    final tr = AppLocalizations.of(
      tester.element(find.byType(ResultsModal)),
    )!;

    expect(find.text('${_testStats.placedTilesCount}'), findsOneWidget);
    expect(find.text(tr.results_tilesPlaced), findsOneWidget);

    expect(find.text('${_testStats.connections3}'), findsOneWidget);
    expect(find.text(tr.results_connections3), findsOneWidget);

    expect(find.text('${_testStats.connections4}'), findsOneWidget);
    expect(find.text(tr.results_connections4), findsOneWidget);

    expect(find.text('${_testStats.connections5}'), findsOneWidget);
    expect(find.text(tr.results_connections5), findsOneWidget);

    expect(find.text('${_testStats.connections6}'), findsOneWidget);
    expect(find.text(tr.results_connections6), findsOneWidget);
  });
}
