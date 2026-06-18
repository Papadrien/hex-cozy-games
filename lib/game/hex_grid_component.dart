/// Composant Flame gérant l'affichage de la grille hexagonale.
///
/// Story 1.2 :
///  - Grille invisible (aucun contour de cellule)
///  - Hexagones pointy-top, coordonnées axiales
///  - Projection isométrique à 45° (scaleY = 0.5)
///  - Hit-testing via [handleTap] (appelé depuis HexBoardGame)
library;

import 'dart:math';
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import 'hex_coords.dart';
import 'hex_cell.dart';

/// Taille de base de l'hexagone (rayon circumscrit) en pixels logiques.
const double kBaseHexSize = 44.0;

/// Facteur d'écrasement vertical pour simuler la vue isométrique à 45°.
const double kIsoScaleY = 0.5;

class HexGridComponent extends PositionComponent {
  HexGridComponent({required this.screenSize})
      : super(position: Vector2.zero(), priority: 0);

  Vector2 screenSize;

  // ── État ──────────────────────────────────────────────────────────────────

  final Map<HexCoords, HexCell> placedCells = {};

  // ── Vue ───────────────────────────────────────────────────────────────────

  Vector2 cameraOffset = Vector2.zero();
  double zoom = 1.0;
  static const double minZoom = 0.4;
  static const double maxZoom = 3.0;

  // ── Layout ────────────────────────────────────────────────────────────────

  HexLayout get _layout => HexLayout(
        hexSize: kBaseHexSize * zoom,
        origin: Point(
          cameraOffset.x + screenSize.x * 0.42,
          cameraOffset.y + screenSize.y * 0.5,
        ),
      );

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    canvas.save();
    // Projection isométrique : on aplatit l'axe Y de moitié (vue à ~45°).
    // Matrice column-major 4×4 pour canvas.transform :
    //   col0=[1,0,0,0] col1=[0,0.5,0,0] col2=[0,0,1,0] col3=[0,0,0,1]
    canvas.transform(
      Float64List.fromList([
        1.0, 0.0, 0.0, 0.0,
        0.0, kIsoScaleY, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
      ]),
    );
    _renderCells(canvas);
    canvas.restore();
  }

  void _renderCells(Canvas canvas) {
    final layout = _layout;
    for (final coords in _visibleCoords()) {
      final center = layout.hexToPixel(coords);
      _drawCell(canvas, coords, center, layout);
    }
  }

  Set<HexCoords> _visibleCoords() {
    if (placedCells.isEmpty) return _disk(HexCoords(0, 0), 5);
    final cells = <HexCoords>{};
    for (final c in placedCells.keys) {
      cells.add(c);
      for (final n in c.neighbors) {
        cells.add(n);
        for (final n2 in n.neighbors) {
          cells.add(n2);
        }
      }
    }
    return cells;
  }

  Set<HexCoords> _disk(HexCoords center, int radius) {
    final result = <HexCoords>{};
    for (var q = -radius; q <= radius; q++) {
      final r1 = max(-radius, -q - radius);
      final r2 = min(radius, -q + radius);
      for (var r = r1; r <= r2; r++) {
        result.add(HexCoords(center.q + q, center.r + r));
      }
    }
    return result;
  }

  void _drawCell(
    Canvas canvas,
    HexCoords coords,
    Point<double> center,
    HexLayout layout,
  ) {
    final corners = layout.hexCorners(center);
    final path = Path()..moveTo(corners[0].x, corners[0].y);
    for (var i = 1; i < 6; i++) {
      path.lineTo(corners[i].x, corners[i].y);
    }
    path.close();

    if (placedCells.containsKey(coords)) {
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFF607D8B).withValues(alpha: 0.8),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF37474F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
    // Cellule vide : rien (grille invisible — règle story 1.2)
  }

  // ── Hit-testing ───────────────────────────────────────────────────────────

  /// Reçoit un tap depuis l'écran Flutter (coordonnées logiques), le convertit
  /// en [HexCoords] en tenant compte de la projection isométrique, et loggue
  /// le résultat (story 1.5 transmettra ces coords au provider de placement).
  void handleTap(Offset screenPos) {
    final worldX = screenPos.dx;
    final worldY = screenPos.dy / kIsoScaleY; // inverse la compression Y
    final coords = _layout.pixelToHex(Point(worldX, worldY));
    debugPrint('[HexGrid] tap → $coords');
  }
}
