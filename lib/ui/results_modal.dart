/// Écran de résultats — Story 1.8b.
///
/// Overlay plein écran affiché lorsque la partie se termine
/// (pile de tuiles épuisée). Présente les statistiques finales
/// et un bouton Rejouer.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/snackbar_utils.dart';
import '../core/strings.dart';
import '../providers/end_game_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/session_restore.dart';
import '../services/haptics_service.dart';

class ResultsModal extends ConsumerWidget {
  const ResultsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGameOver = ref.watch(isGameOverProvider);
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
    buttonHapticTap(context);
    SessionSaver.endSession(ref);
    startNewGame(ref);
    clearAppSnackBars();
    Navigator.pushReplacementNamed(context, '/game');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    buttonHapticTap(context);
    SessionSaver.endSession(ref);
    // '/' est le splash screen (précache polices/images + délai minimum) :
    // le réafficher ici provoquait un flash de splash inutile à chaque
    // retour à l'accueil après une partie. On va directement sur '/home'.
    clearAppSnackBars();
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
              const Icon(Icons.monetization_on, color: Colors.amber, size: 32),
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
