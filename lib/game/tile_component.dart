/// Composant Flame pour le rendu d'une tuile hexagonale — DA procédurale.
///
/// Story 1.3 : rendu originel (aplats biome).
/// DA refonte : texture Voronoï via BiomeTextureRenderer, éclairage
/// directionnel sur les faces latérales.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/constants.dart';
import 'biome_texture_renderer.dart';
import 'hex_cell.dart';
import 'hex_coords.dart';
import 'hex_tile.dart';

export 'biome_texture_renderer.dart' show BiomeBaseColor;

/// Facteur d'écrasement vertical isométrique.
const double kIsoScaleY = 0.57;

/// Durée de l'effet de glow sur les côtés connectés (story 1.6b).
const double kGlowDurationSec = 0.6;
const double kGlowStartAlpha = 0.45;

/// Correspondance [BiomeType] → couleur d'affichage (conservée pour
/// compatibilité avec tile_stack_hud.dart et autres usages).
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

const double kTileDepth = 10.0;
const int kTileDepthPriorityBase = 100000;
const int kTileDepthPriorityPreview = kTileDepthPriorityBase + 1000000;

/// Source de lumière fictive en NW (315°) — angle en radians.
const double _kLightAngleRad = 315.0 * pi / 180.0;

class TileComponent extends PositionComponent {
  TileComponent({
    required this.tile,
    required this._coords,
    double hexSize = kHexSize,
    this._alpha = 1.0,
    this.highlightedSides = const {},
    Vector2? position,
  })  : _hexSize = hexSize,
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
  }

  void updateDepthPriority() {
    priority = kTileDepthPriorityBase + position.y.round();
  }

  double _alpha;
  double get alpha => _alpha;
  set alpha(double value) => _alpha = value.clamp(0.0, 1.0);

  Set<int> highlightedSides;

  // ── Glow ─────────────────────────────────────────────────────────────────

  Set<int>? _glowSides;
  double _glowAlpha = 0.0;

  void startGlow(List<int> sides) {
    _glowSides = sides.toSet();
    _glowAlpha = kGlowStartAlpha;
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cyTop = size.y / 2 - kTileDepth / 2;
    final topCorners = _isoCorners(cx, cyTop);

    // ── 1. Faces latérales avec éclairage directionnel ────────────────────
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

      final baseColor = tile.sides[i].baseColor;
      final shadedColor = _directionalShade(baseColor, i);

      canvas.drawPath(
        sidePath,
        Paint()
          ..color = shadedColor.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );
    }

    // ── 2. Face du dessus : texture Voronoï ───────────────────────────────
    final topPath = Path()..moveTo(topCorners[0].dx, topCorners[0].dy);
    for (var i = 1; i < 6; i++) {
      topPath.lineTo(topCorners[i].dx, topCorners[i].dy);
    }
    topPath.close();

    // Translater le canvas au centre de la tuile pour que BiomeTextureRenderer
    // dessine centré sur (0,0).
    canvas.save();
    canvas.translate(cx, cyTop);

    // Reconstruire le path en coordonnées locales (centrées).
    final centeredPath = Path();
    for (var i = 0; i < 6; i++) {
      final p = topCorners[i];
      if (i == 0) {
        centeredPath.moveTo(p.dx - cx, p.dy - cyTop);
      } else {
        centeredPath.lineTo(p.dx - cx, p.dy - cyTop);
      }
    }
    centeredPath.close();

    paintBiomeTexture(
      canvas: canvas,
      hexPath: centeredPath,
      sides: tile.sides,
      hexSize: _hexSize,
      seed: _coords.q * 73856093 ^ _coords.r * 19349663,
      alpha: _alpha,
    );

    canvas.restore();

    // ── 3. Glow & surbrillances (par-dessus la texture) ───────────────────
    for (var i = 0; i < 6; i++) {
      final c0 = topCorners[i];
      final c1 = topCorners[(i + 1) % 6];

      final sectorPath = Path()
        ..moveTo(cx, cyTop)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();

      if (_glowSides != null && _glowSides!.contains(i) && _glowAlpha > 0.01) {
        canvas.drawPath(
          sectorPath,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: _glowAlpha)
            ..style = PaintingStyle.fill,
        );
      }

      if (highlightedSides.contains(i)) {
        canvas.drawPath(
          sectorPath,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.20)
            ..style = PaintingStyle.fill,
        );
      }
    }
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

  /// Calcule la couleur de la face latérale [i] avec un éclairage directionnel
  /// depuis NW (315°). Les côtés face à la lumière sont plus clairs, les côtés
  /// en ombre sont plus sombres.
  Color _directionalShade(Color base, int sideIndex) {
    // Angle du centre du côté (entre sommet i et i+1, orienté vers le côté).
    final sideAngleDeg = 60.0 * sideIndex - 60.0; // angle normal au côté
    final sideAngleRad = sideAngleDeg * pi / 180.0;

    // Produit scalaire avec la direction lumière.
    final dot = cos(sideAngleRad - _kLightAngleRad);

    // Facteur lumineux : 0.35 (ombre max) → 0.75 (lumière max).
    final factor = (0.55 + dot * 0.20).clamp(0.35, 0.75);

    return Color.from(
      alpha: base.a,
      red: (base.r * factor).clamp(0.0, 1.0),
      green: (base.g * factor).clamp(0.0, 1.0),
      blue: (base.b * factor).clamp(0.0, 1.0),
    );
  }
}
