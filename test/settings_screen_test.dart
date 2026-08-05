/// Tests pour l'écran des Réglages (SettingsScreen).
///
/// Couvre :
///  - le rendu initial (labels, bouton fermer, titre) ;
///  - le toggle Musique (tap sur l'icône music_note → musicEnabled flip) ;
///  - le toggle Bruitages (tap sur l'icône graphic_eq → sfxEnabled flip) ;
///  - les sliders Volume musique / Volume bruitages (drag → volume mis à
///    jour indépendamment pour chaque catégorie) ;
///  - le toggle Vibration (tap sur l'icône vibration → vibrationEnabled flip) ;
///  - le toggle Mode immersif (tap sur l'icône fullscreen → immersiveEnabled
///    flip).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/l10n/app_localizations.dart';
import 'package:hex_haven/providers/options_provider.dart';
import 'package:hex_haven/ui/settings_screen.dart';

Widget _wrap() {
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('rend correctement les labels et le titre', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(SettingsScreen));
    final tr = AppLocalizations.of(element)!;

    expect(find.text(tr.settings_title), findsOneWidget);
    expect(find.text(tr.options_music), findsOneWidget);
    expect(find.text(tr.options_sfx), findsOneWidget);
    expect(find.text(tr.options_musicVolume), findsOneWidget);
    expect(find.text(tr.options_sfxVolume), findsOneWidget);
    expect(find.text(tr.options_vibrations), findsOneWidget);
    expect(find.text(tr.options_immersiveMode), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2));
  });

  testWidgets('toggle musique via l\'icône music_note', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );

    // Par défaut musicEnabled == true.
    expect(container.read(optionsProvider).musicEnabled, isTrue);

    await tester.tap(find.byIcon(Icons.music_note).first);
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).musicEnabled, isFalse);

    await tester.tap(find.byIcon(Icons.music_note).first);
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).musicEnabled, isTrue);
  });

  testWidgets('toggle bruitages via l\'icône graphic_eq', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );

    // Par défaut sfxEnabled == true.
    expect(container.read(optionsProvider).sfxEnabled, isTrue);

    await tester.tap(find.byIcon(Icons.graphic_eq).first);
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).sfxEnabled, isFalse);

    await tester.tap(find.byIcon(Icons.graphic_eq).first);
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).sfxEnabled, isTrue);
  });

  testWidgets(
      'déplacer le slider Volume musique met à jour musicVolume uniquement',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );

    // Par défaut musicVolume == sfxVolume == 1.0.
    expect(container.read(optionsProvider).musicVolume, 1.0);
    expect(container.read(optionsProvider).sfxVolume, 1.0);

    // Le premier slider affiché est celui de la musique.
    await tester.drag(find.byType(Slider).first, const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(container.read(optionsProvider).musicVolume, lessThan(1.0));
    expect(container.read(optionsProvider).sfxVolume, 1.0);
  });

  testWidgets(
      'déplacer le slider Volume bruitages met à jour sfxVolume uniquement',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );

    expect(container.read(optionsProvider).musicVolume, 1.0);
    expect(container.read(optionsProvider).sfxVolume, 1.0);

    // Le second slider affiché est celui des bruitages.
    await tester.drag(find.byType(Slider).last, const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(container.read(optionsProvider).musicVolume, 1.0);
    expect(container.read(optionsProvider).sfxVolume, lessThan(1.0));
  });

  testWidgets('toggle vibration via l\'icône vibration', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );

    expect(container.read(optionsProvider).vibrationEnabled, isTrue);

    await tester.tap(find.byIcon(Icons.vibration));
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).vibrationEnabled, isFalse);

    await tester.tap(find.byIcon(Icons.vibration));
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).vibrationEnabled, isTrue);
  });

  testWidgets('toggle mode immersif via l\'icône fullscreen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );

    expect(container.read(optionsProvider).immersiveEnabled, isTrue);

    // Le toggle est en bas de l'écran de test (800×600) : scrolle pour
    // qu'il soit tappable.
    await tester.ensureVisible(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).immersiveEnabled, isFalse);

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).immersiveEnabled, isTrue);
  });
}
