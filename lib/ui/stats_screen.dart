/// Écran de statistiques joueur — Story 2.9b.
///
/// Affiche toutes les données de `player_stats` : tuiles totales, meilleur
/// score, parties jouées, pièces totales, et taille max par biome.
library;

import 'dart:convert';
import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../providers/player_stats_provider.dart';
import '../services/haptics_service.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(playerStatsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/home_background.png',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D1B3E).withValues(alpha: 0.72),
                  const Color(0xFF0A1628).withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsAppBar(),
                Expanded(
                  child: statsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (_, _) => Center(
                      child: Text(
                        'Erreur',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    data: (stats) {
                      final biomeSizes =
                          Map<String, int>.from(
                            jsonDecode(stats.maxBiomeSizes) as Map,
                          );

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          _StatCard(
                            icon: Icons.grid_on,
                            label: context.tr.stats_totalTiles,
                            value: '${stats.totalTilesPlaced}',
                          ),
                          _StatCard(
                            icon: Icons.emoji_events,
                            label: context.tr.stats_bestScore,
                            value: '${stats.bestScore}',
                          ),
                          _StatCard(
                            icon: Icons.play_arrow,
                            label: context.tr.stats_gamesPlayed,
                            value: '${stats.totalGamesPlayed}',
                          ),
                          _StatCard(
                            icon: Icons.monetization_on,
                            label: context.tr.stats_totalCoins,
                            value: '${stats.totalCoinsEarned}',
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: kBrandBlue,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'GROUPES DE COULEUR',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...biomeSizes.entries.map(
                            (e) => _StatCard(
                              icon: Icons.circle,
                              iconColor: _biomeColor(e.key),
                              label: biomeName(context, e.key),
                              value: context.tr.stats_biomeMax(e.key, e.value),
                            ),
                          ),
                          if (biomeSizes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Aucune donnée',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _biomeColor(String biome) {
    switch (biome) {
      case 'forest':
        return const Color(0xFF43A047);
      case 'village':
        return const Color(0xFFE53935);
      case 'plain':
        return const Color(0xFFFFD600);
      case 'water':
        return const Color(0xFF1E88E5);
      case 'mountain':
        return const Color(0xFF8E24AA);
      case 'orange':
        return const Color(0xFFFB8C00);
      case 'pink':
        return const Color(0xFFFFABE6);
      case 'black':
        return const Color(0xFF212121);
      case 'white':
        return const Color(0xFFF5F5F5);
      default:
        return kBrandBlue;
    }
  }
}

class _StatsAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _StatsGlassIconButton(
            icon: Icons.close,
            onPressed: () {
              buttonHapticTap(context);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 14),
          Text(
            context.tr.stats_title,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGlassIconButton extends StatelessWidget {
  const _StatsGlassIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      blurSigma: 10,
      tintColor: kGlassBlue,
      tintAlpha: 0.22,
      borderColor: kGlassBlueBorder.withValues(alpha: 0.38),
      padding: const EdgeInsets.all(10),
      onTap: onPressed,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? kBrandBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        tintColor: kGlassBlue,
        borderColor: kGlassBlueBorder.withValues(alpha: 0.38),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ],
      ),
      ),
    );
  }
}
