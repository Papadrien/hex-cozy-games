/// Composant Flame pour le rendu d'une tuile hexagonale colorée — Story 1.3.
///
/// Chaque côté est représenté par un triangle coloré du centre vers le côté
/// correspondant, selon la couleur de son [BiomeType].
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import 'hex_cell.dart';
import 'hex_coords.dart';
import 'hex_tile.dart';

/// Correspondance [BiomeType] → couleur d'affichage MVP.
extension BiomeColor on BiomeType {
  Color get color {
    switch (this) {
      case BiomeType.forest:
        return const Color(0xFF4CAF50); // vert
      case BiomeType.village:
        return const Color(0xFFE53935); // rouge
      case BiomeType.plain:
        return const Color(0xFFFFD600); // jaune
      case BiomeType.water:
        return const Color(0xFF1E88E5); // bleu
      case BiomeType.mountain:
        return const Color(0xFF8E24AA); // violet
    }
  }
}

/// Rayon circumscrit par défaut d'une tuile (centre → sommet), en pixels
/// logiques. Doit correspondre à [kBaseHexSize] dans [HexGridComponent].
const double kTileSize = 44.0;

/// Composant Flame représentant une tuile hexagonale colorée.
///
/// [tile]       : la tuile à afficher.
/// [hexSize]    : rayon circumscrit (centre → sommet).
/// [alpha]      : opacité globale (0.0–1.0) — utilisé pour la prévisualisation.
/// [showBorder] : affiche un contour fin blanc entre les triangles.
class TileComponent extends PositionComponent {
  TileComponent({
    required this.tile,
    required HexCoords coords,
    double hexSize = kTileSize,
    double alpha = 1.0,
    bool showBorder = true,
    Vector2? position,
  })  : _hexSize = hexSize,
        _alpha = alpha,
        _showBorder = showBorder,
        _coords = coords,
        super(
          position: position ?? Vector2.zero(),
          anchor: Anchor.center,
          // size logique = bounding-box de l'hexagone
          size: Vector2(sqrt(3) * hexSize, 2 * hexSize),
          priority: 1,
        );

  HexTile tile;
  final HexCoords _coords;
  HexCoords get coords => _coords;

  double _hexSize;
  double get hexSize => _hexSize;
  set hexSize(double value) {
    _hexSize = value;
    size = Vector2(sqrt(3) * value, 2 * value);
  }

  double _alpha;
  double get alpha => _alpha;
  set alpha(double value) => _alpha = value.clamp(0.0, 1.0);

  final bool _showBorder;

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final corners = _corners();
    final center = Offset.zero; // PositionComponent est centré sur anchor

    for (var i = 0; i < 6; i++) {
      final c0 = corners[i];
      final c1 = corners[(i + 1) % 6];

      // Triangle : centre → coin i → coin i+1
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();

      final biomeColor = tile.sides[i].color;
      canvas.drawPath(
        path,
        Paint()
          ..color = biomeColor.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );

      if (_showBorder) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(alpha: _alpha * 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }

    // Contour extérieur de la tuile
    final outline = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (var i = 1; i < 6; i++) {
      outline.lineTo(corners[i].dx, corners[i].dy);
    }
    outline.close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = Colors.white.withValues(alpha: _alpha * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Calcule les 6 sommets de l'hexagone pointy-top centrés en (0, 0).
  List<Offset> _corners() {
    return List.generate(6, (i) {
      // pointy-top : 1er sommet à −30° (nord), puis +60° sens horaire
      final angleDeg = 60.0 * i - 30.0;
      final angleRad = angleDeg * pi / 180.0;
      return Offset(
        _hexSize * cos(angleRad),
        _hexSize * sin(angleRad),
      );
    });
  }
}
