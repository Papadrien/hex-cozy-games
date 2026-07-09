import 'dart:ui';

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
import '../services/haptics_service.dart';
import 'build_screen.dart';
import 'quests_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';
import 'glass_container.dart';

// Bleu nuit tealisé pour les boutons secondaires — foncé pour la lisibilité
// du texte blanc, bordure teal assortie au bouton Jouer.
const Color _kGlassBlue = Color(0xFF2E3B52);
const Color _kGlassBlueBorder = Color(0xFF3DBFAF);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);
    final totalCoins = ref.watch(totalCoinsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fond tropical plein écran ──────────────────────────────────────
          Image.asset(
            'assets/images/home_background.png',
            fit: BoxFit.cover,
          ),
          // ── Titre à 20 % de la hauteur écran ──────────────────────────────
          Builder(
            builder: (context) {
              final screenHeight = MediaQuery.sizeOf(context).height;
              return Positioned(
                top: screenHeight * 0.20,
                left: 0,
                right: 0,
                child: const _HexHavenTitle(),
              );
            },
          ),
          // ── Contenu ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _TopBar(totalCoins: totalCoins),
                const Spacer(),
                _CenterContent(
                  activeSession: activeSession,
                  onPlay: () async {
                    await SessionSaver.endSession(ref);
                    startNewGame(ref);
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/game');
                    }
                  },
                  onResume: () async {
                    await restoreSession(ref);
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/game');
                    }
                  },
                ),
                if (!kReleaseMode) _DebugButton(ref: ref),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR  —  badge pièces · icônes settings/shop
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.totalCoins});

  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Badge pièces
          _GlassPill(
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
          _GlassIconButton(
            icon: Icons.settings,
            tooltip: context.tr.home_settings,
            onPressed: () {
              buttonHapticTap(context);
              _notYet(context, context.tr.home_settings);
            },
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            icon: Icons.store,
            tooltip: context.tr.home_shop,
            onPressed: () {
              buttonHapticTap(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
              );
            },
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

// ─────────────────────────────────────────────────────────────────────────────
// TITRE HEX HAVEN  —  maintenant dans la TopBar
// ─────────────────────────────────────────────────────────────────────────────

class _HexHavenTitle extends StatelessWidget {
  const _HexHavenTitle();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "hex" + fleur
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'hex',
                  style: GoogleFonts.nunito(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
                  child: Image.asset(
                    'assets/images/hibiscus.png',
                    width: 64,
                    height: 64,
                  ),
                ),
              ],
            ),
            // "Haven" en cursif teal
            Text(
              'Haven',
              style: GoogleFonts.pacifico(
                fontSize: 48,
                color: kTropicalTeal,
                height: 0.9,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTENU CENTRAL  —  sans titre, commence directement par le bouton Jouer
// ─────────────────────────────────────────────────────────────────────────────

class _CenterContent extends ConsumerStatefulWidget {
  const _CenterContent({
    required this.activeSession,
    required this.onPlay,
    required this.onResume,
  });

  final AsyncValue<bool> activeSession;
  final Future<void> Function() onPlay;
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Bouton Jouer principal ─────────────────────────────────────
              _PlayButton(
                activeSession: widget.activeSession,
                onPlay: widget.onPlay,
                onResume: widget.onResume,
              ),
              const SizedBox(height: 14),

              // ── Bouton Build ───────────────────────────────────────────────
              _BuildButton(
                selected: selected,
                activeSession: widget.activeSession,
              ),
              const SizedBox(height: 10),

              // ── Bouton Pub / Premium ───────────────────────────────────────
              if (isPremium)
                _PremiumDailyCoinsButton(animController: _animController)
              else
                _RewardedAdButton(),
              const SizedBox(height: 14),

              // ── Quêtes + Statistiques ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _NavButton(
                      icon: Icons.flag_outlined,
                      label: context.tr.quests_title,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const QuestsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NavButton(
                      icon: Icons.bar_chart_outlined,
                      label: context.tr.home_stats,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const StatsScreen()),
                      ),
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
                  Icon(Icons.monetization_on, color: Colors.amber, size: 28),
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

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON JOUER PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.activeSession,
    required this.onPlay,
    required this.onResume,
  });

  final AsyncValue<bool> activeSession;
  final Future<void> Function() onPlay;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    final label = activeSession.when(
      loading: () => null,
      data: (active) => active ? context.tr.home_resume : context.tr.home_play,
      error: (_, _) => context.tr.home_play,
    );
    final onTap = activeSession.when(
      loading: () => null,
      data: (active) => active ? onResume : onPlay,
      error: (_, _) => onPlay,
    );

    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Bouton principal
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Material(
                color: kTropicalTeal.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: onTap == null
                      ? null
                      : () async {
                          buttonHapticTap(context);
                          await onTap();
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      // Alpha relevé (0.3 -> 0.85) : à faible opacité, un
                      // liseré blanc posé sur le fond teal du bouton se
                      // teintait visuellement de vert au lieu de lire comme
                      // blanc. Épaisseur doublée (1.5 -> 3) pour rester
                      // cohérent avec les autres contours glassmorphism.
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: label == null
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              label,
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Fleur hibiscus qui déborde à gauche
          Positioned(
            left: -8,
            top: -20,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/hibiscus.png',
                width: 72,
                height: 72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON GLASS RÉUTILISABLE  —  teinte bleu glacier
// ─────────────────────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.child,
    required this.onPressed,
    this.tint = Colors.transparent,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color tint;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      tintColor: _kGlassBlue,
      tintAlpha: 0.18,
      borderColor: _kGlassBlueBorder.withValues(alpha: 0.38),
      borderRadius: 16,
      padding: padding,
      blurSigma: 10,
      onTap: onPressed,
      child: tint == Colors.transparent
          ? child
          : Stack(
              children: [
                child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON BUILD
// ─────────────────────────────────────────────────────────────────────────────

class _BuildButton extends StatelessWidget {
  const _BuildButton({required this.selected, required this.activeSession});

  final List<UpgradeRow> selected;
  final AsyncValue<bool> activeSession;

  @override
  Widget build(BuildContext context) {
    // Tant qu'une partie est à reprendre, on empêche l'accès à la sélection
    // d'améliorations : le choix d'améliorations ne s'applique qu'à une
    // nouvelle partie et ne doit pas pouvoir être modifié pendant qu'une
    // partie en cours attend d'être reprise.
    final hasResumableGame =
        activeSession.maybeWhen(data: (active) => active, orElse: () => false);

    return SizedBox(
      width: double.infinity,
      child: _GlassButton(
        // Pas de surcouche — le bleu de base suffit pour ce bouton
        tint: hasResumableGame ? Colors.grey : Colors.transparent,
        onPressed: hasResumableGame
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr.home_buildSelectionLockedResume),
                    behavior: SnackBarBehavior.floating,
                  ),
                )
            : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BuildScreen()),
                ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected.isEmpty)
              Icon(
                Icons.build_outlined,
                size: 18,
                color: hasResumableGame
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
              )
            else
              ...selected.map((u) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Opacity(
                      opacity: hasResumableGame ? 0.4 : 1,
                      child: _BuildMiniIcon(
                        effectType: UpgradeEffectType.fromDb(u.effectType),
                      ),
                    ),
                  )),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selected.isEmpty
                    ? context.tr.home_buildSelection
                    : '${selected.length} / $kMaxSelectedUpgrades ${context.tr.home_buildSelection}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.nunito(
                  color: hasResumableGame
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON PUB REWARDED
// ─────────────────────────────────────────────────────────────────────────────

class _RewardedAdButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adAvailable = ref.watch(isDailyRewardAvailableProvider);

    return SizedBox(
      width: double.infinity,
      child: _GlassButton(
        tint: adAvailable ? Colors.amber : Colors.grey,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              adAvailable
                  ? Icons.play_circle_outline
                  : Icons.check_circle_outline,
              size: 20,
              color: adAvailable
                  ? Colors.amber
                  : Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              adAvailable
                  ? context.tr.ads_watchForCoins
                  : context.tr.ads_comeBackTomorrow,
              style: GoogleFonts.nunito(
                color: adAvailable
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON PIÈCES QUOTIDIENNES PREMIUM
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumDailyCoinsButton extends ConsumerWidget {
  const _PremiumDailyCoinsButton({required this.animController});

  final AnimationController animController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(isPremiumDailyCoinsAvailableProvider);

    return SizedBox(
      width: double.infinity,
      child: _GlassButton(
        tint: available ? kUpgradePurple : Colors.grey,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              available ? Icons.monetization_on : Icons.check_circle_outline,
              size: 20,
              color: available
                  ? Colors.amber
                  : Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              available
                  ? context.tr.premium_dailyCoinsButton
                  : context.tr.ads_comeBackTomorrow,
              style: GoogleFonts.nunito(
                color: available
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON NAV (Quêtes / Stats)
// ─────────────────────────────────────────────────────────────────────────────

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
    return _GlassButton(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSANTS UTILITAIRES
// ─────────────────────────────────────────────────────────────────────────────

/// Pill glassmorphism (badge pièces)
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      tintColor: _kGlassBlue,
      tintAlpha: 0.22,
      borderColor: _kGlassBlueBorder.withValues(alpha: 0.40),
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      blurSigma: 10,
      child: child,
    );
  }
}

/// Bouton icône glassmorphism pour la top bar
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
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
      child: GlassContainer(
        tintColor: _kGlassBlue,
        tintAlpha: 0.22,
        borderColor: _kGlassBlueBorder.withValues(alpha: 0.40),
        borderRadius: 14,
        padding: const EdgeInsets.all(10),
        onTap: onPressed,
        blurSigma: 10,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

/// Mini icône d'amélioration dans le bouton Build
class _BuildMiniIcon extends StatelessWidget {
  const _BuildMiniIcon({required this.effectType});

  final UpgradeEffectType effectType;

  @override
  Widget build(BuildContext context) {
    final tintOverride = upgradeIconColor(effectType);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        upgradeIconData(effectType),
        color: tintOverride ?? Colors.white,
        size: 14,
      ),
    );
  }
}

/// Bouton DEBUG (mode debug uniquement)
class _DebugButton extends StatelessWidget {
  const _DebugButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 8),
      child: TextButton.icon(
        icon: const Icon(Icons.build, color: Colors.amber, size: 18),
        style: TextButton.styleFrom(
          foregroundColor: Colors.amber.withValues(alpha: 0.6),
        ),
        label: const Text('DEBUG : tout débloquer'),
        onPressed: () async {
          buttonHapticTap(context);
          await ref.read(progressionServiceProvider).unlockAllUpgrades();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Toutes les améliorations débloquées')),
            );
          }
        },
      ),
    );
  }
}
