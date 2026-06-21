import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors.dart';
import '../core/game_enums.dart';
import '../core/constants.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/build_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/player_profile_provider.dart';
import '../providers/progression_provider.dart';
import '../services/ad_service.dart';
import 'build_screen.dart';
import 'quests_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);
    final totalCoins = ref.watch(totalCoinsProvider);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(totalCoins: totalCoins),
            const Spacer(),
            _CenterContent(
              activeSession: activeSession,
              onPlay: () {
                SessionSaver.endSession(ref);
                startNewGame(ref);
                Navigator.pushReplacementNamed(context, '/game');
              },
              onResume: () async {
                await restoreSession(ref);
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/game');
                }
              },
            ),
            if (!kReleaseMode) _DebugButton(ref: ref),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Bandeau supérieur sobre : pièces totales + accès Réglages + Boutique.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.totalCoins});

  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on,
                    color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$totalCoins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _IconButton(
            icon: Icons.settings,
            tooltip: context.tr.home_settings,
            onPressed: () => _notYet(context, context.tr.home_settings),
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.store,
            tooltip: context.tr.home_shop,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _notYet(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Bouton debug : débloque toutes les améliorations (mode debug uniquement).
class _DebugButton extends StatelessWidget {
  const _DebugButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextButton.icon(
        icon: const Icon(Icons.build, color: Colors.amber, size: 18),
        style: TextButton.styleFrom(
          foregroundColor: Colors.amber.withValues(alpha: 0.6),
        ),
        label: const Text('DEBUG : tout débloquer'),
        onPressed: () async {
          await ref.read(progressionServiceProvider).unlockAllUpgrades();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Toutes les améliorations débloquées')),
            );
          }
        },
      ),
    );
  }
}

/// Bouton icône arrondi pour la barre du haut.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon,
                color: Colors.white.withValues(alpha: 0.7), size: 22),
          ),
        ),
      ),
    );
  }
}

/// Contenu central : titre + bouton Jouer/Reprendre + build + accès.
class _CenterContent extends ConsumerStatefulWidget {
  const _CenterContent({
    required this.activeSession,
    required this.onPlay,
    required this.onResume,
  });

  final AsyncValue<bool> activeSession;
  final VoidCallback onPlay;
  final Future<void> Function() onResume;

  @override
  ConsumerState<_CenterContent> createState() => _CenterContentState();
}

class _CenterContentState extends ConsumerState<_CenterContent>
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
    // Attendre le premier frame pour que le contexte soit monté
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hex Cozy Games',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 36),
            // ── Bouton Jouer / Reprendre ────────────────────────────────────
            SizedBox(
              width: 200,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [kBrandTurquoise, kSeaTurquoise],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kBrandTurquoise.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                onPressed: widget.activeSession.when(
                  loading: () => null,
                  data: (active) => active ? widget.onResume : widget.onPlay,
                  error: (_, _) => widget.onPlay,
                ),
                child: widget.activeSession.when(
                  loading: () => const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  data: (active) => Text(
                    active ? context.tr.home_resume : context.tr.home_play,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  error: (_, _) => Text(
                    context.tr.home_play,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            ),
            const SizedBox(height: 12),
            // ── Bouton Build (sélection des améliorations) ──────────────────
            _BuildButton(selected: selected),
            const SizedBox(height: 16),
            // ── Bouton Pub Rewarded ou Pièces Quotidiennes Premium ─────────
            if (isPremium)
              _PremiumDailyCoinsButton(
                animController: _animController,
              )
            else
              _RewardedAdButton(),
            const SizedBox(height: 24),
            // ── Accès Quêtes et Statistiques ─────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavButton(
                  icon: Icons.flag_outlined,
                  label: context.tr.quests_title,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const QuestsScreen()),
                  ),
                ),
                const SizedBox(width: 16),
                _NavButton(
                  icon: Icons.bar_chart_outlined,
                  label: context.tr.home_stats,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StatsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // ── Animation pièces créditées ──────────────────────────────────────
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
                  Icon(Icons.monetization_on,
                      color: Colors.amber, size: 28),
                  SizedBox(width: 6),
                  Text(
                    '+50',
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

/// Bouton pub rewarded (non-premium).
class _RewardedAdButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adAvailable = ref.watch(isDailyRewardAvailableProvider);

    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        foregroundColor: Colors.white,
        backgroundColor: adAvailable
            ? Colors.amber.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: adAvailable
                ? Colors.amber.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      icon: Icon(
        adAvailable ? Icons.play_circle_outline : Icons.check_circle_outline,
        size: 20,
        color: adAvailable
            ? Colors.amber
            : Colors.white.withValues(alpha: 0.4),
      ),
      label: Text(
        adAvailable
            ? context.tr.ads_watchForCoins
            : context.tr.ads_comeBackTomorrow,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: adAvailable
              ? Colors.amber.shade200
              : Colors.white.withValues(alpha: 0.4),
        ),
      ),
      onPressed: adAvailable
          ? () async {
              final rewarded = await claimDailyReward(ref);
              if (rewarded && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '+$kAdRewardedCoins ${context.tr.reward_coins}'),
                    backgroundColor: Colors.green.withValues(alpha: 0.3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          : null,
    );
  }
}

/// Bouton pièces quotidiennes premium (remplace la pub pour les premium).
class _PremiumDailyCoinsButton extends ConsumerWidget {
  const _PremiumDailyCoinsButton({required this.animController});

  final AnimationController animController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(isPremiumDailyCoinsAvailableProvider);

    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        foregroundColor: Colors.white,
        backgroundColor: available
            ? kUpgradePurple.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: available
                ? kUpgradePurple.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      icon: Icon(
        available ? Icons.monetization_on : Icons.check_circle_outline,
        size: 20,
        color: available
            ? Colors.amber
            : Colors.white.withValues(alpha: 0.4),
      ),
      label: Text(
        available
            ? context.tr.premium_dailyCoinsButton
            : context.tr.ads_comeBackTomorrow,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: available
              ? Colors.amber.shade200
              : Colors.white.withValues(alpha: 0.4),
        ),
      ),
      onPressed: available
          ? () async {
              final claimed = await claimPremiumDailyCoins(ref);
              if (claimed && context.mounted) {
                animController.forward().then((_) {
                  Future.delayed(const Duration(seconds: 2), () {
                    if (context.mounted) animController.reverse();
                  });
                });
              }
            }
          : null,
    );
  }
}

/// Petit bouton d'accès (quêtes / stats).
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        foregroundColor: Colors.white.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Bouton Build affichant les icônes des améliorations sélectionnées.
class _BuildButton extends StatelessWidget {
  const _BuildButton({required this.selected});

  final List<UpgradeRow> selected;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        foregroundColor: Colors.white.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BuildScreen()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.build_outlined, size: 18,
                      color: Colors.white.withValues(alpha: 0.5)),
                )
              else
                ...selected.map((u) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _BuildMiniIcon(
                        effectType: UpgradeEffectType.fromDb(u.effectType),
                      ),
                    )),
            ],
          ),
          Text(
            selected.isEmpty
                ? context.tr.home_buildSelection
                : '${selected.length} / $kMaxSelectedUpgrades',
            style: GoogleFonts.nunito(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Petit cercle icône d'une amélioration dans le bouton build.
class _BuildMiniIcon extends StatelessWidget {
  const _BuildMiniIcon({required this.effectType});

  final UpgradeEffectType effectType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: kBrandBlue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        upgradeIconData(effectType),
        color: kBrandBlue,
        size: 14,
      ),
    );
  }
}
