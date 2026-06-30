import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors.dart';
import '../providers/placement_commit.dart';
import '../services/cloud_save_service.dart';

/// SplashScreen affiché au démarrage.
///
/// Précharge en parallèle :
///   - les polices Google Fonts (Pacifico, Nunito) pour éviter le flash
///     de police sur HomeScreen ;
///   - les images statiques clés (home_background, hibiscus) ;
///   - activeSessionProvider pour que le bouton Jouer soit prêt sans loader ;
///   - la sync cloud (cloudSaveServiceProvider).
///
/// Une fois tout prêt, navigate vers '/home' (HomeScreen) en remplaçant.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Future.wait([
        _precacheFonts(),
        _precacheImages(),
        // Préchauffe le FutureProvider pour que HomeScreen l'ait déjà en cache.
        ref.read(activeSessionProvider.future).catchError((_) => false),
        ref.read(cloudSaveServiceProvider).syncOnLaunch(),
      ]);
    } catch (_) {}

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _precacheFonts() async {
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.pacifico(),
        GoogleFonts.nunito(),
      ]).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _precacheImages() async {
    if (!mounted) return;
    await Future.wait([
      precacheImage(const AssetImage('assets/images/home_background.png'), context),
      precacheImage(const AssetImage('assets/images/hibiscus.png'), context),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTropicalTeal,
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}
