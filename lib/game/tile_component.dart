library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/constants.dart';
import 'hex_cell.dart';
import 'hex_coords.dart';
import 'hex_tile.dart';

const double kIsoScaleY = 0.57;

const double kGlowDurationSec = 0.6;
const double kGlowStartAlpha = 0.45;

extension BiomeColor on BiomeType {
  Color get color {
    switch (this) {
      case BiomeType.plain:
        return const Color(0xFF8BC34A);
      case BiomeType.flowerField:
        return const Color(0xFFEC407A);
      case BiomeType.forest:
        return const Color(0xFF2E7D32);
      case BiomeType.mountain:
        return const Color(0xFF424242);
      case BiomeType.beach:
        return const Color(0xFFFDD835);
      case BiomeType.water:
        return const Color(0xFF26C6DA);
      case BiomeType.village:
        return const Color(0xFF8D6E63);
    }
  }
}

const double kTileDepthBase = 8.0;

const double kMaxVertexJitter = 0.0;

const int kTileDepthPriorityBase = 100000;
const int kTileDepthPriorityPreview = kTileDepthPriorityBase + 1000000;

/// Facteur de réduction pour le polygone intérieur (biome dominant).
const double _kInnerFactor = 0.35;

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

  double get _reliefDepth => kTileDepthBase;

  BiomeType _dominantBiome() {
    final counts = <BiomeType, int>{};
    for (final side in tile.sides) {
      counts[side] = (counts[side] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Set<int> highlightedSides;

  Set<int>? _glowSides;
  double _glowAlpha = 0.0;

  void startGlow(List<int> sides) {
    _glowSides = sides.toSet();
    _glowAlpha = kGlowStartAlpha;
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final depth = _reliefDepth;
    final cx = size.x / 2;
    final cyTop = size.y / 2 - depth / 2;

    // Corners non-jittered pour le hash des sommets partagés.
    final flatCorners = _isoCorners(cx, cyTop);

    // Jitter déterministe basé sur la position absolue de chaque sommet.
    // Deux tuiles adjacentes partagent les mêmes sommets → même hash → même
    // jitter → plus d'espace visible entre les tuiles.
    final jittered = List<Offset>.generate(6, (i) {
      final c = flatCorners[i];
      final seed = Object.hash(c.dx.toStringAsFixed(2), c.dy.toStringAsFixed(2));
      final rng = Random(seed);
      final dx = (rng.nextDouble() - 0.5) * kMaxVertexJitter;
      final dy = (rng.nextDouble() - 0.5) * kMaxVertexJitter * kIsoScaleY;
      return Offset(c.dx + dx, c.dy + dy);
    });

    // ── Ombre portée au sol ───────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.15 * _alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.y / 2 + depth * 0.6),
        width: _hexSize * 1.6,
        height: _hexSize * kIsoScaleY * 0.6,
      ),
      shadowPaint,
    );

    // ── Halo lumineux (dégradé blanc autour de la tuile) ──────────────────
    final haloPath = Path()..moveTo(jittered[0].dx, jittered[0].dy);
    for (var i = 1; i < 6; i++) {
      haloPath.lineTo(jittered[i].dx, jittered[i].dy);
    }
    haloPath.close();
    // Halo extérieur plus large et visible.
    final haloOuterPath = Path()..moveTo(flatCorners[0].dx, flatCorners[0].dy);
    for (var i = 1; i < 6; i++) {
      haloOuterPath.lineTo(flatCorners[i].dx, flatCorners[i].dy);
    }
    haloOuterPath.close();
    canvas.drawPath(
      haloOuterPath,
      Paint()
        ..shader = Gradient.radial(
          Offset(cx, cyTop),
          _hexSize * kIsoScaleY * 1.4,
          [const Color(0xFFFFFFFF).withValues(alpha: 0.12), const Color(0xFFFFFFFF).withValues(alpha: 0.0)],
          [0.0, 1.0],
        )
        ..style = PaintingStyle.fill,
    );

    // ── Faces latérales (côtés "bas" du bloc) ────────────────────────────
    for (var i = 0; i < 6; i++) {
      final t0 = jittered[i];
      final t1 = jittered[(i + 1) % 6];
      final midY = (t0.dy + t1.dy) / 2;
      if (midY < cyTop - 0.01) continue;

      final b0 = Offset(t0.dx, t0.dy + depth);
      final b1 = Offset(t1.dx, t1.dy + depth);

      final sidePath = Path()
        ..moveTo(t0.dx, t0.dy)
        ..lineTo(t1.dx, t1.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b0.dx, b0.dy)
        ..close();

      final baseColor = tile.sides[i].color;
      final shaded = Color.from(
        alpha: baseColor.a,
        red: baseColor.r * 0.55,
        green: baseColor.g * 0.55,
        blue: baseColor.b * 0.55,
      );
      canvas.drawPath(
        sidePath,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, t0.dy),
            Offset(0, b0.dy),
            [shaded.withValues(alpha: _alpha), shaded.withValues(alpha: _alpha * 0.7)],
          )
          ..style = PaintingStyle.fill,
      );
    }

    // ── Face du dessus avec polygone intérieur (biome dominant) ──────────
    final dominantColor = _dominantBiome().color;

    // Polygone intérieur (hexagone réduit centré).
    final innerCorners = List.generate(6, (i) {
      final outer = jittered[i];
      return Offset(
        cx + (outer.dx - cx) * _kInnerFactor,
        cyTop + (outer.dy - cyTop) * _kInnerFactor,
      );
    });

    // Dessiner la couronne extérieure (trapèzes par côté).
    for (var i = 0; i < 6; i++) {
      final j0 = jittered[i];
      final j1 = jittered[(i + 1) % 6];
      final ii0 = innerCorners[i];
      final ii1 = innerCorners[(i + 1) % 6];

      final outerPath = Path()
        ..moveTo(j0.dx, j0.dy)
        ..lineTo(j1.dx, j1.dy)
        ..lineTo(ii1.dx, ii1.dy)
        ..lineTo(ii0.dx, ii0.dy)
        ..close();

      canvas.drawPath(
        outerPath,
        Paint()
          ..color = tile.sides[i].color.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );
    }

    // Liserés de transition entre biomes (sur la couronne extérieure).
    for (var i = 0; i < 6; i++) {
      final next = (i + 1) % 6;
      if (tile.sides[i].color != tile.sides[next].color) {
        canvas.drawLine(
          jittered[next],
          innerCorners[next],
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
            ..strokeWidth = 1.5,
        );
      }
    }

    // Polygone intérieur (biome dominant).
    final innerPath = Path()..moveTo(innerCorners[0].dx, innerCorners[0].dy);
    for (var i = 1; i < 6; i++) {
      innerPath.lineTo(innerCorners[i].dx, innerCorners[i].dy);
    }
    innerPath.close();
    canvas.drawPath(
      innerPath,
      Paint()
        ..color = dominantColor.withValues(alpha: _alpha)
        ..style = PaintingStyle.fill,
    );

    // ── Écume (contour blanc sur le pourtour extérieur) ──────────────────
    final foamPath = Path()..moveTo(jittered[0].dx, jittered[0].dy);
    for (var i = 1; i < 6; i++) {
      foamPath.lineTo(jittered[i].dx, jittered[i].dy);
    }
    foamPath.close();
    canvas.drawPath(
      foamPath,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * _alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── Glow ──────────────────────────────────────────────────────────────
    for (var i = 0; i < 6; i++) {
      final c0 = jittered[i];
      final c1 = jittered[(i + 1) % 6];
      final path = Path()
        ..moveTo(cx, cyTop)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();

      if (_glowSides != null && _glowSides!.contains(i) && _glowAlpha > 0.01) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: _glowAlpha)
            ..style = PaintingStyle.fill,
        );
      }

      if (highlightedSides.contains(i)) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.20)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // ── Décoration HD2D (sur le polygone intérieur) ──────────────────────
    final decorationSeed = _coords.q * 31 + _coords.r * 17;
    final decorationRng = Random(decorationSeed);
    _drawDecoration(canvas, cx, cyTop, _hexSize, decorationRng);
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

  // ── Décoration HD2D ───────────────────────────────────────────────────────

  void _drawDecoration(Canvas canvas, double cx, double cy, double hx, Random rng) {
    final dominant = _dominantBiome();
    final s = hx / 24;

    switch (dominant) {
      case BiomeType.plain:
        if (rng.nextDouble() < 0.3) {
          _drawPlainDecoration(canvas, cx, cy, s, rng);
        }
      case BiomeType.flowerField:
        _drawFlowerDecoration(canvas, cx, cy, s, rng);
      case BiomeType.forest:
        _drawForestDecoration(canvas, cx, cy, s, rng);
      case BiomeType.mountain:
        _drawMountainDecoration(canvas, cx, cy, s, rng);
      case BiomeType.beach:
        if (rng.nextDouble() < 0.3) _drawRockDecoration(canvas, cx, cy, s, rng);
        if (rng.nextDouble() < 0.3) _drawShell(canvas, cx, cy, s, rng);
      case BiomeType.water:
        if (rng.nextDouble() < 0.3) _drawRipples(canvas, cx, cy, s, rng);
      case BiomeType.village:
        _drawStiltHouse(canvas, cx, cy, s, rng);
    }
  }

  // ── Plaine ────────────────────────────────────────────────────────────────

  void _drawPlainDecoration(Canvas canvas, double cx, double cy, double s, Random rng) {
    final count = 1 + rng.nextInt(2);
    for (var e = 0; e < count; e++) {
      final roll = rng.nextDouble();
      final ex = cx + (rng.nextDouble() - 0.5) * 15 * s;
      final ey = cy + (rng.nextDouble() - 0.5) * 9 * s;
      if (roll < 0.4) {
        _drawPalm(canvas, ex, ey, s, rng);
      } else if (roll < 0.7) {
        _drawStick(canvas, ex, ey, s, rng);
      } else {
        _drawBush(canvas, ex, ey, s, rng);
      }
    }
  }

  void _drawPalm(Canvas canvas, double cx, double cy, double s, Random rng) {
    final baseX = cx + (rng.nextDouble() - 0.5) * 12 * s;
    final baseY = cy + (rng.nextDouble() - 0.5) * 7 * s;
    final h = 10 * s;
    final trunk = Path()
      ..moveTo(baseX - 1.5 * s, baseY)
      ..quadraticBezierTo(baseX + 1 * s, baseY - h * 0.5, baseX - 1 * s, baseY - h);
    canvas.drawPath(
      trunk,
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s,
    );
    for (var i = 0; i < 3; i++) {
      final angle = rng.nextDouble() * pi * 0.6 - pi * 0.3 - pi / 2;
      final len = (4 + rng.nextDouble() * 6) * s;
      final leaf = Path()
        ..moveTo(baseX - 1 * s, baseY - h)
        ..quadraticBezierTo(
          baseX - 1 * s + cos(angle) * len * 0.5,
          baseY - h + sin(angle) * len * 0.5,
          baseX - 1 * s + cos(angle) * len,
          baseY - h + sin(angle) * len,
        );
      canvas.drawPath(
        leaf,
        Paint()
          ..color = const Color(0xFF4CAF50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s,
      );
    }
  }

  void _drawStick(Canvas canvas, double cx, double cy, double s, Random rng) {
    final angle = rng.nextDouble() * pi;
    final len = (4 + rng.nextDouble() * 4) * s;
    canvas.drawLine(
      Offset(cx - cos(angle) * len * 0.5, cy - sin(angle) * len * 0.5),
      Offset(cx + cos(angle) * len * 0.5, cy + sin(angle) * len * 0.5),
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..strokeWidth = 1.5 * s,
    );
    final branchAngle = angle + (rng.nextDouble() - 0.5) * 0.8;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + cos(branchAngle) * len * 0.3, cy + sin(branchAngle) * len * 0.3),
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..strokeWidth = 1.0 * s,
    );
  }

  void _drawBush(Canvas canvas, double cx, double cy, double s, Random rng) {
    final count = 2 + rng.nextInt(3);
    for (var i = 0; i < count; i++) {
      final bx = cx + (rng.nextDouble() - 0.5) * 8 * s;
      final by = cy + (rng.nextDouble() - 0.5) * 5 * s;
      final br = (1.5 + rng.nextDouble() * 2) * s;
      canvas.drawCircle(
        Offset(bx, by),
        br,
        Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.8),
      );
    }
  }

  // ── Forêt ─────────────────────────────────────────────────────────────────

  void _drawForestDecoration(Canvas canvas, double cx, double cy, double s, Random rng) {
    final treeCount = 3 + rng.nextInt(2);
    for (var i = 0; i < treeCount; i++) {
      _drawPalm(canvas, cx, cy, s * (0.7 + rng.nextDouble() * 0.4), rng);
    }
    final bushCount = 2 + rng.nextInt(2);
    for (var i = 0; i < bushCount; i++) {
      _drawBush(canvas, cx, cy, s * (0.7 + rng.nextDouble() * 0.3), rng);
    }
  }

  // ── Fleurs ────────────────────────────────────────────────────────────────

  void _drawFlowerDecoration(Canvas canvas, double cx, double cy, double s, Random rng) {
    final count = 5 + rng.nextInt(3);
    for (var i = 0; i < count; i++) {
      final fx = cx + (rng.nextDouble() - 0.5) * 15 * s;
      final fy = cy + (rng.nextDouble() - 0.5) * 9 * s;
      final r = (1.5 + rng.nextDouble() * 2) * s;
      canvas.drawCircle(
        Offset(fx, fy),
        r,
        Paint()..color = const Color(0xFFF48FB1).withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        Offset(fx, fy),
        r * 0.5,
        Paint()..color = const Color(0xFFFFF176),
      );
    }
  }

  // ── Montagne (rochers 3D) ─────────────────────────────────────────────────

  void _drawMountainDecoration(Canvas canvas, double cx, double cy, double s, Random rng) {
    final count = 1 + rng.nextInt(2);
    for (var i = 0; i < count; i++) {
      final rx = cx + (rng.nextDouble() - 0.5) * 14 * s;
      final ry = cy + (rng.nextDouble() - 0.5) * 8 * s;
      _drawRock(canvas, rx, ry, s * (0.6 + rng.nextDouble() * 0.4), rng);
    }
  }

  void _drawRock(Canvas canvas, double cx, double cy, double s, Random rng) {
    final vertices = 5 + rng.nextInt(3);
    final rockPath = Path();
    for (var i = 0; i < vertices; i++) {
      final angle = 2 * pi * i / vertices + (rng.nextDouble() - 0.5) * 0.4;
      final radius = (2 + rng.nextDouble() * 3) * s;
      final x = cx + cos(angle) * radius;
      final y = cy + sin(angle) * radius * 0.7;
      if (i == 0) {
        rockPath.moveTo(x, y);
      } else {
        rockPath.lineTo(x, y);
      }
    }
    rockPath.close();

    // Base plus sombre.
    canvas.drawPath(rockPath, Paint()..color = const Color(0xFF616161));
    // Highlight pour le volume (décalé vers le haut).
    final highPath = Path();
    for (var i = 0; i < vertices; i++) {
      final angle = 2 * pi * i / vertices + (rng.nextDouble() - 0.5) * 0.4;
      final radius = (1.5 + rng.nextDouble() * 2.5) * s;
      final x = cx + cos(angle) * radius - 1 * s;
      final y = cy + sin(angle) * radius * 0.7 - 1 * s;
      if (i == 0) {
        highPath.moveTo(x, y);
      } else {
        highPath.lineTo(x, y);
      }
    }
    highPath.close();
    canvas.drawPath(highPath, Paint()..color = const Color(0xFF9E9E9E));
  }

  // ── Rocher (pour plage aussi) ─────────────────────────────────────────────

  void _drawRockDecoration(Canvas canvas, double cx, double cy, double s, Random rng) {
    final rx = cx + (rng.nextDouble() - 0.5) * 14 * s;
    final ry = cy + (rng.nextDouble() - 0.5) * 8 * s;
    _drawRock(canvas, rx, ry, s * (0.3 + rng.nextDouble() * 0.2), rng);
  }

  // ── Plage (étoile de mer) ─────────────────────────────────────────────────

  void _drawShell(Canvas canvas, double cx, double cy, double s, Random rng) {
    final sx = cx + (rng.nextDouble() - 0.5) * 14 * s;
    final sy = cy + (rng.nextDouble() - 0.5) * 8 * s;
    final scale = 0.5 + rng.nextDouble() * 0.8;
    final rotation = rng.nextDouble() * 2 * pi;
    final shell = Path();
    for (var i = 0; i < 5; i++) {
      final angle = i * 2 * pi / 5 - pi / 2 + rotation;
      final r = (i.isEven ? 4.0 : 2.0) * s * scale;
      if (i == 0) {
        shell.moveTo(sx + cos(angle) * r, sy + sin(angle) * r);
      } else {
        shell.lineTo(sx + cos(angle) * r, sy + sin(angle) * r);
      }
    }
    shell.close();
    canvas.drawPath(
      shell,
      Paint()
        ..color = const Color(0xFFFFCC80).withValues(alpha: 0.8),
    );
  }

  // ── Eau (ripples) ─────────────────────────────────────────────────────────

  void _drawRipples(Canvas canvas, double cx, double cy, double s, Random rng) {
    for (var i = 0; i < 2; i++) {
      final rx = cx + (rng.nextDouble() - 0.5) * 15 * s;
      final ry = cy + (rng.nextDouble() - 0.5) * 8 * s;
      final ripple = Path()
        ..addOval(Rect.fromCenter(
          center: Offset(rx, ry),
          width: (6 + rng.nextDouble() * 4) * s,
          height: (2 + rng.nextDouble()) * s,
        ));
      canvas.drawPath(
        ripple,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  // ── Village (maison sur pilotis) ──────────────────────────────────────────

  void _drawStiltHouse(Canvas canvas, double cx, double cy, double s, Random rng) {
    final hx2 = cx + (rng.nextDouble() - 0.5) * 12 * s;
    final hy = cy + 4 * s + (rng.nextDouble() - 0.5) * 5 * s;
    for (var i = -1; i <= 1; i += 1) {
      canvas.drawLine(
        Offset(hx2 + i * 3 * s, hy),
        Offset(hx2 + i * 3 * s, hy - 8 * s),
        Paint()
          ..color = const Color(0xFF5D4037)
          ..strokeWidth = 1.5 * s,
      );
    }
    canvas.drawRect(
      Rect.fromCenter(center: Offset(hx2, hy - 8 * s), width: 12 * s, height: 2 * s),
      Paint()..color = const Color(0xFF8D6E63),
    );
    final roof = Path()
      ..moveTo(hx2 - 7 * s, hy - 9 * s)
      ..lineTo(hx2, hy - 16 * s)
      ..lineTo(hx2 + 7 * s, hy - 9 * s)
      ..close();
    canvas.drawPath(
      roof,
      Paint()..color = const Color(0xFFD84315).withValues(alpha: 0.8),
    );
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
