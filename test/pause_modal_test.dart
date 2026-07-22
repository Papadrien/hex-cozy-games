/// Tests pour la modale de Pause (PauseModal).
///
/// Couvre :
///  - le rendu vide quand le jeu n'est pas en pause ;
///  - l'affichage complet de la modale (titre, boutons) quand isPaused ;
///  - le bouton Reprendre qui repasse isPaused à false ;
///  - le sous-écran Options qui affiche Sound / Vibrations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/l10n/app_localizations.dart';
import 'package:hex_haven/providers/pause_provider.dart';
import 'package:hex_haven/services/ad_service.dart';
import 'package:hex_haven/ui/pause_modal.dart';

Widget _wrap({required PauseState pause}) {
  final container = ProviderContainer(
    overrides: [
      pauseProvider.overrideWith(
        () => _FakePauseNotifier(pause),
      ),
      bannerAdProvider.overrideWithValue(null),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: PauseModal()),
    ),
  );
}

class _FakePauseNotifier extends PauseStateNotifier {
  _FakePauseNotifier(this._initial);
  final PauseState _initial;

  @override
  PauseState build() => _initial;
}

void main() {
  testWidgets('n\'affiche rien quand le jeu n\'est pas en pause',
      (tester) async {
    await tester.pumpWidget(
      _wrap(pause: const PauseState(isPaused: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PauseModal), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('affiche la modale de pause avec tous les boutons',
      (tester) async {
    await tester.pumpWidget(
      _wrap(pause: const PauseState(isPaused: true)),
    );
    await tester.pumpAndSettle();

    final tr = AppLocalizations.of(
      tester.element(find.byType(PauseModal)),
    )!;

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text(tr.pause_resume), findsOneWidget);
    expect(find.text(tr.pause_options), findsOneWidget);
    expect(find.text(tr.pause_saveAndQuit), findsOneWidget);
    expect(find.text(tr.pause_abandon), findsOneWidget);
  });

  testWidgets('bouton Reprendre repasse isPaused à false', (tester) async {
    final container = ProviderContainer(
      overrides: [
        pauseProvider.overrideWith(
          () => _FakePauseNotifier(const PauseState(isPaused: true)),
        ),
        bannerAdProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: PauseModal()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = AppLocalizations.of(
      tester.element(find.byType(PauseModal)),
    )!;

    expect(container.read(pauseProvider).isPaused, isTrue);

    await tester.tap(find.text(tr.pause_resume));
    await tester.pumpAndSettle();

    expect(container.read(pauseProvider).isPaused, isFalse);
  });

  testWidgets(
      'tap Options affiche Musique, Bruitages, les deux volumes et Vibrations',
      (tester) async {
    await tester.pumpWidget(
      _wrap(pause: const PauseState(isPaused: true)),
    );
    await tester.pumpAndSettle();

    final tr = AppLocalizations.of(
      tester.element(find.byType(PauseModal)),
    )!;

    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text(tr.pause_options));
    await tester.pumpAndSettle();

    expect(find.text(tr.options_music), findsOneWidget);
    expect(find.text(tr.options_sfx), findsOneWidget);
    expect(find.text(tr.options_musicVolume), findsOneWidget);
    expect(find.text(tr.options_sfxVolume), findsOneWidget);
    expect(find.text(tr.options_vibrations), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2));
  });
}
