import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_enums.dart';
import '../core/constants.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/build_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/player_profile_provider.dart';
import '../providers/progression_provider.dart';
import 'build_screen.dart';
import 'quests_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);
    final totalCoins = ref.watch(totalCoinsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
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
            tooltip: Str.home_settings,
            onPressed: () => _notYet(context, Str.home_settings),
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.store,
            tooltip: Str.home_shop,
            onPressed: () => _notYet(context, Str.home_shop),
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
class _CenterContent extends ConsumerWidget {
  const _CenterContent({
    required this.activeSession,
    required this.onPlay,
    required this.onResume,
  });

  final AsyncValue<bool> activeSession;
  final VoidCallback onPlay;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedUpgradesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Hex Cozy Games',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 36),
        // ── Bouton Jouer / Reprendre ────────────────────────────────────
        SizedBox(
          width: 200,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF6FA8DC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: activeSession.when(
              loading: () => null,
              data: (active) => active ? onResume : onPlay,
              error: (_, _) => onPlay,
            ),
            child: activeSession.when(
              loading: () => const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              data: (active) => Text(
                active ? Str.home_resume : Str.home_play,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              error: (_, _) => Text(
                Str.home_play,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ── Bouton Build (sélection des améliorations) ──────────────────
        _BuildButton(selected: selected),
        const SizedBox(height: 24),
        // ── Accès Quêtes et Statistiques ─────────────────────────────────
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavButton(
              icon: Icons.flag_outlined,
              label: Str.quests_title,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const QuestsScreen()),
              ),
            ),
            const SizedBox(width: 16),
            _NavButton(
              icon: Icons.bar_chart_outlined,
                  label: Str.home_stats,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StatsScreen(),
                      ),
                    );
                  },
            ),
          ],
        ),
      ],
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
        MaterialPageRoute(builder: (_) => const BuildScreen()),
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
                ? Str.home_buildSelection
                : '${selected.length} / $kMaxSelectedUpgrades',
            style: const TextStyle(fontSize: 13),
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
        color: const Color(0xFF6FA8DC).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        upgradeIconData(effectType),
        color: const Color(0xFF6FA8DC),
        size: 14,
      ),
    );
  }
}
