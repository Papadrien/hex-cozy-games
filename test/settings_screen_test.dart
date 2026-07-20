/// Tests pour l'écran des Réglages (SettingsScreen).
///
/// Couvre :
///  - le rendu initial (labels, bouton fermer, titre) ;
///  - le toggle Sound (tap sur l'icône volume_up → soundEnabled flip) ;
///  - le toggle Vibration (tap sur l'icône vibration → vibrationEnabled flip).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/l10n/app_localizations.dart';
import 'package:hex_haven/providers/options_provider.dart';
import 'package:hex_haven/ui/settings_screen.dart';

Widget _wrap() {
  return ProviderScope(
    child: const MaterialApp(
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
    expect(find.text(tr.options_sound), findsOneWidget);
    expect(find.text(tr.options_vibrations), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('toggle sound via l\'icône volume_up', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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

    // Par défaut soundEnabled == true.
    expect(container.read(optionsProvider).soundEnabled, isTrue);

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).soundEnabled, isFalse);

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pumpAndSettle();
    expect(container.read(optionsProvider).soundEnabled, isTrue);
  });

  testWidgets('toggle vibration via l\'icône vibration', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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
}
