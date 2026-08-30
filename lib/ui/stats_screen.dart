/// Écran de statistiques joueur — Story 2.9b.
///
/// Affiche toutes les données de `player_stats` : tuiles totales, meilleur
/// score, parties jouées, pièces totales, et taille max par biome.
library;

import 'dart:convert';
import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'coin_icon.dart';
import 'screen_app_bar.dart';
import 'tropical_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/strings.dart';
import '../game/hex_cell.dart';
import '../game/tile_component.dart' show BiomeColor;
import '../providers/player_stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(playerStatsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: TropicalBackground(
        child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenAppBar(title: context.tr.stats_title),
                Expanded(
                  child: statsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (_, _) => Center(
                      child: Text(
                        context.tr.stats_error,
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
                            iconWidget: const CoinIcon(size: 20),
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
                                  context.tr.stats_colorGroups,
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
                              iconColor: BiomeType.values.firstWhere(
                                (b) => b.name == e.key,
                                orElse: () => BiomeType.forest,
                              ).color,
                              label: biomeName(context, e.key),
                              value: context.tr.stats_biomeMax(e.value),
                            ),
                          ),
                          if (biomeSizes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                context.tr.stats_noData,
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
        ),
    );
  }



class _StatCard extends StatelessWidget {
  const _StatCard({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.value,
    this.iconColor,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;

  /// Widget d'icône personnalisé (ex. logo pièce) — prioritaire sur [icon].
  final Widget? iconWidget;
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
        borderColor: kGlassBlueBorder,
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
                  child: iconWidget ?? Icon(icon, color: color, size: 20),
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
