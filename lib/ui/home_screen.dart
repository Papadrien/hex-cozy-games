import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/snackbar_utils.dart';
import '../data/app_database.dart';
import '../providers/placement_commit.dart';
import '../providers/player_profile_provider.dart';
import '../providers/player_stats_provider.dart';
import '../providers/session_restore.dart';
import '../services/ad_service.dart';
import 'home_center_content.dart';
import 'home_debug_button.dart';
import 'home_title.dart';
import 'home_top_bar.dart';
import 'review_bottom_sheet.dart';

// Bleu nuit tealisé pour les boutons secondaires — foncé pour la lisibilité
// du texte blanc, bordure teal assortie au bouton Jouer.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);
    final totalCoins = ref.watch(totalCoinsProvider);
    final isWatchingAd = ref.watch(isWatchingRewardedAdProvider);

    // Story rate-us : propose la bottom sheet d'avis dès que
    // `player_stats.total_games_played` atteint le seuil — ne se déclenche
    // qu'une fois (voir [ReviewService.shouldPromptForReview]), y compris
    // pour un joueur ayant déjà dépassé le seuil avant l'arrivée de cette
    // fonctionnalité. L'accueil est le point de passage le plus fiable
    // après une partie ("Retour à l'accueil" du résultat, ou relance
    // depuis le splash), donc c'est ici qu'on vérifie plutôt qu'en fin de
    // partie où une bottom sheet viendrait se superposer au résultat.
    ref.listen<AsyncValue<PlayerStatsRow>>(playerStatsProvider, (
      previous,
      next,
    ) {
      final stats = next.value;
      if (stats == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          maybeShowReviewPrompt(
            context,
            ref,
            totalGamesPlayed: stats.totalGamesPlayed,
          );
        }
      });
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fond tropical plein écran ──────────────────────────────────────
          Image.asset(
            'assets/images/home_background.png',
            fit: BoxFit.cover,
          ),
          // ── Titre à 20 % de la hauteur écran ──────────────────────────────
          Builder(
            builder: (context) {
              final screenHeight = MediaQuery.sizeOf(context).height;
              return Positioned(
                top: screenHeight * 0.20,
                left: 0,
                right: 0,
                child: const HomeTitle(),
              );
            },
          ),
          // ── Contenu ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                HomeTopBar(totalCoins: totalCoins),
                const Spacer(),
                HomeCenterContent(
                  activeSession: activeSession,
                  onPlay: () async {
                    await SessionSaver.endSession(ref.container);
                    startNewGame(ref);
                    if (context.mounted) {
                      clearAppSnackBars();
                      Navigator.pushReplacementNamed(context, '/game');
                    }
                  },
                  onResume: () async {
                    await restoreSession(ref);
                    if (context.mounted) {
                      clearAppSnackBars();
                      Navigator.pushReplacementNamed(context, '/game');
                    }
                  },
                ),
                if (!kReleaseMode) HomeDebugButton(ref: ref),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // ── Blocage plein écran pendant le chargement/affichage de la
          // rewarded ad — RewardedAd.load peut prendre plusieurs secondes
          // avant que la pub ne s'affiche réellement, sans quoi l'utilisateur
          // peut naviguer ailleurs (settings, shop, jouer) pendant ce temps.
          if (isWatchingAd)
            AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: CircularProgressIndicator(color: kRewardGold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
