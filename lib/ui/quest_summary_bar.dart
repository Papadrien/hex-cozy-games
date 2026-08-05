import 'package:flutter/material.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import 'glass_container.dart';

/// Barre de progression synthétique de l'ensemble des quêtes permanentes :
/// compteur `complétées / total` + jauge.
class QuestSummaryBar extends StatelessWidget {
  const QuestSummaryBar({super.key, required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    return GlassContainer(
      borderRadius: 16,
      tintColor: kGlassBlue,
      tintAlpha: 0.22,
      borderColor: kGlassBlueBorder,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed / $total ${context.tr.quests_status_completed.toLowerCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(kCoinAmber),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}