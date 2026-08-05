import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/page_transitions.dart';
import 'core/snackbar_utils.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/options_provider.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/system_ui_service.dart';
import 'ui/game_screen.dart';
import 'ui/home_screen.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AnalyticsService.initialize();
  await MobileAds.instance.initialize();
  await initOptionsPrefs();

  // Plein écran immersif : masque la barre de statut et la barre de
  // navigation système. En mode "immersiveSticky", un balayage depuis le
  // bord les fait réapparaître brièvement avant qu'elles ne se masquent à
  // nouveau — adapté à une app de jeu où l'on veut éviter tout appui
  // accidentel sur les boutons système. Le joueur peut désactiver ce
  // comportement dans les Réglages (toggle "Mode immersif").
  await applySystemUiMode(initialImmersiveEnabled());

  runApp(const ProviderScope(child: HexCozyGamesApp()));
}

class HexCozyGamesApp extends ConsumerStatefulWidget {
  const HexCozyGamesApp({super.key});

  @override
  ConsumerState<HexCozyGamesApp> createState() => _HexCozyGamesAppState();
}

class _HexCozyGamesAppState extends ConsumerState<HexCozyGamesApp>
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
    // au retour au premier plan — on réapplique alors le mode d'affichage
    // choisi dans les Réglages (immersif ou non).
    if (state == AppLifecycleState.resumed) {
      unawaited(
        applySystemUiMode(ref.read(optionsProvider).immersiveEnabled),
      );
    }
    // Musique de fond (accueil ou partie en cours) : coupée dès que l'app
    // quitte le premier plan, reprise à son retour — quel que soit l'écran
    // actif (splash, accueil, jeu), puisque ce widget englobe toute la nav.
    if (state == AppLifecycleState.paused) {
      unawaited(ref.read(audioServiceProvider).pauseMusicForBackground());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(audioServiceProvider).resumeMusicFromBackground());
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
