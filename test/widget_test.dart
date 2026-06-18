import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_cozy_games/game/hex_board_game.dart';
import 'package:hex_cozy_games/main.dart';

void main() {
  testWidgets('HomeScreen → Play → GameWidget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: HexCozyGamesApp()),
    );
    await tester.pump();

    // Home screen should be shown
    expect(find.text('Play'), findsOneWidget);

    // Tap Play to navigate to the game
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(GameWidget<HexBoardGame>), findsOneWidget);
  });
}
