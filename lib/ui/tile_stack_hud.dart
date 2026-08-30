/// UI de la pile de tuiles (HUD) — Story 1.4b.
///
/// Affiche les 3 prochaines tuiles en disposition horizontale de gauche à
/// droite : active au premier plan, suivante au second, troisième au fond.
///
/// Les tuiles pas encore posables (après la première) pivotent en 3D
/// (axe Y, ancrées sur leur bord gauche) pour suggérer qu'elles s'enfoncent
/// vers la droite dans la pile, et chaque avancée de la pile (pose d'une
/// tuile) déclenche une transition animée : les tuiles
/// suivantes glissent vers l'avant en grandissant vers leur taille cible,
/// et la nouvelle tuile arrivant en fin de pile entre depuis la droite de
/// l'écran.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../game/hex_tile.dart';
import '../game/tile_component.dart' show BiomeColor;
import '../providers/placement_provider.dart';
import '../providers/second_chance_provider.dart';
import '../providers/tile_stack_provider.dart';
import '../services/haptics_service.dart';

const double _kActiveTileRadius = 34.0;
const double _kUpcomingTileRadius = 26.0;

// Bleu nuit tealisé pour les composants HUD.
const Color _kHudGlass = kGlassBlue;
const Color _kHudGlassBorder = kGlassBlueBorder;

// Disposition horizontale avec chevauchement.
//   [Active (1er plan)] [2e (2d plan)] [3e (3e plan)] ...
final double _kActiveTileWidth = _kActiveTileRadius * sqrt(3);
final double _kUpcomingTileWidth = _kUpcomingTileRadius * sqrt(3);
const double _kTileOverlap = 14.0;

final double _kStackHeight = _kActiveTileRadius * 2;

// Rotation 3D (axe Y) appliquée aux tuiles pas encore posables : la pile
// étant horizontale avec le haut (tuile active) à gauche, l'effet de
// profondeur doit basculer les tuiles vers la droite (comme si elles
// s'enfonçaient vers l'arrière-droit de la pile), jamais vers le bas.
const double _kPerspectiveDepth = 0.0011; // force du point de fuite
const double _kPerspectiveStepRotation = 0.16; // radians par tuile
const double _kPerspectiveMaxRotation = 0.38; // plafond en radians

// Épaisseur du "bloc" 3D dessiné sur la droite de chaque tuile pas encore
// posable — même principe que l'extrusion des tuiles du plateau
// (tile_component.dart), mais orientée à droite plutôt que vers le bas,
// pour donner l'impression que la tuile est vue de biais, tournée vers la
// gauche. Sans cette face latérale, la rotation Y d'un hexagone purement
// plat ne fait que l'écraser et l'éclaircir, ce qui ressemble à de la
// transparence plutôt qu'à de la profondeur. Épaisseur fixe (et non plus
// croissante avec l'index) pour que toutes les tuiles pas encore posables
// aient le même effet de profondeur, quelle que soit leur position dans la
// pile.
const double _kStackTileDepth = 5.0; // px, identique pour toutes les tuiles

double _sideDepthFor(int index) => index <= 0 ? 0.0 : _kStackTileDepth;

// Animation de transition jouée à chaque avancée de la pile (pose d'une
// tuile) : les tuiles glissent vers l'avant / grandissent, et la nouvelle
// tuile arrivante entre depuis la droite de l'écran.
const Duration _kAdvanceDuration = Duration(milliseconds: 380);
const Curve _kAdvanceCurve = Curves.easeOutCubic;

// Rotation Y : positive fait pivoter le bord droit de la tuile vers
// l'arrière (loin de la caméra) et le bord gauche vers l'avant — cohérent
// avec une pile dont le haut est à gauche et qui "s'enfonce" vers la droite.
double _rotationYFor(int index) => index <= 0
    ? 0.0
    : min(_kPerspectiveMaxRotation, _kPerspectiveStepRotation * index);

double _radiusFor(int index) =>
    index == 0 ? _kActiveTileRadius : _kUpcomingTileRadius;

double _leftFor(int index) {
  if (index <= 0) return 0;
  final i = index - 1;
  return _kActiveTileWidth + i * _kUpcomingTileWidth - (i + 1) * _kTileOverlap;
}

// ── Widget principal ─────────────────────────────────────────────────────────

class TileStackHud extends ConsumerWidget {
  const TileStackHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stackState = ref.watch(tileStackProvider);
    final placement = ref.watch(placementProvider);
    final visible = stackState.visible;

    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pas de fond glassmorphism ici : la pile de tuiles est affichée
        // directement sur le fond du jeu, seule la croix d'annulation garde
        // un fond vitreux pour rester lisible.
        Padding(
          padding: const EdgeInsets.all(10),
          child: _AnimatedTilePile(
            visible: visible,
            hasSelection: placement.hasSelection,
            onCancelSelection: () {
              ref.read(placementProvider.notifier).clearSelection();
            },
          ),
        ),
        const SizedBox(height: 4),
        _RemainingBadge(remaining: stackState.remaining),
      ],
    );
  }
}

/// Gère la disposition en perspective et l'animation de transition de la
/// pile de tuiles visibles.
///
/// Chaque tuile est identifiée par son identité d'objet (les instances de
/// [HexTile] circulent telles quelles depuis la file du provider jusqu'à
/// l'affichage, sans être recopiées), ce qui permet de reconnaître une même
/// tuile d'une reconstruction à l'autre et de faire glisser/grandir son
/// widget plutôt que de le recréer. Une tuile absente de la liste
/// précédente est considérée comme une nouvelle arrivée : elle est d'abord
/// positionnée hors-écran à droite, puis animée vers son emplacement final
/// dès la frame suivante.
class _AnimatedTilePile extends ConsumerStatefulWidget {
  const _AnimatedTilePile({
    required this.visible,
    required this.hasSelection,
    required this.onCancelSelection,
  });

  final List<HexTile> visible;
  final bool hasSelection;
  final VoidCallback onCancelSelection;

  @override
  ConsumerState<_AnimatedTilePile> createState() => _AnimatedTilePileState();
}

class _AnimatedTilePileState extends ConsumerState<_AnimatedTilePile> {
  /// Tuiles fraîchement arrivées en FIN de pile (tirage normal), encore
  /// positionnées hors-écran en attendant la frame qui déclenchera leur
  /// animation d'entrée depuis la droite.
  final Set<HexTile> _enteringFromRight = {};

  /// Tuiles fraîchement revenues en TÊTE de pile (annulation, reprise de
  /// la tuile en réserve) : elles ne "sortent" pas de la pile, elles y
  /// reviennent — on les fait apparaître sur place en fondu/agrandissement
  /// plutôt que de les faire traverser l'écran depuis la droite.
  final Set<HexTile> _returning = {};

  @override
  void didUpdateWidget(covariant _AnimatedTilePile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousIdentities = oldWidget.visible.toSet();
    final newcomers = <HexTile>[];
    final returners = <HexTile>[];
    for (var i = 0; i < widget.visible.length; i++) {
      final tile = widget.visible[i];
      if (previousIdentities.contains(tile)) continue;
      // Une tuile qui revient en tête de pile (index 0) provient d'une
      // annulation ou d'une reprise de réserve, pas d'un nouveau tirage.
      if (i == 0) {
        returners.add(tile);
      } else {
        newcomers.add(tile);
      }
    }
    if (newcomers.isEmpty && returners.isEmpty) return;

    final bonusNewcomers = newcomers.where((t) => t.isBonus).toList();
    if (bonusNewcomers.isNotEmpty) {
      // Contexte indépendant de la rampe de particules de placement (voir
      // [HexBoardGame._bonusImpactCounter]/[HapticsService.bonusTileArrived])
      // : ici, une tuile bonus déjà gagnée devient simplement visible dans
      // la pile en défilant, potentiellement bien après la pose d'origine.
      // Index 5 fixe reproduit l'ancien comportement (impact moyen unique)
      // plutôt que de s'insérer dans une séquence qui n'a pas de sens ici.
      unawaited(ref.read(hapticsServiceProvider).bonusTileArrived(5));
    }

    setState(() {
      _enteringFromRight.addAll(newcomers);
      _returning.addAll(returners);
    });
    // Frame suivante : on retire ces tuiles de leurs ensembles "en attente
    // d'entrée", ce qui fait passer leur position/échelle cible vers leur
    // état final — AnimatedPositioned / AnimatedScale / AnimatedOpacity
    // interpolent alors automatiquement la transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        for (final tile in newcomers) {
          _enteringFromRight.remove(tile);
        }
        for (final tile in returners) {
          _returning.remove(tile);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visible;
    final upcomingCount = visible.length - 1;
    final stackWidth = _kActiveTileWidth +
        max(0, upcomingCount) * (_kUpcomingTileWidth - _kTileOverlap);
    // Point d'entrée hors-écran à droite pour les nouvelles tuiles.
    final offscreenLeft = stackWidth + _kUpcomingTileWidth;

    return SizedBox(
      width: stackWidth,
      height: _kStackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Tuiles de la plus éloignée (fond) à la plus proche (avant), pour
          // que la tuile active se retrouve au-dessus des autres à l'écran.
          for (var i = visible.length - 1; i >= 0; i--)
            _buildTileSlot(
              tile: visible[i],
              index: i,
              offscreenLeft: offscreenLeft,
            ),
          // Croix d'annulation de sélection — la zone d'effet couvre toute
          // la première tuile (Story 4.2b).
          if (widget.hasSelection)
            Positioned(
              left: 0,
              top: 0,
              width: _kActiveTileWidth,
              height: _kStackHeight,
              child: Center(
                child: GlassIconButton(
                  icon: Icons.close,
                  size: 16,
                  padding: const EdgeInsets.all(5),
                  borderRadius: 13,
                  tintColor: _kHudGlass,
                  borderColor: _kHudGlassBorder,
                  blurSigma: 10,
                  onPressed: widget.onCancelSelection,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTileSlot({
    required HexTile tile,
    required int index,
    required double offscreenLeft,
  }) {
    final radius = _radiusFor(index);
    final width = radius * sqrt(3);
    final height = radius * 2;
    final top = (_kStackHeight - height) / 2;
    final targetLeft = _leftFor(index);
    final isEnteringFromRight = _enteringFromRight.contains(tile);
    final isReturning = _returning.contains(tile);
    final rotationY = _rotationYFor(index);
    final sideDepth = _sideDepthFor(index);
    // Plus d'assombrissement/transparence progressif : la sensation de
    // profondeur vient uniquement de la face latérale extrudée (sideDepth)
    // et de la rotation 3D — toutes les tuiles restent pleinement opaques.
    const depthAlpha = 1.0;

    return AnimatedPositioned(
      key: ValueKey(identityHashCode(tile)),
      duration: _kAdvanceDuration,
      curve: _kAdvanceCurve,
      // Tirage normal : entre depuis la droite, hors-écran. Retour
      // (annulation / reprise de réserve) : reste sur place, l'effet vient
      // du fondu + agrandissement ci-dessous, pas d'un déplacement.
      left: isEnteringFromRight ? offscreenLeft : targetLeft,
      top: top,
      width: width,
      height: height,
      // La croissance de la tuile (2e -> 1ère place, etc.) vient
      // directement de l'interpolation de `width`/`height` ci-dessus :
      // _HexTilePreview se contente de remplir la taille qu'on lui donne.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: rotationY),
        duration: _kAdvanceDuration,
        curve: _kAdvanceCurve,
        builder: (context, value, child) => Transform(
          // Ancré sur le bord gauche (haut de la pile) : le bord droit de
          // la tuile pivote vers l'arrière, donnant une vraie profondeur
          // 3D horizontale plutôt qu'un simple écrasement.
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, _kPerspectiveDepth)
            ..rotateY(value),
          child: child,
        ),
        child: AnimatedScale(
          duration: _kAdvanceDuration,
          curve: _kAdvanceCurve,
          scale: isReturning ? 0.4 : 1.0,
          child: AnimatedOpacity(
            duration: _kAdvanceDuration,
            curve: _kAdvanceCurve,
            opacity: isReturning ? 0.0 : 1.0,
            child: _tileContent(
              tile: tile,
              index: index,
              depthAlpha: depthAlpha,
              sideDepth: sideDepth,
            ),
          ),
        ),
      ),
    );
  }

  /// Construit le contenu visuel d'un emplacement de la pile.
  ///
  /// Pour la tuile active (index 0) et tant qu'aucune sélection de
  /// prévisualisation n'est en cours (le tap sur cette même tuile devient
  /// sinon la croix d'annulation, voir [build]), la tuile est enrobée d'un
  /// [Draggable] : glisser-déposer depuis la pile vers le plateau est une
  /// solution supplémentaire au tap pour prévisualiser un emplacement — voir
  /// [GameScreen] pour la cible du drag ([DragTarget]) et la conversion
  /// position -> case hexagonale. Désactivé pendant le mode sélection
  /// Deuxième chance (mutuellement exclusif avec la prévisualisation de
  /// placement, comme pour le tap — voir [toggleSecondChanceMode]).
  Widget _tileContent({
    required HexTile tile,
    required int index,
    required double depthAlpha,
    required double sideDepth,
  }) {
    final preview = _HexTilePreview(
      tile: tile,
      highlighted: index == 0,
      depthAlpha: depthAlpha,
      sideDepth: sideDepth,
    );

    final secondChanceActive = ref.watch(secondChanceModeProvider);
    final canDrag = index == 0 && !widget.hasSelection && !secondChanceActive;
    if (!canDrag) return preview;

    return Draggable<HexTile>(
      data: tile,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DraggedTileFeedback(tile: tile),
      childWhenDragging: Opacity(opacity: 0.25, child: preview),
      child: preview,
    );
  }
}

class _HexTilePreview extends StatelessWidget {
  const _HexTilePreview({
    required this.tile,
    required this.highlighted,
    required this.depthAlpha,
    required this.sideDepth,
  });

  final HexTile tile;
  final bool highlighted;
  final double depthAlpha;
  final double sideDepth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: highlighted
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : const BoxDecoration(),
      // Remplit exactement la taille fournie par le parent (dictée par
      // l'animation de position/taille de AnimatedPositioned), ce qui
      // permet à la tuile de grandir/rétrécir de façon fluide plutôt que
      // par à-coups.
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _HexTilePainter(
            tile: tile,
            highlighted: highlighted,
            alpha: depthAlpha,
            sideDepth: sideDepth,
          ),
        ),
      ),
    );
  }
}

/// Aperçu de la tuile en cours de glisser-déposer depuis la pile vers le
/// plateau — remplace visuellement le doigt, avec une courte animation
/// d'entrée (grandissement + fondu, courbe "back" pour un effet de
/// "soulèvement") qui rend la tuile attrapée bien visible dès le début du
/// geste. Rendue légèrement plus grande que la tuile active de la pile pour
/// rester lisible une fois sous le doigt, et décalée visuellement au-dessus
/// du point de contact (via [Transform.translate]) pour ne pas être masquée
/// par le doigt qui la porte — ce décalage est purement visuel : la position
/// utilisée par [GameScreen] pour le ciblage de la case ([pointerDragAnchorStrategy])
/// reste le point de contact réel, insensible à ce décalage de rendu.
class _DraggedTileFeedback extends StatefulWidget {
  const _DraggedTileFeedback({required this.tile});

  final HexTile tile;

  static const double _kFeedbackRadius = _kActiveTileRadius * 1.3;

  @override
  State<_DraggedTileFeedback> createState() => _DraggedTileFeedbackState();
}

class _DraggedTileFeedbackState extends State<_DraggedTileFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = _DraggedTileFeedback._kFeedbackRadius;
    final width = radius * sqrt(3);
    final height = radius * 2;

    return IgnorePointer(
      child: Transform.translate(
        // Centrée horizontalement sur le point de contact, décalée vers le
        // haut pour flotter au-dessus du doigt plutôt que dessous.
        offset: Offset(-width / 2, -height - 16),
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _HexTilePainter(
                  tile: widget.tile,
                  highlighted: true,
                  alpha: 1.0,
                  sideDepth: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexTilePainter extends CustomPainter {
  const _HexTilePainter({
    required this.tile,
    required this.highlighted,
    required this.alpha,
    required this.sideDepth,
  });

  final HexTile tile;
  final bool highlighted;
  final double alpha;

  /// Épaisseur (px) de la face latérale extrudée vers la droite. 0 pour la
  /// tuile active (premier plan, pas d'effet de profondeur).
  final double sideDepth;

  @override
  void paint(Canvas canvas, Size size) {
    // La face du dessus garde son diamètre plein sur la hauteur, mais son
    // centre est décalé vers la gauche pour laisser la place à la face
    // latérale extrudée sur la droite (sideDepth), exactement comme les
    // tuiles du plateau réservent de la place sous l'hexagone pour leur
    // extrusion verticale.
    final radius = size.height / 2;
    final center = Offset(size.width / 2 - sideDepth / 2, size.height / 2);
    final corners = _corners(center, radius);

    // ── Face latérale (effet bloc 3D, orientée à droite) ──────────────────
    // Même principe que l'extrusion des tuiles du plateau (côtés dont le
    // bord fait face à la direction d'extrusion), mais tournée à 90° :
    // on extrude vers la droite (au lieu du bas) les côtés dont le milieu
    // se trouve à droite du centre, pour donner l'impression que la tuile
    // est vue de biais, comme tournée vers la gauche.
    if (sideDepth > 0.01) {
      for (var i = 0; i < 6; i++) {
        final t0 = corners[i];
        final t1 = corners[(i + 1) % 6];
        final midX = (t0.dx + t1.dx) / 2;
        if (midX < center.dx + 0.01) continue; // côté face à la gauche : ignoré

        final b0 = Offset(t0.dx + sideDepth, t0.dy);
        final b1 = Offset(t1.dx + sideDepth, t1.dy);

        final sidePath = Path()
          ..moveTo(t0.dx, t0.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(b1.dx, b1.dy)
          ..lineTo(b0.dx, b0.dy)
          ..close();

        final baseColor = tile.sides[i].color;
        final shaded = Color.from(
          alpha: baseColor.a,
          red: baseColor.r * 0.62,
          green: baseColor.g * 0.62,
          blue: baseColor.b * 0.62,
        );

        canvas.drawPath(
          sidePath,
          Paint()
            ..color = shaded.withValues(alpha: alpha)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // ── Face du dessus (sixièmes colorés) ─────────────────────────────────
    for (var i = 0; i < 6; i++) {
      final c0 = corners[i];
      final c1 = corners[(i + 1) % 6];
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = tile.sides[i].color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }
  }

  List<Offset> _corners(Offset center, double radius) {
    return List.generate(6, (i) {
      final angleDeg = 60.0 * i - 90.0;
      final angleRad = angleDeg * pi / 180.0;
      return Offset(
        center.dx + radius * cos(angleRad),
        center.dy + radius * sin(angleRad),
      );
    });
  }

  @override
  bool shouldRepaint(covariant _HexTilePainter old) =>
      old.tile != tile ||
      old.highlighted != highlighted ||
      old.alpha != alpha ||
      old.sideDepth != sideDepth;
}

class _RemainingBadge extends StatelessWidget {
  const _RemainingBadge({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 10,
      blurSigma: 10,
      tintColor: _kHudGlass,
      borderColor: _kHudGlassBorder,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
              Icon(Icons.layers,
                  size: 12, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 4),
              Text(
                '$remaining',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
    );
  }
}
