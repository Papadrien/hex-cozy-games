import 'dart:math';
import 'package:flutter/material.dart';
import 'hex_tile.dart';

// Draws a single hex tile with pseudo-3D relief effect
class HexTilePainter {
  static const double _sideHeight = 14.0;

  static void paint(Canvas canvas, HexTile tile, Offset center, double size,
      {bool highlighted = false, bool ghost = false}) {
    final opacity = ghost ? 0.5 : 1.0;
    final path = _hexPath(center, size);

    // Shadow
    if (!ghost) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(
          _hexPath(center + const Offset(4, 6), size), shadowPaint);
    }

    // Bottom side faces (pseudo-3D)
    _paintSides(canvas, center, size, tile.biome, opacity);

    // Top face
    final topPaint = Paint()
      ..color = tile.biome.topColor.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, topPaint);

    // Subtle top gradient overlay
    final gradPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.9,
        colors: [
          Colors.white.withOpacity(0.18 * opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, gradPaint);

    // Draw decorations
    _paintDecorations(canvas, tile.biome, center, size, opacity);

    // Border
    final borderPaint = Paint()
      ..color = (highlighted
              ? Colors.yellow
              : Colors.black.withOpacity(0.35 * opacity))
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlighted ? 3.0 : 1.2;
    canvas.drawPath(path, borderPaint);
  }

  static void _paintSides(
      Canvas canvas, Offset center, double size, Biome biome, double opacity) {
    // Only paint bottom-facing sides (directions 3,4,5 in flat-top)
    // We simulate 3D by drawing parallelograms below the bottom edges
    final vertices = _hexVertices(center, size);
    final bottomSideIndices = [2, 3, 4]; // bottom-right, bottom, bottom-left

    for (final i in bottomSideIndices) {
      final v1 = vertices[i];
      final v2 = vertices[(i + 1) % 6];
      final v1b = v1 + Offset(0, _sideHeight);
      final v2b = v2 + Offset(0, _sideHeight);

      final isLeft = i >= 4;
      final sideColor =
          isLeft ? biome.sideColorLeft : biome.sideColorRight;

      final sidePaint = Paint()
        ..color = sideColor.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      final sidePath = Path()
        ..moveTo(v1.dx, v1.dy)
        ..lineTo(v2.dx, v2.dy)
        ..lineTo(v2b.dx, v2b.dy)
        ..lineTo(v1b.dx, v1b.dy)
        ..close();

      canvas.drawPath(sidePath, sidePaint);

      // Edge line
      final edgePaint = Paint()
        ..color = Colors.black.withOpacity(0.2 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawPath(sidePath, edgePaint);
    }
  }

  static void _paintDecorations(
      Canvas canvas, Biome biome, Offset center, double size, double opacity) {
    final rng = Random(biome.index * 1337);
    final decs = decorationsFor(biome, rng);

    for (final dec in decs) {
      final pos = center +
          Offset(dec.localOffset.dx * size * 1.2,
              dec.localOffset.dy * size * 1.2);
      _paintDecoration(canvas, dec.type, pos, size * 0.28 * dec.scale, opacity);
    }
  }

  static void _paintDecoration(
      Canvas canvas, String type, Offset pos, double s, double opacity) {
    final paint = Paint()..style = PaintingStyle.fill;

    switch (type) {
      case 'tree':
        // Trunk
        paint.color = const Color(0xFF6B4226).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(0, s * 0.6), width: s * 0.3, height: s * 0.7),
            paint);
        // Canopy layers
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
        // Walls
        paint.color = const Color(0xFFF5DEB3).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(0, s * 0.3),
                width: s * 1.4,
                height: s * 0.9),
            paint);
        // Roof
        paint.color = const Color(0xFFB22222).withOpacity(opacity);
        canvas.drawPath(
            _triangle(pos + Offset(0, -s * 0.3), s * 1.6, s * 0.8), paint);
        // Door
        paint.color = const Color(0xFF8B4513).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(0, s * 0.55),
                width: s * 0.35,
                height: s * 0.5),
            paint);
        // Window
        paint.color = const Color(0xFF87CEEB).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(-s * 0.45, s * 0.15),
                width: s * 0.35,
                height: s * 0.3),
            paint);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(s * 0.45, s * 0.15),
                width: s * 0.35,
                height: s * 0.3),
            paint);
        break;

      case 'peak':
        // Snow cap
        paint.color = const Color(0xFFFFFFFF).withOpacity(opacity);
        canvas.drawPath(_triangle(pos, s * 1.1, s * 1.3), paint);
        // Rock body
        paint.color = const Color(0xFF707070).withOpacity(opacity);
        canvas.drawPath(
            _triangle(pos + Offset(0, s * 0.4), s * 1.6, s * 1.0), paint);
        break;

      case 'wave':
        paint.color = const Color(0xFFFFFFFF).withOpacity(0.45 * opacity);
        final wavePath = Path();
        wavePath.moveTo(pos.dx - s, pos.dy);
        wavePath.cubicTo(pos.dx - s * 0.5, pos.dy - s * 0.5, pos.dx,
            pos.dy + s * 0.3, pos.dx + s, pos.dy);
        final wavePaintLine = Paint()
          ..color = Colors.white.withOpacity(0.5 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.35
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(wavePath, wavePaintLine);
        break;

      case 'cactus':
        paint.color = const Color(0xFF3A7D44).withOpacity(opacity);
        // Main stem
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: pos, width: s * 0.4, height: s * 1.4),
                Radius.circular(s * 0.2)),
            paint);
        // Arms
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
      // flat-top hex: angles at 0°, 60°, 120°...
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
