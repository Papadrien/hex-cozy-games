import 'dart:math';
import 'package:flutter/material.dart';
import 'hex_tile.dart';

class HexTilePainter {
  static const double _sideHeight = 14.0;

  static void paint(Canvas canvas, HexTile tile, Offset center, double size,
      {bool ghost = false}) {
    final opacity = ghost ? 0.5 : 1.0;
    final hexPath = _hexPath(center, size);

    // Shadow
    if (!ghost) {
      canvas.drawPath(
        _hexPath(center + const Offset(4, 6), size),
        Paint()
          ..color = Colors.black.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // 3D side faces
    _paintSides(canvas, center, size, tile.center, opacity);

    // 6 wedge segments (one per edge biome)
    _paintEdgeWedges(canvas, tile, center, size, opacity);

    // Center circle with center biome
    _paintCenterCircle(canvas, tile.center, center, size, opacity);

    // Sheen overlay
    canvas.drawPath(
      hexPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: [
            Colors.white.withOpacity(0.13 * opacity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: size))
        ..style = PaintingStyle.fill,
    );

    // Center decoration (inside circle only)
    _paintCenterDeco(canvas, tile.center, center, size, opacity);

    // Outer border
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = Colors.black.withOpacity(0.35 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  static void _paintEdgeWedges(
      Canvas canvas, HexTile tile, Offset center, double size, double opacity) {
    final verts = _hexVertices(center, size);
    for (int i = 0; i < 6; i++) {
      final biome = tile.edges[i];
      final v1 = verts[i];
      final v2 = verts[(i + 1) % 6];

      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(v1.dx, v1.dy)
          ..lineTo(v2.dx, v2.dy)
          ..close(),
        Paint()
          ..color = biome.topColor.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );

      // Thin divider line between wedges
      canvas.drawLine(
        center,
        v1,
        Paint()
          ..color = Colors.black.withOpacity(0.07 * opacity)
          ..strokeWidth = 0.5,
      );
    }
  }

  static void _paintCenterCircle(
      Canvas canvas, Biome biome, Offset center, double size, double opacity) {
    final r = size * 0.40;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = biome.topColor.withOpacity(opacity)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.black.withOpacity(0.20 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  static void _paintCenterDeco(
      Canvas canvas, Biome biome, Offset center, double size, double opacity) {
    final rng = Random(biome.index * 1337);
    final decs = decorationsFor(biome, rng);
    if (decs.isEmpty) return;
    final dec = decs[0];
    final pos = center +
        Offset(
            dec.localOffset.dx * size * 0.45, dec.localOffset.dy * size * 0.45);
    _drawDeco(canvas, dec.type, pos, size * 0.20 * dec.scale, opacity);
  }

  static void _paintSides(Canvas canvas, Offset center, double size,
      Biome biome, double opacity) {
    final verts = _hexVertices(center, size);
    for (final i in [2, 3, 4]) {
      final v1 = verts[i];
      final v2 = verts[(i + 1) % 6];
      final v1b = v1 + Offset(0, _sideHeight);
      final v2b = v2 + Offset(0, _sideHeight);
      final sideColor = i >= 4 ? biome.sideColorLeft : biome.sideColorRight;

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

  static void _drawDeco(
      Canvas canvas, String type, Offset pos, double s, double opacity) {
    final p = Paint()..style = PaintingStyle.fill;

    switch (type) {
      case 'tree':
        p.color = const Color(0xFF6B4226).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(0, s * 0.6),
                width: s * 0.3,
                height: s * 0.7),
            p);
        for (int i = 0; i < 3; i++) {
          p.color = Color.lerp(
                  const Color(0xFF2D6A30), const Color(0xFF5CB85C), i / 2)!
              .withOpacity(opacity);
          canvas.drawPath(
              _tri(pos + Offset(0, s * (0.3 - i * 0.35)),
                  s * (1.1 - i * 0.15), s * (0.8 + i * 0.1)),
              p);
        }
        break;

      case 'house':
        p.color = const Color(0xFFF5DEB3).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(0, s * 0.3),
                width: s * 1.4,
                height: s * 0.9),
            p);
        p.color = const Color(0xFFB22222).withOpacity(opacity);
        canvas.drawPath(_tri(pos + Offset(0, -s * 0.3), s * 1.6, s * 0.8), p);
        p.color = const Color(0xFF8B4513).withOpacity(opacity);
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + Offset(0, s * 0.55),
                width: s * 0.35,
                height: s * 0.5),
            p);
        break;

      case 'peak':
        p.color = Colors.white.withOpacity(opacity);
        canvas.drawPath(_tri(pos, s * 1.1, s * 1.3), p);
        p.color = const Color(0xFF707070).withOpacity(opacity);
        canvas.drawPath(_tri(pos + Offset(0, s * 0.4), s * 1.6, s * 1.0), p);
        break;

      case 'wave':
        final wave = Path()
          ..moveTo(pos.dx - s, pos.dy)
          ..cubicTo(pos.dx - s * 0.5, pos.dy - s * 0.5, pos.dx,
              pos.dy + s * 0.3, pos.dx + s, pos.dy);
        canvas.drawPath(
            wave,
            Paint()
              ..color = Colors.white.withOpacity(0.5 * opacity)
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.35
              ..strokeCap = StrokeCap.round);
        break;

      case 'cactus':
        p.color = const Color(0xFF3A7D44).withOpacity(opacity);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: pos, width: s * 0.4, height: s * 1.4),
                Radius.circular(s * 0.2)),
            p);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: pos + Offset(-s * 0.5, -s * 0.1),
                    width: s * 0.6,
                    height: s * 0.3),
                Radius.circular(s * 0.15)),
            p);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: pos + Offset(s * 0.5, s * 0.1),
                    width: s * 0.6,
                    height: s * 0.3),
                Radius.circular(s * 0.15)),
            p);
        break;

      case 'bush':
        p.color = const Color(0xFF5A9E3A).withOpacity(opacity * 0.9);
        canvas.drawCircle(pos, s * 0.6, p);
        p.color = const Color(0xFF7ABF50).withOpacity(opacity * 0.7);
        canvas.drawCircle(pos + Offset(-s * 0.2, -s * 0.1), s * 0.45, p);
        canvas.drawCircle(pos + Offset(s * 0.25, -s * 0.05), s * 0.4, p);
        break;
    }
  }

  static Path _tri(Offset tip, double w, double h) => Path()
    ..moveTo(tip.dx, tip.dy - h * 0.5)
    ..lineTo(tip.dx - w * 0.5, tip.dy + h * 0.5)
    ..lineTo(tip.dx + w * 0.5, tip.dy + h * 0.5)
    ..close();

  static Path _hexPath(Offset center, double size) {
    final verts = _hexVertices(center, size);
    final path = Path()..moveTo(verts[0].dx, verts[0].dy);
    for (int i = 1; i < 6; i++) {
      path.lineTo(verts[i].dx, verts[i].dy);
    }
    return path..close();
  }

  static List<Offset> _hexVertices(Offset center, double size) {
    return List.generate(6, (i) {
      final angle = pi / 180 * (60 * i);
      return Offset(center.dx + size * cos(angle), center.dy + size * sin(angle));
    });
  }
}

/// Preview painter for the next-tile HUD.
/// Uses 45% of the widget size as hex radius so it fills the box.
class TilePreviewPainter extends CustomPainter {
  final HexTile tile;
  const TilePreviewPainter(this.tile);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Use 45% of the smaller dimension so the hex fills the preview box
    final radius = size.shortestSide * 0.45;
    HexTilePainter.paint(canvas, tile, center, radius);
  }

  @override
  bool shouldRepaint(covariant TilePreviewPainter old) => old.tile != tile;
}
