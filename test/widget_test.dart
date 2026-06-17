// Test smoke minimal — vérifie que l'app démarre, que le GameWidget Flame
// s'affiche, et que le provider Riverpod de test ('Riverpod OK') est bien
// résolu. Voir critères d'acceptance story 1.1.

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_cozy_games/main.dart';

void main() {
  testWidgets('HexCozyGamesApp démarre et affiche le GameWidget', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: HexCozyGamesApp()),
    );
    await tester.pump();

    expect(find.byType(GameWidget), findsOneWidget);
    expect(find.text('Riverpod OK'), findsOneWidget);
  });
}
