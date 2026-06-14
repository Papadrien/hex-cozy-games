import 'dart:math';
import 'package:flutter/material.dart';
import 'hex_tile.dart';

// Draws a single hex tile with multi-biome segments (Dorfromantik style)
class HexTilePainter {
  static const double _sideHeight = 14.0;

  static void paint(Canvas canvas, HexTile tile, Offset center, double size,
      {bool highlighted = false, bool ghost = false}) {
    final opacity = ghost ? 0.5 : 1.0;
    final hexPath = _hexPath(center, size);

    // Shadow
    if (!ghost) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(
          _hexPath(center + const Offset(4, 6), size), shadowPaint);
    }

    // Bottom side faces (pseudo-3D) based on center biome
    _paintSides(canvas, center, size, tile.center, opacity);

    // Paint each of the 6 edge wedge segments
    _paintEdgeSegments(canvas, tile, center, size, opacity);

    // Center circle with center biome
    _paintCenter(canvas, tile.center, center, size, opacity);

    // Subtle top gradient overlay
    final gradPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.9,
        colors: [
          Colors.white.withOpacity(0.14 * opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size))
      ..style = PaintingStyle.fill;
    canvas.drawPath(hexPath, gradPaint);

    // Center decoration
    _paintCenterDecoration(canvas, tile.center, center, size, opacity);

    // Border
    final borderPaint = Paint()
      ..color = (highlighted
              ? Colors.yellow
              : Colors.black.withOpacity(0.35 * opacity))
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlighted ? 3.0 : 1.2;
    canvas.drawPath(hexPath, borderPaint);
  }

  /// Paints 6 wedge-shaped segments from center to each edge
  static void _paintEdgeSegments(
      Canvas canvas, HexTile tile, Offset center, double size, double opacity) {
    final verts = _hexVertices(center, size);

    for (int i = 0; i < 6; i++) {
      final biome = tile.edges[i];
      final v1 = verts[i];
      final v2 = verts[(i + 1) % 6];

      // Wedge from center to edge i
      final wedgePath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(v1.dx, v1.dy)
        ..lineTo(v2.dx, v2.dy)
        ..close();

      canvas.drawPath(
        wedgePath,
        Paint()
          ..color = biome.topColor.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );

      // Subtle divider between segments
      final dividerPaint = Paint()
        ..color = Colors.black.withOpacity(0.08 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      canvas.drawLine(center, v1, dividerPaint);
    }
  }

  /// Paints a circle in the center with the center biome color
  static void _paintCenter(
      Canvas canvas, Biome biome, Offset center, double size, double opacity) {
    final r = size * 0.38;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = biome.topColor.withOpacity(opacity)
        ..style = PaintingStyle.fill,
    );
    // Subtle ring
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.black.withOpacity(0.18 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  /// Paints the decoration icon in the center circle area only
  static void _paintCenterDecoration(
      Canvas canvas, Biome biome, Offset center, double size, double opacity) {
    final rng = Random(biome.index * 1337);
    final decs = decorationsFor(biome, rng);

    // Only draw first decoration, scaled to fit center circle
    if (decs.isNotEmpty) {
      final dec = decs[0];
      final pos = center +
          Offset(dec.localOffset.dx * size * 0.5,
              dec.localOffset.dy * size * 0.5);
      _paintDecoration(
          canvas, dec.type, pos, size * 0.22 * dec.scale, opacity);
    }
  }

  static void _paintSides(
      Canvas canvas, Offset center, double size, Biome biome, double opacity) {
    final vertices = _hexVertices(center, size);
    final bottomSideIndices = [2, 3, 4];

    for (final i in bottomSideIndices) {
      final v1 = vertices[i];
      final v2 = vertices[(i + 1) % 6];
      final v1b = v1 + Offset(0, _sideHeight);
      final v2b = v2 + Offset(0, _sideHeight);

      final isLeft = i >= 4;
      final sideColor = isLeft ? biome.sideColorLeft : biome.sideColorRight;

      canvas.drawPath(
        Path()
          ..moveTo(v1.dx, v1.dy)
          ..lineTo(v2.dx, v2.dy)
          ..lineTo(v2b.dx, v2b.dy)
          ..lineTo(v1b.dx, v1b.dy)
          ..close(),
        Paint()
          ..color = sideColor.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );
    }
  }

  static void _paintDecoration(
      Canvas canvas, String type, Offset pos, double s, double opacity) {
    final paint = Paint()..style = PaintingStyle.fill;

    switch (type) {
      case 'tree':
        paint.color = const Color(0xFF6B4226).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(0, s * 0.6),
                width: s * 0.3,
                height: s * 0.7),
            paint);
        for (int i = 0; i < 3; i++) {
          paint.color = Color.lerp(const Color(0xFF2D6A30),
                  const Color(0xFF5CB85C), i / 2)!
              .withOpacity(opacity);
          canvas.drawPath(
              _triangle(pos + Offset(0, s * (0.3 - i * 0.35)),
                  s * (1.1 - i * 0.15), s * (0.8 + i * 0.1)),
              paint);
        }
        break;

      case 'house':
        paint.color = const Color(0xFFF5DEB3).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(0, s * 0.3),
                width: s * 1.4,
                height: s * 0.9),
            paint);
        paint.color = const Color(0xFFB22222).withOpacity(opacity);
        canvas.drawPath(
            _triangle(pos + Offset(0, -s * 0.3), s * 1.6, s * 0.8), paint);
        paint.color = const Color(0xFF8B4513).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(0, s * 0.55),
                width: s * 0.35,
                height: s * 0.5),
            paint);
        break;

      case 'peak':
        paint.color = const Color(0xFFFFFFFF).withOpacity(opacity);
        canvas.drawPath(_triangle(pos, s * 1.1, s * 1.3), paint);
        paint.color = const Color(0xFF707070).withOpacity(opacity);
        canvas.drawPath(
            _triangle(pos + Offset(0, s * 0.4), s * 1.6, s * 1.0), paint);
        break;

      case 'wave':
        final wavePath = Path();
        wavePath.moveTo(pos.dx - s, pos.dy);
        wavePath.cubicTo(pos.dx - s * 0.5, pos.dy - s * 0.5, pos.dx,
            pos.dy + s * 0.3, pos.dx + s, pos.dy);
        canvas.drawPath(
            wavePath,
            Paint()
              ..color = Colors.white.withOpacity(0.5 * opacity)
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.35
              ..strokeCap = StrokeCap.round);
        break;

      case 'cactus':
        paint.color = const Color(0xFF3A7D44).withOpacity(opacity);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: pos, width: s * 0.4, height: s * 1.4),
                Radius.circular(s * 0.2)),
            paint);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: pos + Offset(-s * 0.5, -s * 0.1),
                    width: s * 0.6,
                    height: s * 0.3),
                Radius.circular(s * 0.15)),
            paint);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: pos + Offset(s * 0.5, s * 0.1),
                    width: s * 0.6,
                    height: s * 0.3),
                Radius.circular(s * 0.15)),
            paint);
        break;

      case 'bush':
        paint.color = const Color(0xFF5A9E3A).withOpacity(opacity * 0.9);
        canvas.drawCircle(pos, s * 0.6, paint);
        paint.color = const Color(0xFF7ABF50).withOpacity(opacity * 0.7);
        canvas.drawCircle(pos + Offset(-s * 0.2, -s * 0.1), s * 0.45, paint);
        canvas.drawCircle(pos + Offset(s * 0.25, -s * 0.05), s * 0.4, paint);
        break;
    }
  }

  static Path _triangle(Offset tip, double width, double height) {
    return Path()
      ..moveTo(tip.dx, tip.dy - height * 0.5)
      ..lineTo(tip.dx - width * 0.5, tip.dy + height * 0.5)
      ..lineTo(tip.dx + width * 0.5, tip.dy + height * 0.5)
      ..close();
  }

  static Path _hexPath(Offset center, double size) {
    final path = Path();
    final verts = _hexVertices(center, size);
    path.moveTo(verts[0].dx, verts[0].dy);
    for (int i = 1; i < 6; i++) {
      path.lineTo(verts[i].dx, verts[i].dy);
    }
    path.close();
    return path;
  }

  static List<Offset> _hexVertices(Offset center, double size) {
    return List.generate(6, (i) {
      final angle = pi / 180 * (60 * i);
      return Offset(
        center.dx + size * cos(angle),
        center.dy + size * sin(angle),
      );
    });
  }
}

// For the HUD preview of next tile
class TilePreviewPainter extends CustomPainter {
  final HexTile tile;
  TilePreviewPainter(this.tile);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    HexTilePainter.paint(canvas, tile, center, size.width * 0.38);
  }

  @override
  bool shouldRepaint(covariant TilePreviewPainter old) => old.tile != tile;
}
