/// Écran de résultats — Story 1.8b.
///
/// Overlay plein écran affiché lorsque la partie se termine
/// (pile de tuiles épuisée). Présente les statistiques finales
/// et un bouton Rejouer.
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'coin_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/snackbar_utils.dart';
import '../core/strings.dart';
import '../providers/build_provider.dart';
import '../providers/end_game_provider.dart';
import '../providers/grid_state_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/session_provider.dart';
import '../providers/session_restore.dart';
import '../providers/tile_stack_provider.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';


class ResultsModal extends ConsumerWidget {
  const ResultsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGameOver = ref.watch(isGameOverProvider);

    // Joue le bruitage de fin de partie une seule fois, exactement au
    // moment où la pop-up de résultats apparaît (transition false → true)
    // — pas à chaque rebuild pendant qu'elle reste affichée. La transition
    // elle-même n'a lieu qu'une fois les `coin.mp3` de la toute dernière
    // pose terminés (voir `placement_commit.dart`, `_checkGameOver`), donc
    // popup et bruitage démarrent déjà ensemble sans délai à ajouter ici.
    ref.listen<bool>(isGameOverProvider, (previous, next) {
      if (next && previous != true) {
        ref.read(audioServiceProvider).playEndGame();

        final endStats = ref.read(endGameStatsProvider);
        final usedUpgradeIds = ref.read(selectedUpgradeIdsProvider);
        final params = <String, Object>{
          'coins_hundred': (endStats?.coins ?? 0) ~/ 100,
        };
        for (var i = 0; i < usedUpgradeIds.length && i < 3; i++) {
          params['upgrade_${i + 1}'] =
              AnalyticsService.colorEventId(usedUpgradeIds[i]);
        }
        unawaited(AnalyticsService.logEvent('game_end', parameters: params));
      }
    });

    if (!isGameOver) return const SizedBox.shrink();

    final stats = ref.watch(endGameStatsProvider);
    if (stats == null) return const SizedBox.shrink();

    return Stack(
      children: [
        GestureDetector(
          onTap: () {},
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              color: const Color(0xFF0D1A2A).withValues(alpha: 0.55),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            child: _ResultsCard(stats: stats),
          ),
        ),
      ],
    );
  }
}

class _ResultsCard extends ConsumerWidget {
  const _ResultsCard({required this.stats});

  final EndGameStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      tintColor: kGlassBlue,
      tintAlpha: 0.18,
      borderColor: kGlassBlueBorder,
      borderWidth: 1.5,
      borderRadius: 24,
      blurSigma: 16,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
                // Titre
                Text(
                  context.tr.results_title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Pièces gagnées — mises en avant (bandeau doré)
                _CoinsHero(coins: stats.coins),
                const SizedBox(height: 24),

                // Autres statistiques — en retrait (plus petites, plus
                // discrètes, regroupées dans un bloc légèrement estompé).
                Opacity(
                  opacity: 0.75,
                  child: Column(
                    children: [
                      _StatRow(
                        icon: Icons.grid_on,
                        label: context.tr.results_tilesPlaced,
                        value: '${stats.placedTilesCount}',
                      ),
                      const SizedBox(height: 8),
                      _StatRow(
                        icon: Icons.link,
                        label: context.tr.results_connections3,
                        value: '${stats.connections3}',
                      ),
                      const SizedBox(height: 6),
                      _StatRow(
                        icon: Icons.link,
                        label: context.tr.results_connections4,
                        value: '${stats.connections4}',
                      ),
                      const SizedBox(height: 6),
                      _StatRow(
                        icon: Icons.link,
                        label: context.tr.results_connections5,
                        value: '${stats.connections5}',
                      ),
                      const SizedBox(height: 6),
                      _StatRow(
                        icon: Icons.link,
                        label: context.tr.results_connections6,
                        value: '${stats.connections6}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Bouton Rejouer
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2A9D8F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    onPressed: () => _replay(context, ref),
                    child: Text(
                      context.tr.results_replay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Bouton Retour à l'accueil
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.white,
                      backgroundColor:
                          const Color(0xFF2E3B52).withValues(alpha: 0.22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: const Color(0xFF3DBFAF).withValues(alpha: 0.38),
                        ),
                      ),
                    ),
                    onPressed: () => _goHome(context, ref),
                    child: Text(
                      context.tr.results_home,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _replay(BuildContext context, WidgetRef ref) {
    SessionSaver.endSession(ref.container);
    startNewGame(ref);
    clearAppSnackBars();
    Navigator.pushReplacementNamed(context, '/game');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    SessionSaver.endSession(ref.container);
    // Sans ce nettoyage complet (identique à _abandonGame dans
    // pause_modal.dart), l'état de la partie terminée restait en mémoire
    // (grille, pile à 0, session, isGameOverProvider toujours true) : au
    // prochain "Reprendre" depuis l'accueil, restoreSession() ne trouvait
    // plus de session active en base (déjà marquée inactive ci-dessus) et
    // ne faisait donc rien, laissant GameScreen réafficher l'ancien
    // plateau terminé avec la pop-up de résultats toujours ouverte.
    ref.invalidate(activeSessionProvider);
    // Voir le commentaire équivalent dans pause_modal.dart : force le
    // nettoyage immédiat de la bannière AdMob pour éviter qu'elle ne
    // bloque les taps sur l'accueil pendant la transition de route.
    ref.invalidate(bannerAdProvider);
    ref.read(sessionProvider.notifier).reset();
    ref.read(lastPlacementProvider.notifier).set(null);
    ref.read(gridProvider.notifier).reset();
    ref.read(tileStackProvider.notifier).reset();
    resetEndGame(ref);
    // '/' est le splash screen (précache polices/images + délai minimum) :
    // le réafficher ici provoquait un flash de splash inutile à chaque
    // retour à l'accueil après une partie. On va directement sur '/home'.
    clearAppSnackBars();
    ref.read(audioServiceProvider).playMusic(MusicTrack.home);
    Navigator.pushReplacementNamed(context, '/home');
  }
}

/// Bandeau doré mettant en avant les pièces gagnées — proposition A
/// (voir les autres propositions envoyées à Adrien en fin de tour).
class _CoinsHero extends StatelessWidget {
  const _CoinsHero({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withValues(alpha: 0.28),
            Colors.amber.shade700.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            context.tr.results_coins.toUpperCase(),
            style: TextStyle(
              color: Colors.amber.shade100,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CoinIcon(size: 32),
              const SizedBox(width: 10),
              Text(
                '$coins',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
