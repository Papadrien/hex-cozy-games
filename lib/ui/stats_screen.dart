/// Écran de statistiques joueur — Story 2.9b.
///
/// Affiche toutes les données de `player_stats` : tuiles totales, meilleur
/// score, parties jouées, pièces totales, et taille max par biome.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../providers/player_stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(playerStatsProvider);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr.stats_title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, _) => Center(
          child: Text(
            'Erreur',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
        data: (stats) {
          final biomeSizes =
              Map<String, int>.from(jsonDecode(stats.maxBiomeSizes) as Map);

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
              Text(
                'Biomes',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              ...biomeSizes.entries.map((e) => _StatCard(
                    icon: _biomeIcon(e.key),
                    label: biomeName(context, e.key),
                    value: context.tr.stats_biomeMax(e.key, e.value),
                  )),
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
    );
  }

  IconData _biomeIcon(String biome) {
    switch (biome) {
      case 'forest':
        return Icons.forest;
      case 'village':
        return Icons.home;
      case 'plain':
        return Icons.landscape;
      case 'water':
        return Icons.water_drop;
      case 'mountain':
        return Icons.terrain;
      default:
        return Icons.circle;
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kBrandBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kBrandBlue, size: 20),
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
    );
  }
}
