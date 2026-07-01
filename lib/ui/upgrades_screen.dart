library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors.dart';
import '../core/game_enums.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/player_profile_provider.dart';
import '../providers/progression_provider.dart';
import '../providers/quest_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ÉCRAN DES AMÉLIORATIONS — style glassmorphism (aligné sur ShopScreen)
// ─────────────────────────────────────────────────────────────────────────────

class UpgradesScreen extends ConsumerWidget {
  const UpgradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upgradesAsync = ref.watch(upgradesProvider);
    final questsAsync = ref.watch(permanentQuestsProvider);
    final totalCoinsAsync = ref.watch(totalCoinsProvider);

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
                _UpgradesAppBar(),
                Expanded(
                  child: upgradesAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (_, _) => Center(
                      child: Text(
                        'Erreur',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ),
                    data: (upgrades) {
                      final questMap = questsAsync.maybeWhen(
                        data: (list) => {
                          for (final q in list) q.id: q.description,
                        },
                        orElse: () => <String, String>{},
                      );
                      return _UpgradesList(
                        upgrades: upgrades,
                        questDescriptions: questMap,
                        totalCoins: totalCoinsAsync,
                      );
                    },
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

class _UpgradesAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _UpgradesGlassIconButton(
            icon: Icons.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 14),
          Text(
            context.tr.upgrades_title,
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
        ],
      ),
    );
  }
}

class _UpgradesGlassIconButton extends StatelessWidget {
  const _UpgradesGlassIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTE
// ─────────────────────────────────────────────────────────────────────────────

class _UpgradesList extends StatelessWidget {
  const _UpgradesList({
    required this.upgrades,
    required this.questDescriptions,
    required this.totalCoins,
  });

  final List<UpgradeRow> upgrades;
  final Map<String, String> questDescriptions;
  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    final unlocked = upgrades.where((u) => u.isUnlocked).toList();
    final locked = upgrades.where((u) => !u.isUnlocked).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        if (unlocked.isNotEmpty) ...[
          _GlassSectionHeader(
            icon: Icons.check_circle,
            color: kSuccessGreen,
            label: 'Débloquées',
          ),
          const SizedBox(height: 12),
          ...unlocked.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UpgradeCard(
                upgrade: u,
                isLocked: false,
                questDescriptions: questDescriptions,
                totalCoins: totalCoins,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (locked.isNotEmpty) ...[
          _GlassSectionHeader(
            icon: Icons.lock,
            color: Colors.white.withValues(alpha: 0.55),
            label: 'Verrouillées',
          ),
          const SizedBox(height: 12),
          ...locked.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UpgradeCard(
                upgrade: u,
                isLocked: true,
                questDescriptions: questDescriptions,
                totalCoins: totalCoins,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EN-TÊTE DE SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSectionHeader extends StatelessWidget {
  const _GlassSectionHeader({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE AMÉLIORATION — glass
// ─────────────────────────────────────────────────────────────────────────────

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.upgrade,
    required this.isLocked,
    required this.questDescriptions,
    required this.totalCoins,
  });

  final UpgradeRow upgrade;
  final bool isLocked;
  final Map<String, String> questDescriptions;
  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLocked
                ? Colors.white.withValues(alpha: 0.05)
                : kBrandBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isLocked
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _UpgradeIconBadge(isLocked: isLocked),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      upgrade.name,
                      style: GoogleFonts.nunito(
                        color: isLocked
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.tune,
                      size: 14,
                      color: isLocked
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.55)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isLocked ? context.tr.upgrades_hiddenEffect : _effectLabel(upgrade),
                      style: TextStyle(
                        color: isLocked
                            ? Colors.white.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontStyle: isLocked ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isLocked) ...[
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${context.tr.upgrades_unlockCondition} : ${_conditionLabel(upgrade, questDescriptions)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _LevelsPreview(upgrade: upgrade),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.stars,
                        size: 14,
                        color: kRewardGold.withValues(alpha: 0.85)),
                    const SizedBox(width: 6),
                    Text(
                      '${context.tr.upgrades_level} ${upgrade.currentLevel + 1}',
                      style: TextStyle(
                        color: kRewardGold.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _UpgradeButton(upgrade: upgrade, totalCoins: totalCoins),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeIconBadge extends StatelessWidget {
  const _UpgradeIconBadge({required this.isLocked});
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isLocked
                ? Colors.white.withValues(alpha: 0.08)
                : kUpgradePurple.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLocked
                  ? Colors.white.withValues(alpha: 0.14)
                  : kUpgradePurple.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Icon(
            isLocked ? Icons.lock : Icons.auto_awesome,
            size: 18,
            color: isLocked
                ? Colors.white.withValues(alpha: 0.4)
                : kUpgradePurple,
          ),
        ),
      ),
    );
  }
}

/// Ligne de preview des 3 niveaux avec effet de chaque palier.
class _LevelsPreview extends StatelessWidget {
  const _LevelsPreview({required this.upgrade});

  final UpgradeRow upgrade;

  @override
  Widget build(BuildContext context) {
    final levels = upgradeAllLevelEffects(UpgradeEffectType.fromDb(upgrade.effectType));

    return Row(
      children: [
        for (var i = 0; i < levels.length; i++)
          Expanded(
            child: _LevelDot(
              index: i,
              label: levels[i],
              isCurrent: i == upgrade.currentLevel,
              isReached: i <= upgrade.currentLevel,
            ),
          ),
      ],
    );
  }
}

/// Un petit palier dans la ligne de niveaux.
class _LevelDot extends StatelessWidget {
  const _LevelDot({
    required this.index,
    required this.label,
    required this.isCurrent,
    required this.isReached,
  });

  final int index;
  final String label;
  final bool isCurrent;
  final bool isReached;

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? kBrandBlue
        : isReached
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.25);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            if (index < 2)
              Container(
                height: 2,
                width: 12,
                color: isReached && index < 2
                    ? color
                    : Colors.white.withValues(alpha: 0.12),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Niv.${index + 1}',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// Bouton Améliorer avec coût affiché, désactivé si pièces insuffisantes.
class _UpgradeButton extends ConsumerWidget {
  const _UpgradeButton({
    required this.upgrade,
    required this.totalCoins,
  });

  final UpgradeRow upgrade;
  final int totalCoins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMaxLevel = upgrade.currentLevel >= kUpgradeCosts.length;
    if (isMaxLevel) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              context.tr.upgrades_max,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    final cost = kUpgradeCosts[upgrade.currentLevel];
    final canAfford = totalCoins >= cost;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: canAfford
              ? kBrandBlue.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: canAfford ? () => _handleUpgrade(context, ref) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: canAfford
                      ? kBrandBlue.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Text(
                '${context.tr.upgrades_cost} : $cost  ${context.tr.upgrades_upgradeButton}',
                style: TextStyle(
                  color: canAfford
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpgrade(BuildContext context, WidgetRef ref) async {
    final service = ref.read(progressionServiceProvider);
    final result = await service.levelUpUpgrade(upgrade.id);

    if (!context.mounted) return;

    final (message, color) = switch (result) {
      UpgradeResult.success => (
        '${upgrade.name} → ${context.tr.upgrades_level} ${upgrade.currentLevel + 2}',
        kSuccessGreen,
      ),
      UpgradeResult.insufficientCoins => (
        'Pièces insuffisantes',
        Colors.orange,
      ),
      UpgradeResult.maxLevelReached => (
        'Niveau maximum atteint',
        Colors.white.withValues(alpha: 0.5),
      ),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

String _effectLabel(UpgradeRow upgrade) {
  final allLevels = upgradeAllLevelEffects(UpgradeEffectType.fromDb(upgrade.effectType));
  final idx = upgrade.currentLevel < allLevels.length
      ? upgrade.currentLevel
      : allLevels.length - 1;
  return allLevels[idx];
}

String _conditionLabel(
  UpgradeRow upgrade,
  Map<String, String> questDescriptions,
) {
  if (upgrade.unlockConditionType == 'tiles_placed') {
    return 'Poser ${upgrade.unlockConditionValue} tuiles';
  }
  return questDescriptions[upgrade.unlockConditionType] ??
      upgrade.unlockConditionType;
}
