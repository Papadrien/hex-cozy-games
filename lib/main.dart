import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/page_transitions.dart';
import 'core/snackbar_utils.dart';
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

  // Plein écran immersif : masque la barre de statut et la barre de
  // navigation système. En mode "immersiveSticky", un balayage depuis le
  // bord les fait réapparaître brièvement avant qu'elles ne se masquent à
  // nouveau — adapté à une app de jeu où l'on veut éviter tout appui
  // accidentel sur les boutons système.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const ProviderScope(child: HexCozyGamesApp()));
}

class HexCozyGamesApp extends StatefulWidget {
  const HexCozyGamesApp({super.key});

  @override
  State<HexCozyGamesApp> createState() => _HexCozyGamesAppState();
}

class _HexCozyGamesAppState extends State<HexCozyGamesApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Le système restaure parfois les barres système (statut/navigation)
    // au retour au premier plan — on réapplique alors le plein écran.
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hex Cozy Games',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return BlurFadePageRoute<void>(
              builder: (_) => const SplashScreen(),
              settings: settings,
            );
          case '/home':
            // Retour au menu : transition calme, jouée souvent (depuis le
            // splash, la partie, les résultats, la pause).
            return BlurFadePageRoute<void>(
              builder: (_) => const HomeScreen(),
              settings: settings,
            );
          case '/game':
            // Entrée en partie : moment fort, wipe hexagonal thématique.
            return HexWipePageRoute<void>(
              builder: (_) => const GameScreen(),
              settings: settings,
            );
          default:
            return null;
        }
      },
    );
  }
}
