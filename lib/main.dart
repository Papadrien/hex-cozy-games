import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'services/analytics_service.dart';
import 'ui/game_screen.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ne lève jamais d'exception : démarre en mode dégradé si le projet
  // Firebase / google-services.json n'est pas encore configuré.
  await AnalyticsService.initialize();

  runApp(const ProviderScope(child: HexCozyGamesApp()));
}

class HexCozyGamesApp extends StatelessWidget {
  const HexCozyGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hex Cozy Games',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/game': (_) => const GameScreen(),
      },
    );
  }
}
