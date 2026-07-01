/// Écran de résultats — Story 1.8b.
///
/// Overlay plein écran affiché lorsque la partie se termine
/// (pile de tuiles épuisée). Présente les statistiques finales
/// et un bouton Rejouer.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../providers/end_game_provider.dart';
import '../providers/placement_commit.dart';

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF5BA4D4).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF7EC8E3).withValues(alpha: 0.38),
                width: 1.5,
              ),
            ),
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
                const SizedBox(height: 24),

                // Tuiles posées
                _StatRow(
                  icon: Icons.grid_on,
                  label: context.tr.results_tilesPlaced,
                  value: '${stats.placedTilesCount}',
                ),
                const SizedBox(height: 12),

                // Connexions par type
                _StatRow(
                  icon: Icons.link,
                  label: '${context.tr.results_connections3} (3)',
                  value: '${stats.connections3}',
                ),
                const SizedBox(height: 8),
                _StatRow(
                  icon: Icons.link,
                  label: '${context.tr.results_connections4} (4)',
                  value: '${stats.connections4}',
                ),
                const SizedBox(height: 8),
                _StatRow(
                  icon: Icons.link,
                  label: '${context.tr.results_connections5} (5)',
                  value: '${stats.connections5}',
                ),
                const SizedBox(height: 8),
                _StatRow(
                  icon: Icons.link,
                  label: '${context.tr.results_connections6} (6)',
                  value: '${stats.connections6}',
                ),
                const SizedBox(height: 16),

                // Pièces gagnées
                _StatRow(
                  icon: Icons.monetization_on,
                  label: context.tr.results_coins,
                  value: '${stats.coins}',
                  valueColor: Colors.amber,
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
                          const Color(0xFF5BA4D4).withValues(alpha: 0.22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: const Color(0xFF7EC8E3).withValues(alpha: 0.38),
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
          ),
        ),
      ),
    );
  }

  void _replay(BuildContext context, WidgetRef ref) {
    SessionSaver.endSession(ref);
    startNewGame(ref);
    Navigator.pushReplacementNamed(context, '/game');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    SessionSaver.endSession(ref);
    Navigator.pushReplacementNamed(context, '/');
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

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
            color: valueColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
