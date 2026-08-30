import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../providers/quest_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';

import 'coin_icon.dart';
import 'glass_container.dart';
import 'quest_card.dart';
import 'quest_reward_burst.dart';

/// Carte d'une quête quotidienne.
///
/// Même mécanisme que [QuestCard] : lorsque la quête est terminée mais que
/// sa récompense n'a pas encore été réclamée (`isCompleted &&
/// !rewardClaimed`), un point rouge invite le joueur à taper dessus. Le tap
/// déclenche [QuestService.claimDailyReward] ainsi que la même animation de
/// récompense (bounce, halo doré, explosion de particules, texte flottant
/// "+X").
class DailyQuestCard extends ConsumerStatefulWidget {
  const DailyQuestCard({super.key, required this.quest, required this.color});

  final DailyQuestWithProgress quest;
  final Color color;

  @override
  ConsumerState<DailyQuestCard> createState() => DailyQuestCardState();
}

class DailyQuestCardState extends ConsumerState<DailyQuestCard>
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
    final questId = widget.quest.def.id;
    setState(() => _isClaiming = true);
    unawaited(ref.read(hapticsServiceProvider).questRewardClaimed());
    unawaited(ref.read(audioServiceProvider).playQuestRewardClaimed());
    unawaited(AnalyticsService.logEvent(
      'quest_reward_${AnalyticsService.colorEventId(questId)}',
    ));
    await Future.wait([
      _claimController.forward(from: 0),
      ref.read(questServiceProvider).claimDailyReward(questId),
    ]);
    if (mounted) setState(() => _isClaiming = false);
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final color = widget.color;
    final progress = quest.def.targetValue > 0
        ? (quest.currentValue / quest.def.targetValue).clamp(0.0, 1.0)
        : 0.0;
    // Le point rouge et l'invite au tap disparaissent dès que le tap est
    // pris en compte, sans attendre l'aller-retour base de données.
    final showPendingClaimUi = _isPendingClaim && !_isClaiming;
    final fullyClaimed = quest.isCompleted && quest.rewardClaimed;

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
                        child: ClaimedCoinsText(
                          rewardValue: quest.def.rewardValue,
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
                : fullyClaimed
                    ? color.withValues(alpha: 0.5)
                    : kGlassBlueBorder,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            : fullyClaimed
                                ? Icons.check_circle
                                : Icons.flag,
                        color: showPendingClaimUi
                            ? kCoinAmber
                            : fullyClaimed
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        questDescription(context, quest.def.id, quest.def.targetValue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!quest.isCompleted)
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
                      if (!quest.isCompleted) const SizedBox(height: 4),
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
                                : fullyClaimed
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
                                        '${quest.currentValue}/${quest.def.targetValue}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                          ),
                          const SizedBox(width: 8),
                          RewardBadge(
                            rewardType: quest.def.rewardType,
                            rewardValue: quest.def.rewardValue,
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

/// Texte flottant "+X pièces" affiché brièvement au-dessus d'une carte de
/// quête quotidienne lors de la réclamation — équivalent simplifié de
/// [ClaimedRewardText] (toutes les quêtes quotidiennes rapportent des
/// pièces, jamais de déblocage d'amélioration).
class ClaimedCoinsText extends StatelessWidget {
  const ClaimedCoinsText({super.key, required this.rewardValue});

  final int rewardValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoinIcon(size: 18),
        const SizedBox(width: 4),
        Text(
          '+$rewardValue',
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
}