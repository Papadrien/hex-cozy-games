import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/glb_parser.dart';
import 'tile_component.dart';

class PalmTree3DComponent extends PositionComponent {
  PalmTree3DComponent({
    required super.position,
    required this.treeSize,
    required this.randomSeed,
  }) : _rng = Random(randomSeed);

  final double treeSize;
  final int randomSeed;
  final Random _rng;

  GlbModel? _model;
  bool _loading = false;
  bool _loaded = false;

  // Cached projected triangles: list of (triPoints, color, avgDepth)
  final List<_Tri2D> _triangles = [];
  bool _dirty = true;

  // Rotation angles (radians)
  late double _lookAngle;
  late double _spinAngle;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _lookAngle = -0.55 + _rng.nextDouble() * 0.15;
    _spinAngle = _rng.nextDouble() * 2 * pi;
    _loadModel();
  }

  Future<void> _loadModel() async {
    if (_loading) return;
    _loading = true;
    try {
      final bytes = await rootBundle.load('assets/Palm Tree.glb');
      _model = parseGlb(bytes);
      _loaded = true;
      _dirty = true;
    } catch (e) {
      print('PalmTree3D load error: $e');
    }
  }

  void _projectTriangles() {
    _triangles.clear();
    final model = _model;
    if (model == null) return;

    final scale = treeSize * 0.32;
    final lookAngle = _lookAngle;
    final spinAngle = _spinAngle;
    final cosLook = cos(lookAngle);
    final sinLook = sin(lookAngle);
    final cosSpin = cos(spinAngle);
    final sinSpin = sin(spinAngle);

    // Compute model Y range for height-based coloring
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final prim in model.primitives) {
      final pos = prim.positions;
      for (var i = 0; i < pos.length; i += 3) {
        final y = pos[i + 1];
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    final yRange = maxY - minY;

    for (final prim in model.primitives) {
      final pos = prim.positions;
      final idx = prim.indices;

      for (var i = 0; i < idx.length; i += 3) {
        final i0 = idx[i] * 3;
        final i1 = idx[i + 1] * 3;
        final i2 = idx[i + 2] * 3;

        double avgDepth = 0;
        double avgY = 0;
        final pts = <Offset>[];

        for (final vi in [i0, i1, i2]) {
          double x = pos[vi];
          double y = pos[vi + 1];
          double z = pos[vi + 2];
          avgY += y;

          // Rotate around X axis (look down)
          double y1 = y * cosLook - z * sinLook;
          double z1 = y * sinLook + z * cosLook;

          // Rotate around Y axis (spin)
          double x2 = x * cosSpin + z1 * sinSpin;
          double z2 = -x * sinSpin + z1 * cosSpin;

          avgDepth += z2;
          pts.add(Offset(x2 * scale, -y1 * scale));
        }
        avgDepth /= 3;
        avgY /= 3;

        // Height-based coloring: trunk (brown) at bottom, leaves (green) at top
        final t = yRange > 0 ? ((avgY - minY) / yRange).clamp(0.0, 1.0) : 0.5;
        final color = Color.from(
          alpha: 1.0,
          red: 0.42 + t * 0.2,
          green: 0.25 + t * 0.45,
          blue: 0.08 + t * 0.1,
        );

        _triangles.add(_Tri2D(pts: pts, color: color, avgDepth: avgDepth));
      }
    }

    // Sort by depth (painter's algorithm: farthest first)
    _triangles.sort((a, b) => a.avgDepth.compareTo(b.avgDepth));
    _dirty = false;
  }

  @override
  void render(Canvas canvas) {
    if (!_loaded || _model == null) return;
    if (_dirty) _projectTriangles();

    final sy = kIsoScaleY;

    for (final tri in _triangles) {
      final path = Path()
        ..moveTo(tri.pts[0].dx, tri.pts[0].dy * sy)
        ..lineTo(tri.pts[1].dx, tri.pts[1].dy * sy)
        ..lineTo(tri.pts[2].dx, tri.pts[2].dy * sy)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = tri.color
          ..style = PaintingStyle.fill,
      );
    }
  }

  void updateDepthPriority(double baseY) {
    priority = kTileDepthPriorityBase + baseY.round();
  }
}

class _Tri2D {
  final List<Offset> pts;
  final Color color;
  final double avgDepth;

  const _Tri2D({
    required this.pts,
    required this.color,
    required this.avgDepth,
  });
}
