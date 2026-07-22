/// Écran des améliorations — Story 2.7b (fusion avec l'ancien UpgradesScreen).
///
/// Écran unique qui gère à la fois :
///  - la sélection des améliorations actives pour la prochaine partie
///    (0 à [kMaxSelectedUpgrades]) ;
///  - la montée en niveau de chaque amélioration débloquée (description,
///    comparatif niveau actuel → niveau suivant, bouton "Améliorer" avec
///    confirmation en deux temps pour éviter un achat accidentel).
///
/// L'ancien `UpgradesScreen` (jamais relié à une navigation) est supprimé :
/// cet écran est désormais LE seul écran "Améliorations" de l'application.
///
/// Style glassmorphism, aligné sur ShopScreen.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/game_enums.dart';
import '../core/constants.dart';
import '../core/formatting.dart';
import '../core/snackbar_utils.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/build_provider.dart';
import '../providers/player_profile_provider.dart';
import '../providers/progression_provider.dart';
import '../services/haptics_service.dart';
import 'glass_container.dart';
import 'coin_icon.dart';
import 'tropical_background.dart';

class BuildScreen extends ConsumerWidget {
  const BuildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(unlockedUpgradesProvider);
    final selected = ref.watch(selectedUpgradeIdsProvider);
    final totalCoins = ref.watch(totalCoinsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: TropicalBackground(
        child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BuildAppBar(
                  selectedCount: selected.length,
                  totalCoins: totalCoins,
                ),
                Expanded(
                  child: unlocked.isEmpty
                      ? Center(
                          child: Text(
                            context.tr.upgrades_noneUnlocked,
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
                                  key: ValueKey(u.id),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _BuildCard(
                                    upgrade: u,
                                    isSelected: selected.contains(u.id),
                                    totalCoins: totalCoins,
                                    onToggleSelect: () {
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
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR GLASS
// ─────────────────────────────────────────────────────────────────────────────

class _BuildAppBar extends StatelessWidget {
  const _BuildAppBar({required this.selectedCount, required this.totalCoins});
  final int selectedCount;
  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              ),
              _SelectionCountBadge(count: selectedCount),
            ],
          ),
          const SizedBox(height: 10),
          _CoinBalanceBadge(totalCoins: totalCoins),
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
      tintColor: kGlassBlue,
      tintAlpha: 0.22,
      borderColor: kGlassBlueBorder,
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
      tintColor: kGlassBlue,
      tintAlpha: 0.22,
      borderColor: kGlassBlueBorder,
      blurSigma: 10,
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

/// Solde de pièces — repris de l'ancien UpgradesScreen, permet de voir
/// immédiatement si une montée de niveau est abordable.
class _CoinBalanceBadge extends StatelessWidget {
  const _CoinBalanceBadge({required this.totalCoins});
  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 12,
      tintColor: kRewardGold,
      tintAlpha: 0.14,
      borderColor: kRewardGold.withValues(alpha: 0.4),
      blurSigma: 10,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 16),
          const SizedBox(width: 6),
          Text(
            '$totalCoins',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE AMÉLIORATION — repliable, sélectionnable, améliorable
// ─────────────────────────────────────────────────────────────────────────────

class _BuildCard extends ConsumerStatefulWidget {
  const _BuildCard({
    required this.upgrade,
    required this.isSelected,
    required this.totalCoins,
    required this.onToggleSelect,
  });

  final UpgradeRow upgrade;
  final bool isSelected;
  final int totalCoins;
  final VoidCallback onToggleSelect;

  @override
  ConsumerState<_BuildCard> createState() => _BuildCardState();
}

class _BuildCardState extends ConsumerState<_BuildCard>
    with AutomaticKeepAliveClientMixin {
  bool _expanded = false;

  // Garde la carte en vie (état préservé) tant qu'elle est dépliée, pour
  // qu'elle ne se replie pas quand elle sort du viewport puis y revient.
  @override
  bool get wantKeepAlive => _expanded;

  void _toggleExpanded() {
    buttonHapticTap(context);
    setState(() => _expanded = !_expanded);
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // requis par AutomaticKeepAliveClientMixin
    final upgrade = widget.upgrade;
    final isSelected = widget.isSelected;
    final isDebugOnly = upgrade.unlockConditionType == 'debug_only';

    return GlassContainer(
      borderRadius: 14,
      tintColor: isSelected ? kUpgradePurple : kGlassBlue,
      tintAlpha: isSelected ? 0.18 : 0.22,
      borderColor: isSelected
          ? kUpgradePurple.withValues(alpha: 0.65)
          : kGlassBlueBorder,
      borderWidth: isSelected ? 1.5 : 1,
      blurSigma: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleExpanded,
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    upgrade.name,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.85),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isDebugOnly) ...[
                                  const SizedBox(width: 6),
                                  const _DevBadge(),
                                ],
                              ],
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
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white.withValues(alpha: 0.45),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggleSelect,
                child: _SelectionCheck(isSelected: isSelected),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 14),
            Text(
              upgradeDescription(context, upgrade.id),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            _LevelPipsRow(upgrade: upgrade),
            const SizedBox(height: 12),
            _LevelComparison(upgrade: upgrade),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _UpgradeButton(
                upgrade: upgrade,
                totalCoins: widget.totalCoins,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DevBadge extends StatelessWidget {
  const _DevBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
      ),
      child: const Text(
        'DEV',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
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
    final tintOverride =
        upgradeIconColor(UpgradeEffectType.fromDb(upgrade.effectType));
    final iconColor = tintOverride != null
        ? (isSelected ? tintOverride : tintOverride.withValues(alpha: 0.55))
        : (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55));

    return GlassContainer(
      borderRadius: 12,
      tintColor: isSelected ? kUpgradePurple : Colors.white,
      tintAlpha: isSelected ? 0.28 : 0.08,
      borderColor: isSelected
          ? kUpgradePurple.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.14),
      blurSigma: 10,
      width: 42,
      height: 42,
      child: UpgradeEffectIcon(
        effectType: UpgradeEffectType.fromDb(upgrade.effectType),
        color: iconColor,
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
        color: isSelected ? kUpgradePurple : Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? kUpgradePurple.withValues(alpha: 0.8)
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

// ─────────────────────────────────────────────────────────────────────────────
// PASTILLES DE NIVEAU — hexagones, clin d'œil au plateau du jeu
// ─────────────────────────────────────────────────────────────────────────────

class _LevelPipsRow extends StatelessWidget {
  const _LevelPipsRow({required this.upgrade});
  final UpgradeRow upgrade;

  @override
  Widget build(BuildContext context) {
    final levels = upgradeAllLevelEffects(UpgradeEffectType.fromDb(upgrade.effectType));
    // Amélioration à palier unique (ex. debug) : pas de progression à afficher.
    if (levels.length <= 1) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < levels.length; i++) ...[
          _HexPip(
            isReached: i <= upgrade.currentLevel,
            isCurrent: i == upgrade.currentLevel,
          ),
          if (i < levels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i < upgrade.currentLevel
                    ? kBrandBlue.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
        ],
        const SizedBox(width: 8),
        Icon(Icons.stars, size: 14, color: kRewardGold.withValues(alpha: 0.85)),
        const SizedBox(width: 4),
        Text(
          '${context.tr.upgrades_level} ${upgrade.currentLevel + 1}',
          style: TextStyle(
            color: kRewardGold.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Un hexagone de niveau — plein/lumineux si atteint, léger halo si courant.
class _HexPip extends StatelessWidget {
  const _HexPip({required this.isReached, required this.isCurrent});
  final bool isReached;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? kBrandBlue
        : isReached
            ? Colors.white.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.2);

    return Container(
      decoration: isCurrent
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kBrandBlue.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: CustomPaint(
        size: const Size(16, 16),
        painter: _HexagonPainter(color: color),
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  const _HexagonPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (60 * i - 90) * math.pi / 180;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPARATIF NIVEAU ACTUEL → NIVEAU SUIVANT
// ─────────────────────────────────────────────────────────────────────────────

/// N'affiche que le niveau actuel et le prochain palier (pas les 3 niveaux
/// d'un coup) : au niveau 1, inutile de montrer déjà le niveau 3.
class _LevelComparison extends StatelessWidget {
  const _LevelComparison({required this.upgrade});
  final UpgradeRow upgrade;

  @override
  Widget build(BuildContext context) {
    final levels = upgradeAllLevelEffects(UpgradeEffectType.fromDb(upgrade.effectType));
    final level = upgrade.currentLevel;
    final currentLabel = levels[level.clamp(0, levels.length - 1)];
    final isMax = level >= kUpgradeCosts.length || level + 1 >= levels.length;

    if (isMax) {
      return Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: kSuccessGreen.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${context.tr.upgrades_level} ${level + 1} — ${context.tr.upgrades_max} ($currentLabel)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    final nextLabel = levels[level + 1];
    return Row(
      children: [
        Expanded(
          child: Text(
            '${context.tr.upgrades_level} ${level + 1} : $currentLabel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ),
        Icon(Icons.arrow_forward, size: 14, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${context.tr.upgrades_level} ${level + 2} : $nextLabel',
            style: TextStyle(
              color: kBrandBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON AMÉLIORER — confirmation en deux temps
// ─────────────────────────────────────────────────────────────────────────────

/// Bouton Améliorer avec coût affiché, désactivé si pièces insuffisantes.
///
/// Confirmation en deux temps : un premier tap fait passer le bouton en
/// état "Confirmer ?" ; l'achat n'est déclenché qu'au second tap. Le bouton
/// revient à son état initial après un court délai sans action, pour éviter
/// qu'une amélioration ne soit achetée par erreur (double-tap accidentel).
class _UpgradeButton extends ConsumerStatefulWidget {
  const _UpgradeButton({
    required this.upgrade,
    required this.totalCoins,
  });

  final UpgradeRow upgrade;
  final int totalCoins;

  @override
  ConsumerState<_UpgradeButton> createState() => _UpgradeButtonState();
}

class _UpgradeButtonState extends ConsumerState<_UpgradeButton> {
  bool _confirming = false;
  Timer? _revertTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

  void _startConfirm() {
    buttonHapticTap(context);
    setState(() => _confirming = true);
    _revertTimer?.cancel();
    _revertTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _confirming = false);
    });
  }

  Future<void> _confirmAndUpgrade() async {
    _revertTimer?.cancel();
    setState(() => _confirming = false);
    await _handleUpgrade(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final upgrade = widget.upgrade;
    final totalCoins = widget.totalCoins;
    final levels = upgradeAllLevelEffects(UpgradeEffectType.fromDb(upgrade.effectType));
    final isMaxLevel = upgrade.currentLevel >= kUpgradeCosts.length ||
        upgrade.currentLevel + 1 >= levels.length;

    if (isMaxLevel) {
      return GlassContainer(
        borderRadius: 10,
        tintColor: Colors.white,
        tintAlpha: 0.06,
        borderColor: Colors.white.withValues(alpha: 0.12),
        blurSigma: 10,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          context.tr.upgrades_max,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final cost = kUpgradeCosts[upgrade.currentLevel];
    final canAfford = totalCoins >= cost;

    if (_confirming) {
      return GlassContainer(
        borderRadius: 10,
        tintColor: Colors.orange,
        tintAlpha: 0.28,
        borderColor: Colors.orange.withValues(alpha: 0.7),
        blurSigma: 10,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        onTap: _confirmAndUpgrade,
        child: Text(
          context.tr.upgrades_confirmButton,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return GlassContainer(
      borderRadius: 10,
      tintColor: canAfford ? kGlassBlue : Colors.white,
      tintAlpha: canAfford ? 0.32 : 0.06,
      borderColor: canAfford
          ? kGlassBlueBorder
          : Colors.white.withValues(alpha: 0.12),
      blurSigma: 10,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      onTap: canAfford ? _startConfirm : null,
      child: Text(
        '${context.tr.upgrades_cost} : ${formatThousands(cost)}  ${context.tr.upgrades_upgradeButton}',
        style: TextStyle(
          color: canAfford ? Colors.white : Colors.white.withValues(alpha: 0.35),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _handleUpgrade(BuildContext context, WidgetRef ref) async {
    buttonHapticTap(context);
    final upgrade = widget.upgrade;
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

    showAppSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// La fonction de description des améliorations (par upgradeId) vit
// maintenant dans `core/strings.dart` (`upgradeDescription`), partagée avec
// l'encart des améliorations actives du HUD de jeu.
