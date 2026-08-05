import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../providers/quest_provider.dart';
import 'daily_quest_card.dart';

/// Section des quêtes quotidiennes (Story 2.4a/2.4b) — même mécanisme de
/// déblocage de récompense que les quêtes permanentes : tap requis, son,
/// et point rouge sur la carte (et sur le bouton "Quêtes" de l'accueil)
/// tant que la récompense n'a pas été réclamée (voir
/// [QuestService.claimDailyReward]).
class DailyQuestsSection extends ConsumerWidget {
  const DailyQuestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyQuests = ref.watch(todayDailyQuestsProvider);
    if (dailyQuests.isEmpty) return const SizedBox.shrink();

    final completedCount = dailyQuests.where((q) => q.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kQuestBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.today, color: kQuestBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr.quests_category_daily,
                  style: const TextStyle(
                    color: kQuestBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Text(
                '$completedCount/${dailyQuests.length}',
                style: TextStyle(
                  color: kQuestBlue.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...dailyQuests.map((q) => Padding(
              key: ValueKey(q.def.id),
              padding: const EdgeInsets.only(bottom: 8),
              child: DailyQuestCard(quest: q, color: kQuestBlue),
            )),
      ],
    );
  }
}