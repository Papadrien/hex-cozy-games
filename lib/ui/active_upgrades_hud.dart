/// Encart des améliorations actives — Story B12c / B12d, consolidé avec les
/// actions Emplacement Joker / Deuxième chance (ex-Story B10/B11).
///
/// Affiche les icônes des ≤[kMaxSelectedUpgrades] améliorations du build en
/// cours, avec un badge de suivi pour celles à effet cumulatif/compté (voir
/// [upgradeCounterFor]) et une pulsation/contour doré au déclenchement d'un
/// effet sur la pose en cours (voir [upgradeFeedbackProvider]). "Aperçu
/// prolongé" (passivement active tout le long de la partie) affiche à la
/// place un contour doré fixe, pour la distinguer d'un déclenchement
/// ponctuel.
///
/// Consolidation UX (audit) : "Emplacement Joker" et "Deuxième chance"
/// n'ont plus de HUD dédié séparé (ex `hold_slot_hud.dart` /
/// `second_chance_hud.dart`, positionnés en bas à gauche) — leur slot ICI,
/// dans l'encart central, devient directement l'élément interactif :
///  - Emplacement Joker : tap = échange tuile active ↔ tuile en réserve
///    (aperçu de la tuile tenue affiché à la place de l'icône).
///  - Deuxième chance : tap = bascule le mode sélection (icône et teinte
///    passent à l'ambre quand actif).
/// Un seul emplacement visuel à repérer pendant la partie, au lieu de deux.
///
/// Geste d'info : un appui long sur N'IMPORTE QUEL slot ouvre une fiche
/// descriptive (nom + explication complète de l'effet) — uniforme sur
/// toutes les améliorations, y compris celles qui répondent aussi au tap
/// court pour leur action. Le tap court reste réservé à l'action quand il y
/// en a une, pour ne jamais faire hésiter le joueur entre "info" et
/// "agir" : long press = toujours info, tap court = agir si possible.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/game_enums.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../game/hex_tile.dart';
import '../game/tile_component.dart' show BiomeColor;
import '../providers/build_provider.dart';
import '../providers/hold_slot_provider.dart';
import '../providers/hold_slot_swap.dart';
import '../providers/second_chance_ops.dart';
import '../providers/progression_provider.dart';
import '../providers/second_chance_provider.dart';
import '../providers/session_provider.dart';
import '../providers/tile_stack_provider.dart';
import '../providers/upgrade_counter.dart';
import '../providers/upgrade_feedback_provider.dart';
import '../services/haptics_service.dart';
import 'glass_container.dart';
import 'coin_icon.dart';

/// Taille des slots dans l'encart central — l'audit UX aligne aussi la
/// zone cliquable du bouton Annuler (`game_screen.dart`) sur cette même
/// valeur, pour une cohérence de taille de cible tactile sur tout le HUD
/// de jeu.
const double kActiveUpgradeSlotSize = 44.0;
const double _kSlotSpacing = 8.0;

/// Durée totale de la pulsation (aller-retour d'échelle + flash de contour)
/// jouée au déclenchement d'un effet — cohérente avec les autres animations
/// de feedback courtes du jeu (glow de connexion : [kGlowDurationSec]).
const Duration _kPulseDuration = Duration(milliseconds: 550);

// Teinte ambre pour signaler le mode Deuxième chance actif — reprise à
// l'identique de l'ancien `second_chance_hud.dart`.
const Color _kActiveGlass = Color(0xFFFFB300);
const Color _kActiveBorder = Color(0xFFFFD54F);

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

  void _showDescription(BuildContext context) {
    buttonHapticTap(context);
    final effectType = UpgradeEffectType.fromDb(widget.upgrade.effectType);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpgradeDescriptionSheet(
        upgrade: widget.upgrade,
        effectType: effectType,
      ),
    );
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

    switch (effectType) {
      case UpgradeEffectType.holdSlotUses:
        return _buildHoldSlot(context);
      case UpgradeEffectType.secondChanceUses:
        return _buildSecondChance(context);
      case UpgradeEffectType.hatedColorExclusion:
        return _buildHatedColor(context);
      default:
        return _buildPassiveSlot(context, effectType);
    }
  }

  /// Slot par défaut (sans action au tap court) — comportement historique :
  /// icône teintée + badge de suivi éventuel + pulse au déclenchement.
  /// Le tap court n'a pas d'effet ; seul l'appui long ouvre la description.
  Widget _buildPassiveSlot(BuildContext context, UpgradeEffectType effectType) {
    final tint = upgradeIconColor(effectType);
    final counter = upgradeCounterFor(ref, effectType);

    return GestureDetector(
      onLongPress: () => _showDescription(context),
      child: _slotShell(
        counter: counter,
        builder: (glowAlpha, scale) => GlassContainer(
          width: kActiveUpgradeSlotSize,
          height: kActiveUpgradeSlotSize,
          tintColor: kGlassBlue,
          borderColor: glowAlpha > 0
              ? Color.lerp(kGlassBlueBorder, kRewardGold, glowAlpha)
              : kGlassBlueBorder,
          borderWidth: glowAlpha > 0 ? 1.0 + glowAlpha : 1.0,
          child: UpgradeEffectIcon(
            effectType: effectType,
            color: tint ?? Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  /// Slot "Emplacement Joker" — reprend le comportement de l'ex
  /// `HoldSlotHud` : tap = échange tuile active ↔ tuile en réserve, aperçu
  /// de la tuile tenue affiché à la place de l'icône par défaut.
  Widget _buildHoldSlot(BuildContext context) {
    final effects = ref.watch(activeUpgradeEffectsProvider);
    final remainingUses =
        ref.watch(sessionProvider.select((s) => s.holdSlotRemainingUses));
    final heldTile = ref.watch(holdSlotProvider.select((s) => s.heldTile));
    final hasActiveTile =
        ref.watch(tileStackProvider.select((s) => s.activeTile != null));

    // Reprendre une tuile déjà en réserve est gratuit (ne consomme pas
    // d'utilisation) : possible même si remainingUses == 0. Mettre une
    // tuile EN réserve, en revanche, requiert un usage disponible.
    final canSwap = heldTile != null || (remainingUses > 0 && hasActiveTile);
    final counter = effects.holdSlotUses > 0
        ? UpgradeCounterInfo.number(remainingUses)
        : const UpgradeCounterInfo.none();

    return GestureDetector(
      onLongPress: () => _showDescription(context),
      child: _slotShell(
        counter: counter,
        builder: (glowAlpha, scale) => GlassContainer(
          width: kActiveUpgradeSlotSize,
          height: kActiveUpgradeSlotSize,
          tintColor: kGlassBlue,
          borderColor: glowAlpha > 0
              ? Color.lerp(kGlassBlueBorder, kRewardGold, glowAlpha)
              : kGlassBlueBorder,
          borderWidth: glowAlpha > 0 ? 1.0 + glowAlpha : 1.0,
          onTap: canSwap
              ? () {
                  buttonHapticTap(context);
                  swapHoldSlot(ref);
                }
              : null,
          child: Opacity(
            opacity: canSwap ? 1.0 : 0.4,
            child: heldTile != null
                ? _HeldTilePreview(tile: heldTile)
                : const Icon(Icons.swap_horiz, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  /// Slot "Deuxième chance" — reprend le comportement de l'ex
  /// `SecondChanceHud` : tap = bascule le mode sélection, teinte ambre et
  /// icône "close" tant que le mode est actif.
  Widget _buildSecondChance(BuildContext context) {
    final effects = ref.watch(activeUpgradeEffectsProvider);
    final remainingUses =
        ref.watch(sessionProvider.select((s) => s.secondChanceRemainingUses));
    final isActive = ref.watch(secondChanceModeProvider);
    final canTap = isActive || remainingUses > 0;
    final counter = effects.secondChanceUses > 0
        ? UpgradeCounterInfo.number(remainingUses)
        : const UpgradeCounterInfo.none();

    return GestureDetector(
      onLongPress: () => _showDescription(context),
      child: _slotShell(
        counter: counter,
        builder: (glowAlpha, scale) => GlassContainer(
          width: kActiveUpgradeSlotSize,
          height: kActiveUpgradeSlotSize,
          tintColor: isActive ? _kActiveGlass : kGlassBlue,
          tintAlpha: isActive ? 0.28 : 0.22,
          borderColor: isActive
              ? _kActiveBorder.withValues(alpha: 0.6)
              : (glowAlpha > 0
                  ? Color.lerp(kGlassBlueBorder, kRewardGold, glowAlpha)
                  : kGlassBlueBorder),
          borderWidth: isActive ? 1.5 : (glowAlpha > 0 ? 1.0 + glowAlpha : 1.0),
          onTap: canTap
              ? () {
                  buttonHapticTap(context);
                  toggleSecondChanceMode(ref);
                }
              : null,
          child: Opacity(
            opacity: canTap ? 1.0 : 0.4,
            child: Icon(
              isActive ? Icons.close : Icons.replay,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  /// Slot "Couleur détestée" — amélioration à usage unique par partie :
  /// tant qu'elle n'a pas été activée, un tap déclenche l'exclusion (voir
  /// [activateHatedColor]) ; une fois activée (en cours ou terminée), le
  /// slot n'a plus d'action au tap, seul l'appui long reste disponible. La
  /// pastille de couleur du biome exclu (voir [upgradeCounterFor]) reste le
  /// seul indicateur visuel de l'effet en cours.
  Widget _buildHatedColor(BuildContext context) {
    final activated =
        ref.watch(tileStackProvider.select((s) => s.hatedActivated));
    final tint = upgradeIconColor(UpgradeEffectType.hatedColorExclusion);
    final counter = upgradeCounterFor(ref, UpgradeEffectType.hatedColorExclusion);

    return GestureDetector(
      onLongPress: () => _showDescription(context),
      child: _slotShell(
        counter: counter,
        builder: (glowAlpha, scale) => GlassContainer(
          width: kActiveUpgradeSlotSize,
          height: kActiveUpgradeSlotSize,
          tintColor: kGlassBlue,
          borderColor: glowAlpha > 0
              ? Color.lerp(kGlassBlueBorder, kRewardGold, glowAlpha)
              : kGlassBlueBorder,
          borderWidth: glowAlpha > 0 ? 1.0 + glowAlpha : 1.0,
          onTap: activated
              ? null
              : () {
                  buttonHapticTap(context);
                  activateHatedColor(ref);
                },
          child: Opacity(
            opacity: activated ? 0.4 : 1.0,
            child: Icon(
              upgradeIconData(UpgradeEffectType.hatedColorExclusion),
              color: tint ?? Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  /// Coque commune à tous les slots : pulse d'échelle/contour au
  /// déclenchement + badge de suivi éventuel en overlay bas-droite.
  Widget _slotShell({
    required UpgradeCounterInfo counter,
    required Widget Function(double glowAlpha, double scale) builder,
  }) {
    return Tooltip(
      message: widget.upgrade.name,
      child: SizedBox(
        width: kActiveUpgradeSlotSize,
        height: kActiveUpgradeSlotSize,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final glowAlpha = _glow.value;
            final scale = 1.0 + (0.14 * _scale.value);
            return Transform.scale(
              scale: scale,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  builder(glowAlpha, scale),
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

/// Aperçu miniature de la tuile en réserve (Emplacement Joker) — même
/// logique de rendu que la pile de tuiles (`tile_stack_hud.dart`),
/// volontairement dupliquée en plus petit pour éviter de coupler les deux
/// HUDs. Reprise à l'identique de l'ex `hold_slot_hud.dart`.
class _HeldTilePreview extends StatelessWidget {
  const _HeldTilePreview({required this.tile});

  final HexTile tile;

  static const double _kTileRadius = 15.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(_kTileRadius * sqrt(3), _kTileRadius * 2),
      painter: _HeldTilePainter(tile: tile),
    );
  }
}

class _HeldTilePainter extends CustomPainter {
  const _HeldTilePainter({required this.tile});

  final HexTile tile;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2;
    final corners = List.generate(6, (i) {
      final angleRad = (60.0 * i - 90.0) * pi / 180.0;
      return Offset(
        center.dx + radius * cos(angleRad),
        center.dy + radius * sin(angleRad),
      );
    });

    for (var i = 0; i < 6; i++) {
      final c0 = corners[i];
      final c1 = corners[(i + 1) % 6];
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = tile.sides[i].color);
    }

    final outline = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (var i = 1; i < 6; i++) {
      outline.lineTo(corners[i].dx, corners[i].dy);
    }
    outline.close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HeldTilePainter old) => old.tile != tile;
}

/// Fiche descriptive ouverte par appui long sur un slot de l'encart — nom +
/// explication complète de l'effet (même contenu que la carte dépliée de
/// l'écran Build, voir [upgradeDescription]), pour que le joueur puisse se
/// rappeler ce que fait une amélioration sans quitter la partie.
class _UpgradeDescriptionSheet extends StatelessWidget {
  const _UpgradeDescriptionSheet({
    required this.upgrade,
    required this.effectType,
  });

  final UpgradeRow upgrade;
  final UpgradeEffectType effectType;

  @override
  Widget build(BuildContext context) {
    final tint = upgradeIconColor(effectType);
    return Padding(
      // Laisse respirer la sheet au-dessus de la zone home indicator.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: GlassContainer(
            tintColor: kGlassBlue,
            tintAlpha: 0.32,
            borderColor: kGlassBlueBorder,
            borderWidth: 1.5,
            borderRadius: 24,
            blurSigma: 16,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    GlassContainer(
                      width: 40,
                      height: 40,
                      borderRadius: 12,
                      tintColor: kGlassBlue,
                      borderColor: kGlassBlueBorder,
                      child: UpgradeEffectIcon(
                        effectType: effectType,
                        color: tint ?? Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        upgrade.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  upgradeDescription(context, upgrade.id),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.4,
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
