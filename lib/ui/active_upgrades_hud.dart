/// Encart des améliorations actives — Story B12c / B12d.
///
/// Affiche les icônes des ≤[kMaxSelectedUpgrades] améliorations du build en
/// cours, avec un badge de suivi pour celles à effet cumulatif/compté (voir
/// [upgradeCounterFor]) et une pulsation/contour doré au déclenchement d'un
/// effet sur la pose en cours (voir [upgradeFeedbackProvider]). "Aperçu
/// prolongé" (passivement active tout le long de la partie) affiche à la
/// place un contour doré fixe, pour la distinguer d'un déclenchement
/// ponctuel. Intégration dans [GameScreen] branchée en Story B12e.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/game_enums.dart';
import '../data/app_database.dart';
import '../providers/build_provider.dart';
import '../providers/progression_provider.dart';
import '../providers/upgrade_counter.dart';
import '../providers/upgrade_feedback_provider.dart';
import 'glass_container.dart';

const double _kSlotSize = 44.0;
const double _kSlotSpacing = 8.0;

/// Durée totale de la pulsation (aller-retour d'échelle + flash de contour)
/// jouée au déclenchement d'un effet — cohérente avec les autres animations
/// de feedback courtes du jeu (glow de connexion : [kGlowDurationSec]).
const Duration _kPulseDuration = Duration(milliseconds: 550);

/// Alpha du contour doré fixe pour "Aperçu prolongé", passivement active
/// tant que sélectionnée (pas de pulsation ponctuelle, l'effet joue en
/// continu tout au long de la partie).
const double _kSteadyGlowAlpha = 0.55;

class ActiveUpgradesHud extends ConsumerWidget {
  const ActiveUpgradesHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedUpgradesProvider);
    if (selected.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < selected.length; i++) ...[
          if (i > 0) const SizedBox(width: _kSlotSpacing),
          _UpgradeSlot(key: ValueKey(selected[i].id), upgrade: selected[i]),
        ],
      ],
    );
  }
}

class _UpgradeSlot extends ConsumerStatefulWidget {
  const _UpgradeSlot({super.key, required this.upgrade});

  final UpgradeRow upgrade;

  @override
  ConsumerState<_UpgradeSlot> createState() => _UpgradeSlotState();
}

class _UpgradeSlotState extends ConsumerState<_UpgradeSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _kPulseDuration);
    // Échelle et intensité du contour suivent la même courbe aller-retour
    // (0 → 1 → 0) sur une seule passe de _controller.forward(from: 0), pour
    // éviter d'avoir à enchaîner forward()/reverse() manuellement.
    final pulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scale = pulse;
    _glow = pulse;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectType = UpgradeEffectType.fromDb(widget.upgrade.effectType);

    // Story B12d : déclenche la pulsation quand CET effectType fait partie
    // des types signalés par la pose la plus récente. `ref.listen` en cours
    // de build (même pattern que game_screen.dart pour _RewardTag/reward).
    ref.listen<UpgradeFeedbackState>(upgradeFeedbackProvider, (prev, next) {
      if (next.triggeredTypes.contains(effectType)) {
        _controller.forward(from: 0);
      }
    });

    final tint = upgradeIconColor(effectType);
    final counter = upgradeCounterFor(ref, effectType);
    final isSteadyActive =
        effectType == UpgradeEffectType.extendedPreviewCount;

    return Tooltip(
      message: widget.upgrade.name,
      child: SizedBox(
        width: _kSlotSize,
        height: _kSlotSize,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final glowAlpha =
                isSteadyActive ? _kSteadyGlowAlpha : _glow.value;
            final scale = 1.0 + (0.14 * _scale.value);
            return Transform.scale(
              scale: scale,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  GlassContainer(
                    width: _kSlotSize,
                    height: _kSlotSize,
                    tintColor: kGlassBlue,
                    borderColor: glowAlpha > 0
                        ? Color.lerp(kGlassBlueBorder, kRewardGold, glowAlpha)
                        : kGlassBlueBorder,
                    borderWidth: glowAlpha > 0 ? 1.0 + glowAlpha : 1.0,
                    child: Icon(
                      upgradeIconData(effectType),
                      color: tint ?? Colors.white,
                      size: 22,
                    ),
                  ),
                  if (counter.hasBadge)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: _CounterBadge(counter: counter),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Badge de suivi affiché en overlay d'une icône d'amélioration —
/// numérique (avec palier optionnel "valeur/max") ou pastille de couleur
/// (Couleur détestée).
class _CounterBadge extends StatelessWidget {
  const _CounterBadge({required this.counter});

  final UpgradeCounterInfo counter;

  @override
  Widget build(BuildContext context) {
    if (counter.swatchColor != null) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: counter.swatchColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.45), width: 1),
        ),
      );
    }

    final label =
        counter.max != null ? '${counter.value}/${counter.max}' : '${counter.value}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: kGlassBlue.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGlassBlueBorder, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
