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
import '../core/constants.dart';
import '../core/game_enums.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../game/hex_cell.dart' show BiomeType;
import '../game/hex_tile.dart';
import '../game/tile_component.dart' show BiomeColor;
import '../providers/build_provider.dart';
import '../providers/biome_size_overlay_provider.dart';
import '../providers/grid_state_provider.dart';
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
/// jouée au déclenchement d'un effet — doublée par rapport à la durée des
/// autres animations de feedback courtes du jeu (glow de connexion :
/// [kGlowDurationSec]) pour laisser le contour d'activation bien plus
/// visible.
const Duration _kPulseDuration = Duration(milliseconds: 1100);

// Teinte ambre pour signaler le mode Deuxième chance actif — reprise à
// l'identique de l'ancien `second_chance_hud.dart`.
const Color _kActiveGlass = Color(0xFFFFB300);
const Color _kActiveBorder = Color(0xFFFFD54F);

/// Nombre d'étincelles de l'explosion jouée au déclenchement d'un effet
/// (voir [_SparkBurstPainter]) — assez dense pour se voir clairement sur
/// une icône de ~44px sans la surcharger.
const int _kSparkCount = 8;

/// Fraction de la durée totale du pulse ([_kPulseDuration]) que dure
/// l'explosion d'étincelles — beaucoup plus courte que le halo doré
/// (aller-retour sur toute la durée) pour rester un flash bref au moment
/// précis du déclenchement plutôt qu'un effet qui traîne.
const double _kSparkBurstFraction = 0.4;

/// Distance de projection des étincelles au-delà du bord de l'icône.
const double _kSparkTravel = 20.0;

/// Marge autour du slot réservée à l'explosion — les étincelles doivent
/// pouvoir dépasser largement les limites de l'icône (contrairement au
/// contour doré, qui reste dans les bords du [GlassContainer]).
const double _kSparkBurstMargin = 32.0;

/// Registre statique des slots de l'encart des améliorations actives,
/// indexé par type d'effet — permet à du code hors de l'arbre Flutter (ici
/// [HexBoardGame], via `game_screen.dart`) de cibler la position écran d'un
/// slot précis pour y ancrer une animation Flame (ex. particule Combo+),
/// sans coupler ce widget au jeu Flame. Un build ne peut pas sélectionner
/// deux fois la même amélioration, donc une clé par [UpgradeEffectType]
/// suffit et peut être réutilisée d'un build à l'autre plutôt que recréée.
class UpgradeHudAnchors {
  UpgradeHudAnchors._();
  static final Map<UpgradeEffectType, GlobalKey> _keys = {};

  static GlobalKey keyFor(UpgradeEffectType type) =>
      _keys.putIfAbsent(type, () => GlobalKey());

  /// Position globale (coordonnées jeu Flame — même origine que
  /// [GameWidget], voir `game_screen.dart`) du centre du slot pour [type],
  /// ou null si ce slot n'est pas affiché actuellement (amélioration non
  /// sélectionnée dans le build en cours).
  static Offset? globalCenterFor(UpgradeEffectType type) {
    final key = _keys[type];
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }
}

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
    buttonTapFeedback(context);
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
      case UpgradeEffectType.closureBonusTiles:
        return _buildClosureBonus(context);
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
        effectType: effectType,
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
            upgradeId: widget.upgrade.id,
            color: tint ?? Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  /// Slot "Emplacement Joker" — reprend le comportement de l'ex
  /// `HoldSlotHud` : tap = échange tuile active ↔ tuile en réserve, aperçu
  /// de la tuile tenue affiché à la place de l'icône par défaut. Contour et
  /// fond illuminés en doré (mêmes teintes que le slot Deuxième chance actif,
  /// `_kActiveGlass`/`_kActiveBorder`) tant qu'une tuile est effectivement
  /// stockée, pour signaler l'état "en réserve" en un coup d'œil plutôt que
  /// seulement via l'aperçu de la tuile.
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
        effectType: UpgradeEffectType.holdSlotUses,
        counter: counter,
        builder: (glowAlpha, scale) => GlassContainer(
          width: kActiveUpgradeSlotSize,
          height: kActiveUpgradeSlotSize,
          tintColor: heldTile != null ? _kActiveGlass : kGlassBlue,
          tintAlpha: heldTile != null ? 0.28 : 0.22,
          borderColor: heldTile != null
              ? _kActiveBorder.withValues(alpha: 0.6)
              : (glowAlpha > 0
                  ? Color.lerp(kGlassBlueBorder, kRewardGold, glowAlpha)
                  : kGlassBlueBorder),
          borderWidth: heldTile != null
              ? 1.5
              : (glowAlpha > 0 ? 1.0 + glowAlpha : 1.0),
          onTap: canSwap
              ? () {
                  buttonTapFeedback(context);
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
        effectType: UpgradeEffectType.secondChanceUses,
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
                  buttonTapFeedback(context);
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

  /// Slot "Couleur détestée" (Story B12x+) — amélioration à utilisations
  /// limitées par partie (1/2/3 selon niveau) : un tap ouvre la pop-up de
  /// choix de couleur ([_showColorPicker]) tant qu'il reste des
  /// utilisations ET qu'aucune exclusion n'est déjà en cours ; le slot n'a
  /// alors plus d'action au tap (mais reste consultable en appui long)
  /// jusqu'à ce que l'exclusion en cours se termine. Le badge affiche la
  /// pastille de couleur + tuiles restantes pendant une exclusion, ou le
  /// nombre d'utilisations restantes ("restant/max") le reste du temps
  /// (voir [upgradeCounterFor]).

  /// Ouvre la pop-up de choix de couleur à exclure — un tap sur une couleur
  /// valide immédiatement le choix (voir [_HatedColorPickerSheet], qui se
  /// referme en renvoyant la couleur tapée) et déclenche l'activation.
  Future<void> _showColorPicker(BuildContext context) async {
    final biome = await showModalBottomSheet<BiomeType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _HatedColorPickerSheet(),
    );
    if (biome != null) {
      activateHatedColor(ref, biome);
    }
  }

  Widget _buildHatedColor(BuildContext context) {
    final stack = ref.watch(tileStackProvider);
    final placedCount =
        ref.watch(gridProvider.select((g) => g.placedTiles.length));
    final isExclusionActive =
        hatedColorTilesRemaining(stack, placedCount) != null;
    final usesRemaining =
        ref.watch(sessionProvider.select((s) => s.hatedColorRemainingUses));
    final canActivate = !isExclusionActive && usesRemaining > 0;
    final counter = upgradeCounterFor(ref, UpgradeEffectType.hatedColorExclusion);

    return GestureDetector(
      onLongPress: () => _showDescription(context),
      child: _slotShell(
        effectType: UpgradeEffectType.hatedColorExclusion,
        counter: counter,
        builder: (glowAlpha, scale) => GlassContainer(
          width: kActiveUpgradeSlotSize,
          height: kActiveUpgradeSlotSize,
          tintColor: kGlassBlue,
          borderColor: glowAlpha > 0
              ? Color.lerp(kGlassBlueBorder, kRewardGold, glowAlpha)
              : kGlassBlueBorder,
          borderWidth: glowAlpha > 0 ? 1.0 + glowAlpha : 1.0,
          onTap: canActivate
              ? () {
                  buttonTapFeedback(context);
                  _showColorPicker(context);
                }
              : null,
          child: Opacity(
            opacity: canActivate ? 1.0 : 0.4,
            child: const UpgradeEffectIcon(
              effectType: UpgradeEffectType.hatedColorExclusion,
              upgradeId: 'hated_color',
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  /// Slot "Bonus de clôture" — un tap bascule l'affichage à la demande de la
  /// taille de chaque zone de couleur (cluster de tuiles connectées par un
  /// même biome, hors village) directement sur le plateau (voir
  /// [biomeSizeOverlayProvider] et `hex_grid_component.dart`,
  /// `biomeSizeClusters`) : un chiffre blanc sur fond noir translucide
  /// au-dessus de chaque zone, pour visualiser la progression vers le seuil
  /// de 8 tuiles du bonus. Un second tap masque l'affichage. Contour et
  /// fond illuminés en doré tant que l'affichage reste actif (mêmes teintes
  /// que le slot Deuxième chance actif), pour signaler l'état en un coup
  /// d'œil.
  Widget _buildClosureBonus(BuildContext context) {
    final isActive = ref.watch(biomeSizeOverlayProvider);
    final tint = upgradeIconColor(UpgradeEffectType.closureBonusTiles);
    final counter = upgradeCounterFor(ref, UpgradeEffectType.closureBonusTiles);

    return GestureDetector(
      onLongPress: () => _showDescription(context),
      child: _slotShell(
        effectType: UpgradeEffectType.closureBonusTiles,
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
          onTap: () {
            buttonTapFeedback(context);
            ref.read(biomeSizeOverlayProvider.notifier).toggle();
          },
          child: UpgradeEffectIcon(
            effectType: UpgradeEffectType.closureBonusTiles,
            upgradeId: widget.upgrade.id,
            color: tint ?? Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }


  /// déclenchement + badge(s) de suivi éventuel(s) en overlay (chiffre en
  /// bas-droite, pastille de couleur en haut-droite pour Couleur détestée).
  Widget _slotShell({
    required UpgradeEffectType effectType,
    required UpgradeCounterInfo counter,
    required Widget Function(double glowAlpha, double scale) builder,
  }) {
    return SizedBox(
      key: UpgradeHudAnchors.keyFor(effectType),
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
                // Explosion d'étincelles au déclenchement — même
                // déclencheur (_controller.forward(from: 0)) que le
                // contour doré, mais jouée sur une fraction plus courte
                // de la durée totale (voir [_kSparkBurstFraction]) pour
                // rester un flash net plutôt qu'un effet qui traîne
                // aussi longtemps que le pulse du contour.
                Positioned(
                  left: -_kSparkBurstMargin,
                  top: -_kSparkBurstMargin,
                  right: -_kSparkBurstMargin,
                  bottom: -_kSparkBurstMargin,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SparkBurstPainter(
                        progress: _controller.value,
                        iconRadius: kActiveUpgradeSlotSize / 2,
                        color: kRewardGold,
                      ),
                    ),
                  ),
                ),
                if (counter.swatchColor != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: _SwatchBadge(color: counter.swatchColor!),
                  ),
                if (counter.value != null)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: _NumberBadge(
                      value: counter.value!,
                      max: counter.max,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Peintre de l'explosion d'étincelles jouée au déclenchement d'un effet
/// (voir usage dans [_UpgradeSlotState._slotShell]) — [_kSparkCount]
/// étincelles radiales qui partent du bord de l'icône et s'éloignent en
/// s'estompant, sur les [_kSparkBurstFraction] premiers de [progress] (la
/// valeur brute 0→1 de _controller, pas le pulse aller-retour du contour) :
/// au-delà, l'explosion est déjà terminée et rien n'est dessiné, pour
/// rester un flash bref plutôt qu'un effet qui traîne aussi longtemps que
/// le halo doré du contour.
class _SparkBurstPainter extends CustomPainter {
  _SparkBurstPainter({
    required this.progress,
    required this.iconRadius,
    required this.color,
  });

  final double progress;
  final double iconRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (progress / _kSparkBurstFraction).clamp(0.0, 1.0);
    if (t <= 0.0 || t >= 1.0) return;

    final center = size.center(Offset.zero);
    final eased = Curves.easeOut.transform(t);
    final fade = 1.0 - Curves.easeIn.transform(t);

    for (var i = 0; i < _kSparkCount; i++) {
      // Léger décalage d'angle alterné + longueur alternée : évite un
      // motif trop parfaitement symétrique/mécanique pour un flash censé
      // paraître spontané.
      final angle = (2 * pi / _kSparkCount) * i + (i.isEven ? 0.12 : -0.12);
      final lengthMul = i.isEven ? 1.0 : 0.72;
      final dir = Offset(cos(angle), sin(angle));
      final dist = iconRadius + eased * _kSparkTravel * lengthMul;

      final paint = Paint()
        ..color = color.withValues(alpha: fade * 0.9)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center + dir * dist,
        center + dir * (dist + 6.0 + eased * 4.0),
        paint,
      );

      // Petit point lumineux à la pointe de chaque étincelle.
      canvas.drawCircle(
        center + dir * (dist + 6.0 + eased * 4.0),
        1.6 * (1.0 - eased * 0.4),
        Paint()..color = color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Pastille ronde de la couleur du biome exclu — affichée en haut-droite de
/// l'icône (Couleur détestée).
class _SwatchBadge extends StatelessWidget {
  const _SwatchBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.45), width: 1),
      ),
    );
  }
}

/// Badge numérique de suivi — affiché en bas-droite de l'icône, avec palier
/// optionnel ("valeur/max", ex. Combo+) ou simple compteur d'utilisations/
/// tuiles restantes (Emplacement Joker, Deuxième chance, Couleur détestée).
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.value, this.max});

  final int value;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final label = max != null ? '$value/$max' : '$value';

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
                        upgradeId: upgrade.id,
                        color: tint ?? Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        upgradeName(context, upgrade.id),
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

/// Pop-up de choix de couleur ouverte au tap du slot "Couleur détestée"
/// (Story B12x+, revue UX) — remplace l'ancien tirage aléatoire : le joueur
/// choisit lui-même, parmi les couleurs de base disponibles dès le
/// lancement de la partie ([unlockedBiomesAt]), celle qu'il veut exclure
/// temporairement de la pile. Un tap sur une pastille de couleur valide
/// immédiatement le choix et referme la pop-up en renvoyant la couleur
/// choisie (voir [_UpgradeSlotState._showColorPicker]). Même habillage
/// (GlassContainer + poignée) que [_UpgradeDescriptionSheet], pour rester
/// cohérent avec le reste du HUD.
class _HatedColorPickerSheet extends StatelessWidget {
  const _HatedColorPickerSheet();

  @override
  Widget build(BuildContext context) {
    final biomes = unlockedBiomesAt(1);
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
                Text(
                  context.tr.upgrade_hated_color_picker_title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final biome in biomes) _HatedColorSwatch(biome: biome),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille tappable d'une couleur dans [_HatedColorPickerSheet] — couleur
/// pleine + léger halo lumineux assorti (cohérent avec le glow doré des
/// autres slots de l'encart) + nom localisé de la couleur en dessous.
class _HatedColorSwatch extends StatelessWidget {
  const _HatedColorSwatch({required this.biome});

  final BiomeType biome;

  @override
  Widget build(BuildContext context) {
    final color = biome.color;
    return GestureDetector(
      onTap: () {
        buttonTapFeedback(context);
        Navigator.of(context).pop(biome);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            biomeName(context, biome.name),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
