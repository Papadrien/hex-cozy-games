import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/game_enums.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/quest_provider.dart';
import '../providers/progression_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';

import 'coin_icon.dart';
import 'glass_container.dart';
import 'quest_reward_burst.dart';

/// Statut d'affichage d'une quête permanente.
enum QuestStatus { active, completed, locked }

/// Détermine le statut d'une quête : complétée, active, ou verrouillée
/// (prédécesseur de chaîne pas encore complété).
QuestStatus computeQuestStatus(
  PermanentQuestRow quest,
  List<PermanentQuestRow> all,
) {
  if (quest.isCompleted) return QuestStatus.completed;
  final hasIncompletePredecessor =
      all.any((q) => q.nextQuestId == quest.id && !q.isCompleted);
  return hasIncompletePredecessor ? QuestStatus.locked : QuestStatus.active;
}

/// Carte d'une quête.
///
/// Lorsque la quête est terminée mais que sa récompense n'a pas encore été
/// réclamée (`isCompleted && !rewardClaimed`), un point rouge invite le
/// joueur à taper dessus. Le tap déclenche [QuestService.claimReward] ainsi
/// qu'une animation de récompense (bounce de la carte, halo doré, explosion
/// de particules, texte flottant "+X").
class QuestCard extends ConsumerStatefulWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.status,
    required this.color,
  });

  final PermanentQuestRow quest;
  final QuestStatus status;
  final Color color;

  @override
  ConsumerState<QuestCard> createState() => QuestCardState();
}

class QuestCardState extends ConsumerState<QuestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _claimController;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _floatAnim;
  late final Animation<double> _textRiseAnim;
  late final Animation<double> _textFadeAnim;
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
    // Texte de récompense : montée puis disparition en fondu, l'une après
    // l'autre plutôt qu'en parallèle (contrairement à [_floatAnim] qui
    // pilote la burst de particules et reste inchangé). La montée occupe
    // la première moitié de l'animation et se fige ensuite ; le fondu ne
    // démarre qu'à partir de là.
    _textRiseAnim = CurvedAnimation(
      parent: _claimController,
      curve: const Interval(0.05, 0.5, curve: Curves.easeOut),
    );
    _textFadeAnim = CurvedAnimation(
      parent: _claimController,
      curve: const Interval(0.5, 0.95, curve: Curves.easeIn),
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
    final questId = widget.quest.id;
    setState(() => _isClaiming = true);
    // Garde la quête visible dans la liste (voir
    // [QuestsList._visibleQuests]) tant que l'écriture en base et
    // l'animation de récompense ne sont pas toutes les deux terminées —
    // sinon la carte disparaîtrait de la liste dès que `rewardClaimed`
    // passe à vrai en base, en pleine animation.
    ref.read(claimingQuestIdsProvider.notifier).start(questId);
    unawaited(ref.read(hapticsServiceProvider).questRewardClaimed());
    unawaited(ref.read(audioServiceProvider).playQuestRewardClaimed());
    unawaited(AnalyticsService.logEvent(
      'quest_reward_${AnalyticsService.colorEventId(questId)}',
    ));
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
    final linkedUpgrade = ref.watch(upgradeForQuestProvider(quest.id));
    final linkedUpgradeName = linkedUpgrade != null
        ? upgradeName(context, linkedUpgrade.id)
        : null;

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
                      opacity: (1 - _textFadeAnim.value).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -28 * _textRiseAnim.value),
                        child: ClaimedRewardText(
                          quest: quest,
                          upgradeName: linkedUpgradeName,
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
                : status == QuestStatus.completed
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
                            : status == QuestStatus.completed
                                ? Icons.check_circle
                                : Icons.flag,
                        color: showPendingClaimUi
                            ? kCoinAmber
                            : status == QuestStatus.completed
                                ? color
                                : Colors.white,
                        size: 20,
                      ),
                    ),
                    if (showPendingClaimUi)
                      const Positioned(
                        top: -3,
                        right: -3,
                        child: RedDot(),
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
                        questDescription(context, quest.id, quest.targetValue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Progress bar
                      if (status != QuestStatus.completed)
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
                      if (status != QuestStatus.completed)
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
                                : status == QuestStatus.completed
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
                          RewardBadge(
                            rewardType: RewardType.fromDb(quest.rewardType),
                            rewardValue: quest.rewardValue,
                            upgradeName: linkedUpgradeName,
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
class RedDot extends StatelessWidget {
  const RedDot({super.key});

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
class ClaimedRewardText extends StatelessWidget {
  const ClaimedRewardText({super.key, required this.quest, this.upgradeName});

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

/// Badge de récompense ancré à droite de la carte de quête.
class RewardBadge extends StatelessWidget {
  const RewardBadge({
    super.key,
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
