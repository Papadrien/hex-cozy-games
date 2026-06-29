import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'services/analytics_service.dart';
import 'ui/game_screen.dart';
import 'ui/home_screen.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AnalyticsService.initialize();
  await MobileAds.instance.initialize();

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/home': (_) => const HomeScreen(),
        '/game': (_) => const GameScreen(),
      },
    );
  }
}
