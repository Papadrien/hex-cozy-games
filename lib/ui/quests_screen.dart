/// Écran des quêtes permanentes — Story 2.3b.
///
/// Affiche les quêtes actives et complétées (en attente de réclamation),
/// organisées par catégorie. Les quêtes verrouillées (prédécesseur de
/// chaîne pas encore complété) restent invisibles — pas de cadenas —
/// jusqu'à leur déblocage ; les quêtes entièrement terminées (récompense
/// réclamée) disparaissent de la liste une fois leur animation de
/// réclamation terminée (voir [_QuestsList._visibleQuests] et
/// [claimingQuestIdsProvider]).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/game_enums.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/quest_provider.dart';
import '../services/haptics_service.dart';
import 'coin_icon.dart';
import 'daily_quest_section.dart';
import 'glass_container.dart';
import 'quest_card.dart';
import 'quest_category_section.dart';
import 'quest_summary_bar.dart';
import 'tropical_background.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(permanentQuestsProvider);
    final claimingIds = ref.watch(claimingQuestIdsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: TropicalBackground(
        child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuestsAppBar(),
                Expanded(
                  child: questsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (_, _) => Center(
                      child: Text(
                        context.tr.quests_empty,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    data: (quests) => _QuestsList(
                      quests: quests,
                      claimingIds: claimingIds,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _QuestsList extends StatelessWidget {
  const _QuestsList({required this.quests, required this.claimingIds});

  final List<PermanentQuestRow> quests;

  /// IDs des quêtes actuellement en cours de réclamation (voir
  /// [claimingQuestIdsProvider]) — restent visibles même si déjà marquées
  /// réclamées en base, le temps que leur animation se termine.
  final Set<String> claimingIds;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCategory(_visibleQuests(quests));
    final completedCount = quests.where((q) => q.isCompleted).length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        QuestSummaryBar(completed: completedCount, total: quests.length),
        const SizedBox(height: 20),
        const DailyQuestsSection(),
        const SizedBox(height: 24),
        if (grouped.containsKey(QuestCategory.coinsEarned.dbValue))
          QuestCategorySection(
            iconWidget: const CoinIcon(size: 18),
            color: kCoinAmber,
            label: context.tr.quests_category_coins,
            quests: grouped[QuestCategory.coinsEarned.dbValue]!,
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (grouped.containsKey(QuestCategory.bestGameCoins.dbValue))
          QuestCategorySection(
            icon: Icons.emoji_events,
            color: kRecordGold,
            label: context.tr.quests_category_record,
            quests: grouped[QuestCategory.bestGameCoins.dbValue]!,
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (grouped.containsKey(QuestCategory.biomesClosed.dbValue))
          QuestCategorySection(
            icon: Icons.water_drop,
            color: kQuestBlue,
            label: context.tr.quests_category_biomes,
            quests: grouped[QuestCategory.biomesClosed.dbValue]!,
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (_biomeColorQuests(grouped).isNotEmpty)
          QuestCategorySection(
            icon: Icons.palette,
            color: kBiomeColorQuestPurple,
            label: context.tr.quests_category_biome_colors,
            quests: _biomeColorQuests(grouped),
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (_connectionQuests(grouped).isNotEmpty)
          QuestCategorySection(
            icon: Icons.hub,
            color: kConnectionOrange,
            label: context.tr.quests_category_connections,
            quests: _connectionQuests(grouped),
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (grouped.containsKey(QuestCategory.bestConnectionStreak.dbValue))
          QuestCategorySection(
            icon: Icons.local_fire_department,
            color: kSuccessGreen,
            label: context.tr.quests_category_streak,
            quests: grouped[QuestCategory.bestConnectionStreak.dbValue]!,
            allQuests: quests,
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  /// Rassemble les quêtes de connexions (triple/quadruple/quintuple/
  /// sextuple) dans un seul groupe affiché sous une même section, dans
  /// l'ordre croissant du nombre de côtés connectés.
  ///
  /// Pour triple/quad/quint, la catégorie contient à la fois la quête
  /// one-shot de déblocage (ex. `connections_triple_first`) et la quête
  /// répétable de farm (ex. `connections_triple`) — les deux s'affichaient
  /// en double. On n'affiche que la quête de déblocage tant que sa
  /// récompense n'a pas été réclamée (objectif courant, y compris le temps
  /// que le joueur tape sur le point rouge), puis on bascule sur la quête
  /// répétable une fois la récompense réclamée. Sextuple n'a pas de
  /// variante one-shot : elle s'affiche telle quelle.
  List<PermanentQuestRow> _connectionQuests(
    Map<String, List<PermanentQuestRow>> grouped,
  ) {
    return [
      ..._dedupedConnectionCategory(
        grouped,
        QuestCategory.tripleConnections.dbValue,
        'connections_triple_first',
      ),
      ..._dedupedConnectionCategory(
        grouped,
        QuestCategory.quadConnections.dbValue,
        'connections_quad_first',
      ),
      ..._dedupedConnectionCategory(
        grouped,
        QuestCategory.quintConnections.dbValue,
        'connections_quint_first',
      ),
      ...?grouped[QuestCategory.sextConnections.dbValue],
    ];
  }

  /// Choisit une seule quête à afficher pour une catégorie de connexions
  /// qui contient à la fois une quête one-shot ([oneShotId]) et une quête
  /// répétable de farm.
  List<PermanentQuestRow> _dedupedConnectionCategory(
    Map<String, List<PermanentQuestRow>> grouped,
    String category,
    String oneShotId,
  ) {
    final quests = grouped[category] ?? const [];
    PermanentQuestRow? oneShot;
    PermanentQuestRow? repeatable;
    for (final q in quests) {
      if (q.id == oneShotId) {
        oneShot = q;
      } else {
        repeatable = q;
      }
    }
    // On continue d'afficher la quête one-shot tant que sa récompense n'a
    // pas été réclamée (même complétée), ou tant que son animation de
    // réclamation est en cours ([claimingIds]) : sinon le point rouge du
    // bouton "Quêtes" (piloté par isCompleted && !rewardClaimed) reste
    // allumé alors qu'aucune quête n'apparaît plus comme terminée dans la
    // liste, ou la carte bascule vers la répétable en pleine animation.
    if (oneShot != null &&
        (claimingIds.contains(oneShot.id) ||
            !(oneShot.isCompleted && oneShot.rewardClaimed))) {
      return [oneShot];
    }
    if (repeatable != null) return [repeatable];
    if (oneShot != null) return [oneShot];
    return const [];
  }

  /// Rassemble les 5 quêtes "cluster couleur" (rouge/village + forêt/eau/
  /// plaine/montagne) dans un seul groupe affiché sous une même section —
  /// même principe que [_connectionQuests]. Le village (rouge) rejoint ici
  /// les autres couleurs, dont il partage exactement le même mécanisme
  /// (plus grand amas connecté > 50 tuiles).
  List<PermanentQuestRow> _biomeColorQuests(
    Map<String, List<PermanentQuestRow>> grouped,
  ) {
    return [
      ...?grouped[QuestCategory.villageSize.dbValue],
      ...?grouped[QuestCategory.forestClusterSize.dbValue],
      ...?grouped[QuestCategory.waterClusterSize.dbValue],
      ...?grouped[QuestCategory.plainClusterSize.dbValue],
      ...?grouped[QuestCategory.mountainClusterSize.dbValue],
    ];
  }

  /// Quêtes affichées dans la liste : les quêtes verrouillées (prédécesseur
  /// de chaîne pas encore complété) restent invisibles — pas de cadenas —
  /// et apparaissent dès qu'elles se débloquent ; les quêtes entièrement
  /// terminées (récompense déjà réclamée) sont masquées pour ne pas
  /// encombrer la liste, sauf si leur animation de réclamation est encore
  /// en cours ([claimingIds]) — sans ce garde-fou, la carte disparaîtrait
  /// de la liste dès l'écriture en base, en pleine animation. Une quête
  /// complétée mais dont la récompense n'a pas encore été réclamée reste
  /// affichée (point rouge, voir [QuestCardState._isPendingClaim]).
  List<PermanentQuestRow> _visibleQuests(List<PermanentQuestRow> all) {
    return all
        .where((q) =>
            claimingIds.contains(q.id) || !(q.isCompleted && q.rewardClaimed))
        .where((q) => computeQuestStatus(q, all) != QuestStatus.locked)
        .toList();
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

class _QuestsAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _QuestsGlassIconButton(
            icon: Icons.close,
            onPressed: () {
              buttonTapFeedback(context);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 14),
          Text(
            context.tr.quests_title,
            style: TextStyle(
              fontFamily: 'Nunito',
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

class _QuestsGlassIconButton extends StatelessWidget {
  const _QuestsGlassIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      tintColor: kGlassBlue,
      tintAlpha: 0.22,
      borderColor: kGlassBlueBorder,
      padding: const EdgeInsets.all(10),
      onTap: onPressed,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
