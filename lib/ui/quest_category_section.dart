import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'quest_card.dart';

/// Section d'une catégorie de quêtes permanentes : en-tête coloré avec
/// compteur `complétées / total`, puis la liste des [QuestCard] de la
/// catégorie.
class QuestCategorySection extends StatelessWidget {
  const QuestCategorySection({
    super.key,
    this.icon,
    this.iconWidget,
    required this.color,
    required this.label,
    required this.quests,
    required this.allQuests,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;

  /// Widget d'icône personnalisé (ex. logo pièce) — prioritaire sur [icon].
  final Widget? iconWidget;
  final Color color;
  final String label;
  final List<PermanentQuestRow> quests;
  final List<PermanentQuestRow> allQuests;

  @override
  Widget build(BuildContext context) {
    final completedInCategory = quests.where((q) => q.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              iconWidget ?? Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Text(
                '$completedInCategory/${quests.length}',
                style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...quests.map((q) => Padding(
              key: ValueKey(q.id),
              padding: const EdgeInsets.only(bottom: 8),
              child: QuestCard(
                quest: q,
                status: computeQuestStatus(q, allQuests),
                color: color,
              ),
            )),
      ],
    );
  }
}