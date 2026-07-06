/// Écran de sélection des améliorations avant une partie — Story 2.7b.
///
/// Liste toutes les améliorations débloquées. Tap pour sélectionner /
/// désélectionner (0 à [kMaxSelectedUpgrades]).
///
/// Style glassmorphism, aligné sur ShopScreen / UpgradesScreen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors.dart';
import '../core/game_enums.dart';
import '../core/constants.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/build_provider.dart';
import '../providers/progression_provider.dart';
import '../services/haptics_service.dart';
import 'glass_container.dart';

class BuildScreen extends ConsumerWidget {
  const BuildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(unlockedUpgradesProvider);
    final selected = ref.watch(selectedUpgradeIdsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Même fond tropical que le reste de l'application ─────────────
          Image.asset(
            'assets/images/home_background.png',
            fit: BoxFit.cover,
          ),
          // ── Voile bleuté — signature des écrans secondaires ───────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D1B3E).withValues(alpha: 0.72),
                  const Color(0xFF0A1628).withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          // ── Contenu ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BuildAppBar(selectedCount: selected.length),
                Expanded(
                  child: unlocked.isEmpty
                      ? Center(
                          child: Text(
                            'Aucune amélioration débloquée',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 15,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                          children: [
                            ...unlocked.map((u) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _BuildCard(
                                    upgrade: u,
                                    isSelected: selected.contains(u.id),
                                    onTap: () {
                                      buttonHapticTap(context);
                                      ref
                                          .read(selectedUpgradeIdsProvider
                                              .notifier)
                                          .toggle(u.id);
                                    },
                                  ),
                                )),
                          ],
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

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR GLASS
// ─────────────────────────────────────────────────────────────────────────────

class _BuildAppBar extends StatelessWidget {
  const _BuildAppBar({required this.selectedCount});
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _BuildGlassIconButton(
            icon: Icons.close,
            onPressed: () {
              buttonHapticTap(context);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.tr.home_buildSelection,
              style: GoogleFonts.nunito(
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
          ),
          _SelectionCountBadge(count: selectedCount),
        ],
      ),
    );
  }
}

class _BuildGlassIconButton extends StatelessWidget {
  const _BuildGlassIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      tintColor: Colors.white,
      tintAlpha: 0.15,
      borderColor: Colors.white.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(10),
      onTap: onPressed,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

/// Badge glass affichant "sélectionnées / max" dans l'app bar.
class _SelectionCountBadge extends StatelessWidget {
  const _SelectionCountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 12,
      tintColor: kBrandBlue,
      tintAlpha: 0.20,
      borderColor: kBrandBlue.withValues(alpha: 0.5),
      blurSigma: 8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        '$count / $kMaxSelectedUpgrades',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE AMÉLIORATION SÉLECTIONNABLE — glass
// ─────────────────────────────────────────────────────────────────────────────

class _BuildCard extends StatelessWidget {
  const _BuildCard({
    required this.upgrade,
    required this.isSelected,
    required this.onTap,
  });

  final UpgradeRow upgrade;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      tintColor: isSelected ? kUpgradePurple : kGlassBlue,
      tintAlpha: isSelected ? 0.18 : 0.22,
      borderColor: isSelected
          ? kUpgradePurple.withValues(alpha: 0.65)
          : kGlassBlueBorder.withValues(alpha: 0.45),
      borderWidth: isSelected ? 1.5 : 1,
      blurSigma: 12,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          _BuildIconBadge(
            upgrade: upgrade,
            isSelected: isSelected,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upgrade.name,
                  style: GoogleFonts.nunito(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  upgradeEffectLabel(upgrade),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SelectionCheck(isSelected: isSelected),
        ],
      ),
    );
  }
}

class _BuildIconBadge extends StatelessWidget {
  const _BuildIconBadge({required this.upgrade, required this.isSelected});
  final UpgradeRow upgrade;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 12,
      tintColor: isSelected ? kBrandBlue : Colors.white,
      tintAlpha: isSelected ? 0.28 : 0.08,
      borderColor: isSelected
          ? kBrandBlue.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.14),
      borderWidth: 0.8,
      blurSigma: 6,
      width: 42,
      height: 42,
      child: Icon(
        upgradeIconData(UpgradeEffectType.fromDb(upgrade.effectType)),
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55),
        size: 20,
      ),
    );
  }
}

/// Pastille de sélection — coche pleine si sélectionnée, anneau glass sinon.
class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.isSelected});
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isSelected ? kBrandBlue : Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? kBrandBlue.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}
