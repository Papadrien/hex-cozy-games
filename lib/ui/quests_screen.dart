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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/game_enums.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/quest_provider.dart';
import '../providers/progression_provider.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import 'glass_container.dart';
import 'coin_icon.dart';
import 'tropical_background.dart';
import 'quest_reward_burst.dart';

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
        _QuestsSummaryBar(completed: completedCount, total: quests.length),
        const SizedBox(height: 20),
        if (grouped.containsKey(QuestCategory.coinsEarned.dbValue))
          _CategorySection(
            iconWidget: const CoinIcon(size: 18),
            color: kCoinAmber,
            label: context.tr.quests_category_coins,
            quests: grouped[QuestCategory.coinsEarned.dbValue]!,
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (grouped.containsKey(QuestCategory.bestGameCoins.dbValue))
          _CategorySection(
            icon: Icons.emoji_events,
            color: kRecordGold,
            label: context.tr.quests_category_record,
            quests: grouped[QuestCategory.bestGameCoins.dbValue]!,
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (grouped.containsKey(QuestCategory.biomesClosed.dbValue))
          _CategorySection(
            icon: Icons.water_drop,
            color: kQuestBlue,
            label: context.tr.quests_category_biomes,
            quests: grouped[QuestCategory.biomesClosed.dbValue]!,
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (_biomeColorQuests(grouped).isNotEmpty)
          _CategorySection(
            icon: Icons.palette,
            color: kBiomeColorQuestPurple,
            label: context.tr.quests_category_biome_colors,
            quests: _biomeColorQuests(grouped),
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (_connectionQuests(grouped).isNotEmpty)
          _CategorySection(
            icon: Icons.hub,
            color: kConnectionOrange,
            label: context.tr.quests_category_connections,
            quests: _connectionQuests(grouped),
            allQuests: quests,
          ),
        const SizedBox(height: 24),
        if (grouped.containsKey(QuestCategory.bestConnectionStreak.dbValue))
          _CategorySection(
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
  /// affichée (point rouge, voir [_QuestCardState._isPendingClaim]).
  List<PermanentQuestRow> _visibleQuests(List<PermanentQuestRow> all) {
    return all
        .where((q) =>
            claimingIds.contains(q.id) || !(q.isCompleted && q.rewardClaimed))
        .where((q) => _computeStatus(q, all) != _QuestStatus.locked)
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

class _QuestsSummaryBar extends StatelessWidget {
  const _QuestsSummaryBar({required this.completed, required this.total});

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

class _CategorySection extends StatelessWidget {
  const _CategorySection({
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

/// Carte d'une quête.
///
/// Lorsque la quête est terminée mais que sa récompense n'a pas encore été
/// réclamée (`isCompleted && !rewardClaimed`), un point rouge invite le
/// joueur à taper dessus. Le tap déclenche [QuestService.claimReward] ainsi
/// qu'une animation de récompense (bounce de la carte, halo doré, explosion
/// de particules, texte flottant "+X").
class _QuestCard extends ConsumerStatefulWidget {
  const _QuestCard({
    required this.quest,
    required this.status,
    required this.color,
  });

  final PermanentQuestRow quest;
  final _QuestStatus status;
  final Color color;

  @override
  ConsumerState<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends ConsumerState<_QuestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _claimController;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _floatAnim;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _claimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.08,
          end: 0.97,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.97,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_claimController);
    _glowAnim = CurvedAnimation(
      parent: _claimController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _floatAnim = CurvedAnimation(
      parent: _claimController,
      curve: const Interval(0.05, 0.9, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _claimController.dispose();
    super.dispose();
  }

  bool get _isPendingClaim =>
      widget.quest.isCompleted && !widget.quest.rewardClaimed;

  Future<void> _handleClaim() async {
    if (!_isPendingClaim || _isClaiming) return;
    buttonTapFeedback(context);
    final questId = widget.quest.id;
    setState(() => _isClaiming = true);
    // Garde la quête visible dans la liste (voir
    // [_QuestsList._visibleQuests]) tant que l'écriture en base et
    // l'animation de récompense ne sont pas toutes les deux terminées —
    // sinon la carte disparaîtrait de la liste dès que `rewardClaimed`
    // passe à vrai en base, en pleine animation.
    ref.read(claimingQuestIdsProvider.notifier).start(questId);
    unawaited(ref.read(hapticsServiceProvider).questRewardClaimed());
    unawaited(ref.read(audioServiceProvider).playQuestRewardClaimed());
    await Future.wait([
      _claimController.forward(from: 0),
      ref.read(questServiceProvider).claimReward(questId),
    ]);
    ref.read(claimingQuestIdsProvider.notifier).finish(questId);
    if (mounted) setState(() => _isClaiming = false);
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final color = widget.color;
    final status = widget.status;
    final progress = quest.targetValue > 0
        ? (quest.currentValue / quest.targetValue).clamp(0.0, 1.0)
        : 0.0;
    // Le point rouge et l'invite au tap disparaissent dès que le tap est
    // pris en compte, sans attendre l'aller-retour base de données.
    final showPendingClaimUi = _isPendingClaim && !_isClaiming;
    final upgradeName = ref.watch(upgradeForQuestProvider(quest.id))?.name;

    return GestureDetector(
      onTap: showPendingClaimUi ? _handleClaim : null,
      child: AnimatedBuilder(
        animation: _claimController,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.scale(scale: _bounceAnim.value, child: child),
              if (_claimController.isAnimating)
                QuestRewardBurst(
                  progress: _floatAnim.value,
                  color: kCoinAmber,
                ),
              if (_claimController.isAnimating)
                Positioned(
                  top: -6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: (1 - _floatAnim.value).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -28 * _floatAnim.value),
                        child: _ClaimedRewardText(
                          quest: quest,
                          upgradeName: upgradeName,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            // Au repos, _claimController vaut 0.0 — indistinguable du tout
            // début d'une animation de réclamation, où glow doit valoir 1.
            // Sans le garde-fou `isAnimating`, chaque carte affichait donc
            // ce halo ambré en continu au lieu de seulement juste après un
            // claim.
            final glow =
                _claimController.isAnimating ? 1 - _glowAnim.value : 0.0;
            return Container(
              decoration: glow > 0
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: kCoinAmber.withValues(alpha: 0.55 * glow),
                          blurRadius: 22 * glow,
                          spreadRadius: 2 * glow,
                        ),
                      ],
                    )
                  : null,
              child: child,
            );
          },
          child: GlassContainer(
            borderRadius: 14,
            tintColor: kGlassBlue,
            tintAlpha: 0.22,
            borderColor: showPendingClaimUi
                ? kCoinAmber.withValues(alpha: 0.7)
                : status == _QuestStatus.completed
                    ? color.withValues(alpha: 0.5)
                    : kGlassBlueBorder,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: showPendingClaimUi
                            ? kCoinAmber.withValues(alpha: 0.22)
                            : color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        showPendingClaimUi
                            ? Icons.card_giftcard
                            : status == _QuestStatus.completed
                                ? Icons.check_circle
                                : Icons.flag,
                        color: showPendingClaimUi
                            ? kCoinAmber
                            : status == _QuestStatus.completed
                                ? color
                                : Colors.white,
                        size: 20,
                      ),
                    ),
                    if (showPendingClaimUi)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: _RedDot(),
                      ),
                  ],
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
                        style: const TextStyle(
                          color: Colors.white,
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
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 6,
                          ),
                        ),
                      if (status != _QuestStatus.completed)
                        const SizedBox(height: 4),
                      // Progress text or completed label
                      Row(
                        children: [
                          Expanded(
                            child: showPendingClaimUi
                                ? Text(
                                    context.tr.quests_tap_to_claim,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: kCoinAmber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : status == _QuestStatus.completed
                                    ? Text(
                                        context.tr.quests_status_completed,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : Text(
                                        '${quest.currentValue}/${quest.targetValue}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                          ),
                          const SizedBox(width: 8),
                          // Reward — ancré à droite
                          _RewardBadge(
                            rewardType: RewardType.fromDb(quest.rewardType),
                            rewardValue: quest.rewardValue,
                            upgradeName: upgradeName,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Petit point rouge de notification — récompense de quête en attente.
class _RedDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 1.5),
      ),
    );
  }
}

/// Texte flottant "+X" (ou icône) affiché brièvement au-dessus de la carte
/// lors de la réclamation d'une récompense.
class _ClaimedRewardText extends StatelessWidget {
  const _ClaimedRewardText({required this.quest, this.upgradeName});

  final PermanentQuestRow quest;
  final String? upgradeName;

  @override
  Widget build(BuildContext context) {
    final rewardType = RewardType.fromDb(quest.rewardType);
    if (rewardType == RewardType.coins) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 18),
          const SizedBox(width: 4),
          Text(
            '+${quest.rewardValue}',
            style: const TextStyle(
              color: kCoinAmber,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(color: Colors.black45, blurRadius: 4),
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome, color: kUpgradePurple, size: 18),
        const SizedBox(width: 4),
        Text(
          upgradeName ?? context.tr.quests_reward_upgrade,
          style: const TextStyle(
            color: kUpgradePurple,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({
    required this.rewardType,
    required this.rewardValue,
    this.upgradeName,
  });

  final RewardType rewardType;
  final int rewardValue;
  final String? upgradeName;

  @override
  Widget build(BuildContext context) {
    if (rewardType == RewardType.coins) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 14),
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

    if (rewardType == RewardType.upgradeUnlock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kUpgradePurple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: kUpgradePurple, size: 14),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                upgradeName ?? context.tr.quests_reward_upgrade,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: kUpgradePurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
