/// Composant Flame pour le rendu d'une tuile hexagonale colorée — Story 1.3.
///
/// Rendu : chaque côté i est un trapèze allant du centre de l'hexagone vers
/// les deux sommets qui encadrent ce côté.
///
/// Projection isométrique : les coins sont calculés en espace "monde plat"
/// puis la coordonnée Y est multipliée par [kIsoScaleY] avant dessin.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/constants.dart';
import 'hex_cell.dart';
import 'hex_coords.dart';
import 'hex_tile.dart';

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

/// Épaisseur de base du "bloc" 3D des tuiles (à zoom 1.0).
const double kTileDepth = 10.0;

// ── Ondulation animée de la ligne basse du relief 3D ────────────────────────
// Donne l'impression que le pied de la tuile "trempe" légèrement dans l'eau.

/// Amplitude de l'ondulation (à zoom 1.0), en pixels.
const double kEdgeWaveAmplitude = 1.6;

/// Nombre d'oscillations le long de chaque arête.
const double kEdgeWaveFrequency = 1.5;

/// Vitesse d'animation de l'ondulation (rad/s).
const double kEdgeWaveSpeed = 1.3;

/// Nombre de segments utilisés pour dessiner la ligne ondulée.
const int kEdgeWaveSegments = 8;

const int kTileDepthPriorityBase = 100000;
const int kTileDepthPriorityPreview = kTileDepthPriorityBase + 1000000;

class TileComponent extends PositionComponent {
  TileComponent({
    required HexTile tile,
    required HexCoords coords,
    double hexSize = kHexSize,
    double alpha = 1.0,
    this.highlightedSides = const {},
    Vector2? position,
  })  : _tile = tile,
        _coords = coords,
        _hexSize = hexSize,
        _alpha = alpha,
        super(
          position: position ?? Vector2.zero(),
          anchor: Anchor.center,
          size: Vector2(sqrt(3) * hexSize, 2 * hexSize * kIsoScaleY),
          priority: 1,
        );

  HexTile _tile;
  HexTile get tile => _tile;
  set tile(HexTile value) {
    _tile = value;
  }

  final HexCoords _coords;
  HexCoords get coords => _coords;

  /// Décalage de phase propre à cette tuile (basé sur ses coordonnées) pour
  /// que les tuiles n'ondulent pas toutes de façon parfaitement synchrone.
  late final double _wavePhaseOffset =
      (_coords.q * 0.73 + _coords.r * 1.31).abs() % (2 * pi);

  double _waveTime = 0.0;

  double _hexSize;
  double get hexSize => _hexSize;
  set hexSize(double value) {
    _hexSize = value;
    size = Vector2(sqrt(3) * value, 2 * value * kIsoScaleY);
  }

  void updateDepthPriority() {
    priority = kTileDepthPriorityBase + position.y.round();
  }

  /// Épaisseur du bloc 3D proportionnelle au zoom courant.
  double get _tileDepth => kTileDepth * (_hexSize / kHexSize);

  /// Amplitude de l'ondulation proportionnelle au zoom courant.
  double get _waveAmplitude => kEdgeWaveAmplitude * (_hexSize / kHexSize);

  double _alpha;
  double get alpha => _alpha;
  set alpha(double value) {
    _alpha = value.clamp(0.0, 1.0);
  }

  Set<int> highlightedSides;

  // ── Glow ─────────────────────────────────────────────────────────────────
  Set<int>? _glowSides;
  double _glowAlpha = 0.0;

  void startGlow(List<int> sides) {
    _glowSides = sides.toSet();
    _glowAlpha = kGlowStartAlpha;
  }

  // ── Rendu Canvas (hexagone coloré + effet 3D) ─────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cyTop = size.y / 2 - _tileDepth / 2;
    final topCorners = _isoCorners(cx, cyTop);

    // ── Faces latérales (effet bloc 3D) ──────────────────────────────────
    for (var i = 0; i < 6; i++) {
      final t0 = topCorners[i];
      final t1 = topCorners[(i + 1) % 6];
      final midY = (t0.dy + t1.dy) / 2;
      if (midY < cyTop - 0.01) continue;

      final b0 = Offset(t0.dx, t0.dy + _tileDepth);
      final b1 = Offset(t1.dx, t1.dy + _tileDepth);

      // Ligne basse ondulée (b1 → b0) : les extrémités restent fixes sur les
      // coins pour garder une silhouette fermée, l'ondulation est maximale
      // au milieu de l'arête (effet "trempé dans l'eau").
      final wavyBottom = _wavyEdge(b1, b0, _wavePhaseOffset + i * 0.9);

      final sidePath = Path()
        ..moveTo(t0.dx, t0.dy)
        ..lineTo(t1.dx, t1.dy);
      for (final p in wavyBottom) {
        sidePath.lineTo(p.dx, p.dy);
      }
      sidePath.close();

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

    // ── Polygone central du biome majoritaire ────────────────────────────
    final dominantColor = _dominantBiomeColor();
    if (dominantColor != null) {
      const double innerRatio = 0.32;
      final innerCx = cx;
      final innerCy = cyTop;
      final innerPath = Path();
      for (var i = 0; i < 6; i++) {
        final angleDeg = 60.0 * i - 90.0;
        final angleRad = angleDeg * pi / 180.0;
        final x = innerCx + _hexSize * innerRatio * cos(angleRad);
        final y = innerCy + _hexSize * innerRatio * sin(angleRad) * kIsoScaleY;
        if (i == 0) {
          innerPath.moveTo(x, y);
        } else {
          innerPath.lineTo(x, y);
        }
      }
      innerPath.close();
      canvas.drawPath(
        innerPath,
        Paint()
          ..color = dominantColor.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );
    }

  }

  /// Retourne la couleur du biome majoritaire sur la tuile, ou null en cas
  /// d'égalité.
  Color? _dominantBiomeColor() {
    final counts = <BiomeType, int>{};
    for (final b in tile.sides) {
      counts[b] = (counts[b] ?? 0) + 1;
    }
    BiomeType? dominant;
    int maxCount = 0;
    bool tie = false;
    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominant = entry.key;
        tie = false;
      } else if (entry.value == maxCount) {
        tie = true;
      }
    }
    if (dominant == null || tie) return null;
    return dominant.color;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _waveTime += dt;
    if (_glowSides != null && _glowAlpha > 0.01) {
      _glowAlpha -= (kGlowStartAlpha / kGlowDurationSec) * dt;
      if (_glowAlpha <= 0.01) {
        _glowAlpha = 0.0;
        _glowSides = null;
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Génère les points d'une arête ondulée entre [from] et [to].
  ///
  /// Les extrémités gardent un décalage nul (enveloppe en sinus) afin que
  /// l'arête reste parfaitement raccordée aux coins de l'hexagone — seul le
  /// milieu de l'arête ondule, comme une petite vague le long du pied de
  /// la tuile.
  List<Offset> _wavyEdge(Offset from, Offset to, double phase) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final points = <Offset>[];
    for (var s = 0; s <= kEdgeWaveSegments; s++) {
      final t = s / kEdgeWaveSegments;
      final baseX = from.dx + dx * t;
      final baseY = from.dy + dy * t;
      final envelope = sin(pi * t); // 0 aux extrémités, 1 au centre
      final wave = _waveAmplitude *
          envelope *
          sin(kEdgeWaveFrequency * 2 * pi * t + phase + _waveTime * kEdgeWaveSpeed);
      points.add(Offset(baseX, baseY + wave));
    }
    return points;
  }

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
