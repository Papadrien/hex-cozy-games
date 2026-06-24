/// Composant Flame pour le rendu d'une tuile hexagonale colorée — Story 1.3 / 1.10a.
///
/// Rendu : chaque côté i est un trapèze allant du centre de l'hexagone vers
/// les deux sommets qui encadrent ce côté.
///
/// Projection isométrique : les coins sont calculés en espace "monde plat"
/// puis la coordonnée Y est multipliée par [kIsoScaleY] avant dessin.
///
/// Story 1.10a — Palmiers sprites :
/// Les palmiers sont rendus via [PalmSpriteComponent] (sprites PNG pré-rendus
/// depuis Blender) ajoutés comme enfants de ce composant. Ils sont positionnés
/// sur les sixièmes [BiomeType.forest] en coordonnées locales du composant.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/constants.dart';
import 'hex_cell.dart';
import 'hex_coords.dart';
import 'hex_tile.dart';
import 'palm_sprite_component.dart';

/// Facteur d'écrasement vertical isométrique.
const double kIsoScaleY = 0.57;

/// Durée de l'effet de glow sur les côtés connectés.
const double kGlowDurationSec = 0.6;

/// Opacité initiale du glow.
const double kGlowStartAlpha = 0.45;

/// Correspondance [BiomeType] → couleur d'affichage.
extension BiomeColor on BiomeType {
  Color get color {
    switch (this) {
      case BiomeType.forest:
        return const Color(0xFF43A047);
      case BiomeType.village:
        return const Color(0xFFE53935);
      case BiomeType.plain:
        return const Color(0xFFFFD600);
      case BiomeType.water:
        return const Color(0xFF1E88E5);
      case BiomeType.mountain:
        return const Color(0xFF8E24AA);
    }
  }
}

/// Épaisseur du "bloc" 3D des tuiles.
const double kTileDepth = 10.0;

const int kTileDepthPriorityBase = 100000;
const int kTileDepthPriorityPreview = kTileDepthPriorityBase + 1000000;

/// Taille d'affichage de base du sprite palmier pour kHexSize normal.
/// Le sprite fait 256px de haut ; on l'affiche à ~80px pour kHexSize=48.
const double kPalmSpriteBaseHeight = 80.0;

class TileComponent extends PositionComponent {
  TileComponent({
    required this.tile,
    required HexCoords coords,
    double hexSize = kHexSize,
    double alpha = 1.0,
    this.highlightedSides = const {},
    Vector2? position,
  })  : _coords = coords,
        _hexSize = hexSize,
        _alpha = alpha,
        super(
          position: position ?? Vector2.zero(),
          anchor: Anchor.center,
          size: Vector2(sqrt(3) * hexSize, 2 * hexSize * kIsoScaleY),
          priority: 1,
        );

  HexTile tile;
  final HexCoords _coords;
  HexCoords get coords => _coords;

  double _hexSize;
  double get hexSize => _hexSize;
  set hexSize(double value) {
    _hexSize = value;
    size = Vector2(sqrt(3) * value, 2 * value * kIsoScaleY);
    _rebuildPalmSprites();
  }

  void updateDepthPriority() {
    priority = kTileDepthPriorityBase + position.y.round();
  }

  double _alpha;
  double get alpha => _alpha;
  set alpha(double value) {
    _alpha = value.clamp(0.0, 1.0);
    // Propager l'opacité aux sprites enfants.
    for (final child in children.whereType<PalmSpriteComponent>()) {
      child.paint.color = child.paint.color.withValues(alpha: _alpha);
    }
  }

  Set<int> highlightedSides;

  // ── Glow ─────────────────────────────────────────────────────────────────
  Set<int>? _glowSides;
  double _glowAlpha = 0.0;

  void startGlow(List<int> sides) {
    _glowSides = sides.toSet();
    _glowAlpha = kGlowStartAlpha;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildPalmSprites();
  }

  /// Construit les [PalmSpriteComponent] enfants pour chaque palmier de la tuile.
  void _buildPalmSprites() {
    // Supprimer les anciens sprites si présents.
    removeWhere((c) => c is PalmSpriteComponent);

    if (tile.palms.isEmpty) return;

    final cx = size.x / 2;
    final cyTop = size.y / 2 - kTileDepth / 2;
    final topCorners = _isoCorners(cx, cyTop);

    for (final palm in tile.palms) {
      if (tile.sides[palm.sideIndex] != BiomeType.forest) continue;

      final offset = _palmOffset(palm, cx, cyTop, topCorners);
      final spriteSize = _palmSpriteSize(palm);

      final spriteComp = PalmSpriteComponent(
        worldOffset: offset,
        displaySize: spriteSize,
        variantIndex: palm.variantIndex,
        alphaValue: _alpha,
      );
      add(spriteComp);
    }
  }

  /// Recrée les sprites après un changement de hexSize (zoom).
  void _rebuildPalmSprites() {
    if (!isMounted) return;
    _buildPalmSprites();
  }

  /// Calcule l'offset local du pied du palmier (anchor: bottomCenter du sprite).
  Vector2 _palmOffset(PalmPlacement palm, double cx, double cyTop, List<Offset> topCorners) {
    final c0 = topCorners[palm.sideIndex];
    final c1 = topCorners[(palm.sideIndex + 1) % 6];

    final midX = (cx + c0.dx + c1.dx) / 3;
    final midY = (cyTop + c0.dy + c1.dy) / 3;

    final baseAngle = atan2(midY - cyTop, midX - cx);
    final angle = baseAngle + palm.angleFrac * 2 * pi;
    final dist = palm.offsetFrac * _hexSize;

    final palmX = cx + cos(angle) * dist;
    final palmY = cyTop + sin(angle) * dist * kIsoScaleY;

    return Vector2(palmX, palmY);
  }

  /// Calcule la taille d'affichage du sprite selon hexSize et scaleFrac.
  Vector2 _palmSpriteSize(PalmPlacement palm) {
    // Hauteur de base proportionnelle au hexSize courant.
    final h = kPalmSpriteBaseHeight * (_hexSize / kHexSize) * palm.scaleFrac;
    // Les deux variantes ont un ratio largeur/hauteur légèrement différent.
    // palm_tree_1 : 284×256 ≈ 1.109, palm_tree_2 : 274×256 ≈ 1.070
    final ratio = palm.variantIndex == 0 ? (284.0 / 256.0) : (274.0 / 256.0);
    return Vector2(h * ratio, h);
  }

  // ── Rendu Canvas (hexagone coloré + effet 3D) ─────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cyTop = size.y / 2 - kTileDepth / 2;
    final topCorners = _isoCorners(cx, cyTop);

    // ── Faces latérales (effet bloc 3D) ──────────────────────────────────
    for (var i = 0; i < 6; i++) {
      final t0 = topCorners[i];
      final t1 = topCorners[(i + 1) % 6];
      final midY = (t0.dy + t1.dy) / 2;
      if (midY < cyTop - 0.01) continue;

      final b0 = Offset(t0.dx, t0.dy + kTileDepth);
      final b1 = Offset(t1.dx, t1.dy + kTileDepth);

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
          ..color = shaded.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Face du dessus ────────────────────────────────────────────────────
    for (var i = 0; i < 6; i++) {
      final c0 = topCorners[i];
      final c1 = topCorners[(i + 1) % 6];

      final path = Path()
        ..moveTo(cx, cyTop)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = tile.sides[i].color.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );

      // Glow.
      if (_glowSides != null && _glowSides!.contains(i) && _glowAlpha > 0.01) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: _glowAlpha)
            ..style = PaintingStyle.fill,
        );
      }

      // Surbrillance côtés connectés.
      if (highlightedSides.contains(i)) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.20)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Les palmiers sont rendus par les PalmSpriteComponent enfants (pas ici).
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_glowSides != null && _glowAlpha > 0.01) {
      _glowAlpha -= (kGlowStartAlpha / kGlowDurationSec) * dt;
      if (_glowAlpha <= 0.01) {
        _glowAlpha = 0.0;
        _glowSides = null;
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<Offset> _isoCorners(double cx, double cy) {
    return List.generate(6, (i) {
      final angleDeg = 60.0 * i - 90.0;
      final angleRad = angleDeg * pi / 180.0;
      final x = cx + _hexSize * cos(angleRad);
      final y = cy + _hexSize * sin(angleRad) * kIsoScaleY;
      return Offset(x, y);
    });
  }
}
