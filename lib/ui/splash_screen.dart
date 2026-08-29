import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_restore.dart';
import '../services/audio_service.dart';
import '../services/cloud_save_service.dart';

/// SplashScreen affiché au démarrage.
///
/// Précharge en parallèle :
///   - les images statiques clés (home_background, hibiscus) ;
///   - tous les bruitages (voir AudioService.preloadSfx) ;
///   - activeSessionProvider pour que le bouton Jouer soit prêt sans loader ;
///   - la sync cloud (cloudSaveServiceProvider).
///
/// Une fois tout prêt, navigate vers '/home' (HomeScreen) en remplaçant.
const Duration _kMinDisplayDuration = Duration(milliseconds: 700);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Musique de tous les écrans hors partie en cours (voir AudioService) :
    // démarrée dès le splash pour une présence sonore immédiate au
    // lancement de l'app.
    unawaited(ref.read(audioServiceProvider).playMusic(MusicTrack.home));
    _load();
  }

  Future<void> _load() async {
    try {
      await Future.wait([
        _precacheImages(),
        ref.read(audioServiceProvider).preloadSfx(),
        ref.read(activeSessionProvider.future).catchError((_) => false),
        ref.read(cloudSaveServiceProvider).syncOnLaunch(),
        Future<void>.delayed(_kMinDisplayDuration),
      ]);
    } catch (_) {}

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _precacheImages() async {
    if (!mounted) return;
    await Future.wait([
      precacheImage(const AssetImage('assets/images/home_background.png'), context),
      precacheImage(const AssetImage('assets/images/hibiscus.png'), context),
      precacheImage(const AssetImage('assets/images/coin.png'), context),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          'assets/images/splash_logo.png',
          width: MediaQuery.sizeOf(context).width * 0.8,
          fit: BoxFit.fitWidth,
        ),
      ),
    );
  }
}
