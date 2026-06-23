import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'services/analytics_service.dart';
import 'services/cloud_save_service.dart';
import 'ui/game_screen.dart';
import 'ui/home_screen.dart';

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
        '/': (_) => const _AppLifecycle(child: HomeScreen()),
        '/game': (_) => const GameScreen(),
      },
    );
  }
}

/// Widget interne qui déclenche la sync cloud au premier frame.
class _AppLifecycle extends ConsumerStatefulWidget {
  const _AppLifecycle({required this.child});
  final Widget child;

  @override
  ConsumerState<_AppLifecycle> createState() => _AppLifecycleState();
}

class _AppLifecycleState extends ConsumerState<_AppLifecycle> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cloudSaveServiceProvider).syncOnLaunch();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
