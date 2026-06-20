/// Écran des quêtes permanentes — Story 2.3b.
///
/// Affiche toutes les quêtes (actives, complétées, verrouillées)
/// organisées par catégorie.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/quest_provider.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(permanentQuestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          Str.quests_title,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: questsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, __) => Center(
          child: Text(
            Str.quests_empty,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
        data: (quests) => _QuestsList(quests: quests),
      ),
    );
  }
}

class _QuestsList extends StatelessWidget {
  const _QuestsList({required this.quests});

  final List<PermanentQuestRow> quests;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCategory(quests);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        if (grouped.containsKey('tiles_placed'))
          _CategorySection(
            icon: Icons.grid_on,
            color: const Color(0xFF4CAF50),
            label: Str.quests_category_tiles,
            quests: grouped['tiles_placed']!,
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (grouped.containsKey('village_size'))
          _CategorySection(
            icon: Icons.home,
            color: const Color(0xFFE57373),
            label: Str.quests_category_village,
            quests: grouped['village_size']!,
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (grouped.containsKey('biomes_closed'))
          _CategorySection(
            icon: Icons.water_drop,
            color: const Color(0xFF64B5F6),
            label: Str.quests_category_biomes,
            quests: grouped['biomes_closed']!,
            allQuests: quests,
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Map<String, List<PermanentQuestRow>> _groupByCategory(
    List<PermanentQuestRow> quests,
  ) {
    final map = <String, List<PermanentQuestRow>>{};
    for (final q in quests) {
      map.putIfAbsent(q.category, () => []).add(q);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.targetValue.compareTo(b.targetValue));
    }
    return map;
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.icon,
    required this.color,
    required this.label,
    required this.quests,
    required this.allQuests,
  });

  final IconData icon;
  final Color color;
  final String label;
  final List<PermanentQuestRow> quests;
  final List<PermanentQuestRow> allQuests;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...quests.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _QuestCard(
                quest: q,
                status: _computeStatus(q, allQuests),
                color: color,
              ),
            )),
      ],
    );
  }
}

enum _QuestStatus { active, completed, locked }

_QuestStatus _computeStatus(
  PermanentQuestRow quest,
  List<PermanentQuestRow> all,
) {
  if (quest.isCompleted) return _QuestStatus.completed;
  final hasIncompletePredecessor =
      all.any((q) => q.nextQuestId == quest.id && !q.isCompleted);
  return hasIncompletePredecessor ? _QuestStatus.locked : _QuestStatus.active;
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.status,
    required this.color,
  });

  final PermanentQuestRow quest;
  final _QuestStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = quest.targetValue > 0
        ? (quest.currentValue / quest.targetValue).clamp(0.0, 1.0)
        : 0.0;
    final isLocked = status == _QuestStatus.locked;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isLocked ? 0.03 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == _QuestStatus.completed
              ? color.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isLocked
                  ? Colors.white.withValues(alpha: 0.08)
                  : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isLocked
                  ? Icons.lock
                  : status == _QuestStatus.completed
                      ? Icons.check_circle
                      : Icons.flag,
              color: isLocked
                  ? Colors.white.withValues(alpha: 0.4)
                  : status == _QuestStatus.completed
                      ? color
                      : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  quest.description,
                  style: TextStyle(
                    color: isLocked
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                // Progress bar
                if (status != _QuestStatus.completed)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLocked
                            ? Colors.white.withValues(alpha: 0.25)
                            : color,
                      ),
                      minHeight: 6,
                    ),
                  ),
                if (status != _QuestStatus.completed)
                  const SizedBox(height: 4),
                // Progress text or completed label
                Row(
                  children: [
                    if (status == _QuestStatus.completed)
                      Text(
                        Str.quests_status_completed,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        isLocked
                            ? Str.quests_status_locked
                            : '${quest.currentValue}/${quest.targetValue}',
                        style: TextStyle(
                          color: isLocked
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    const Spacer(),
                    // Reward
                    _RewardBadge(rewardType: quest.rewardType, rewardValue: quest.rewardValue),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.rewardType, required this.rewardValue});

  final String rewardType;
  final int rewardValue;

  @override
  Widget build(BuildContext context) {
    if (rewardType == 'coins') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
            const SizedBox(width: 3),
            Text(
              '+$rewardValue',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (rewardType == 'upgrade_unlock') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFCE93D8).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: const Color(0xFFCE93D8), size: 14),
            const SizedBox(width: 3),
            Text(
              Str.quests_reward_upgrade,
              style: const TextStyle(
                color: Color(0xFFCE93D8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
