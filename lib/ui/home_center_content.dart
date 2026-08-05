import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/page_transitions.dart';
import '../core/snackbar_utils.dart';
import '../core/strings.dart';
import '../providers/build_provider.dart';
import '../providers/player_profile_provider.dart';
import '../providers/quest_provider.dart';
import '../services/ad_service.dart';
import '../services/haptics_service.dart';
import 'coin_icon.dart';
import 'home_ad_buttons.dart';
import 'home_build_button.dart';
import 'home_nav_button.dart';
import 'home_play_button.dart';
import 'quests_screen.dart';
import 'stats_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONTENU CENTRAL  —  sans titre, commence directement par le bouton Jouer
// ─────────────────────────────────────────────────────────────────────────────

class HomeCenterContent extends ConsumerStatefulWidget {
  const HomeCenterContent({
    super.key,
    required this.activeSession,
    required this.onPlay,
    required this.onResume,
  });

  final AsyncValue<bool> activeSession;
  final Future<void> Function() onPlay;
  final Future<void> Function() onResume;

  @override
  ConsumerState<HomeCenterContent> createState() => _HomeCenterContentState();
}

class _HomeCenterContentState extends ConsumerState<HomeCenterContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: const ElasticOutCurve(0.8),
    );
    _opacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0, 0.3, curve: Curves.easeOut),
      ),
    );
    _autoClaimPremium();
  }

  Future<void> _autoClaimPremium() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final claimed = await claimPremiumDailyCoins(ref);
    if (claimed && mounted) {
      _animController.forward().then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _animController.reverse();
        });
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedUpgradesProvider);
    final isPremium = ref.watch(playerProfileProvider).maybeWhen(
          data: (r) => r.isPremium,
          orElse: () => false,
        );
    final hasUnclaimedQuest = ref.watch(hasUnclaimedQuestProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Bouton Jouer principal ─────────────────────────────────────
              HomePlayButton(
                activeSession: widget.activeSession,
                onPlay: widget.onPlay,
                onResume: widget.onResume,
              ),
              const SizedBox(height: 14),

              // ── Bouton Build ───────────────────────────────────────────────
              HomeBuildButton(
                selected: selected,
                activeSession: widget.activeSession,
              ),
              const SizedBox(height: 10),

              // ── Bouton Pub / Premium ───────────────────────────────────────
              if (isPremium)
                HomePremiumDailyCoinsButton(animController: _animController)
              else
                const HomeRewardedAdButton(),
              const SizedBox(height: 14),

              // ── Quêtes + Statistiques ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: HomeNavButton(
                      icon: Icons.flag_outlined,
                      label: context.tr.quests_title,
                      showBadge: hasUnclaimedQuest,
                      onTap: () {
                        buttonTapFeedback(context);
                        clearAppSnackBars();
                        Navigator.of(context).push(
                          BlurFadePageRoute<void>(
                              builder: (_) => const QuestsScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HomeNavButton(
                      icon: Icons.bar_chart_outlined,
                      label: context.tr.home_stats,
                      onTap: () {
                        buttonTapFeedback(context);
                        clearAppSnackBars();
                        Navigator.of(context).push(
                          BlurFadePageRoute<void>(
                              builder: (_) => const StatsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Animation pièces créditées ─────────────────────────────────────
        if (_animController.isAnimating || _animController.value > 0)
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnim.value * (1 - _animController.value),
                  child: Transform.scale(
                    scale: 1 + (1 - _scaleAnim.value) * 0.5,
                    child: child,
                  ),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CoinIcon(size: 28),
                  SizedBox(width: 6),
                  Text(
                    '+$kAdRewardedCoins',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}