/// Composant Flame pour le rendu d'une tuile hexagonale colorée — Story 1.3.
///
/// Rendu : chaque côté i est un trapèze (ou triangle) allant du centre de
/// l'hexagone vers les deux sommets qui encadrent ce côté.
///
/// Projection isométrique : les coins sont calculés en espace "monde plat"
/// puis la coordonnée Y est multipliée par [kIsoScaleY] avant dessin —
/// c'est la SEULE transformation iso appliquée, ce qui garantit que le rendu
/// interne de chaque tuile est cohérent avec sa position sur le plateau.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import 'hex_cell.dart';
import 'hex_coords.dart';
import 'hex_tile.dart';

/// Facteur d'écrasement vertical isométrique (identique à hex_grid_component).
const double kIsoScaleY = 0.57; // ~tan(30°) → vue à ~30° du plan

/// Correspondance [BiomeType] → couleur d'affichage MVP.
extension BiomeColor on BiomeType {
  Color get color {
    switch (this) {
      case BiomeType.forest:
        return const Color(0xFF43A047); // vert
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

/// Rayon circumscrit par défaut d'une tuile (centre → sommet), en px logiques.
const double kTileSize = 44.0;

/// Composant Flame représentant une tuile hexagonale colorée.
///
/// La projection isométrique est appliquée DANS le rendu (Y *= kIsoScaleY) :
/// le [PositionComponent] est positionné en coordonnées écran "plat", et les
/// coins de l'hexagone sont écrasés au moment du dessin.
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

  double _alpha;
  double get alpha => _alpha;
  set alpha(double value) => _alpha = value.clamp(0.0, 1.0);

  final bool _showBorder;

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    // Coins en espace "plat", la projection Y est appliquée ici.
    final corners = _isoCorners();

    for (var i = 0; i < 6; i++) {
      final c0 = corners[i];
      final c1 = corners[(i + 1) % 6];

      final path = Path()
        ..moveTo(0, 0) // centre de la tuile (anchor = center)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = tile.sides[i].color.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );

      if (_showBorder) {
        // Séparateur entre segments — ligne du centre vers chaque coin
        canvas.drawLine(
          Offset.zero,
          c0,
          Paint()
            ..color = Colors.black.withValues(alpha: _alpha * 0.3)
            ..strokeWidth = 0.6,
        );
      }
    }

    // Contour extérieur
    final outline = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (var i = 1; i < 6; i++) {
      outline.lineTo(corners[i].dx, corners[i].dy);
    }
    outline.close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = Colors.black.withValues(alpha: _alpha * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Calcule les 6 sommets de l'hexagone pointy-top avec projection iso.
  ///
  /// pointy-top : 1er sommet à −90° (nord), puis +60° sens horaire.
  /// Le Y de chaque sommet est multiplié par [kIsoScaleY] pour l'aplatissement.
  List<Offset> _isoCorners() {
    return List.generate(6, (i) {
      final angleDeg = 60.0 * i - 90.0;
      final angleRad = angleDeg * pi / 180.0;
      final x = _hexSize * cos(angleRad);
      final y = _hexSize * sin(angleRad) * kIsoScaleY;
      return Offset(x, y);
    });
  }
}
