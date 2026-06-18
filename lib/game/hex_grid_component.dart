/// Composant Flame gérant l'affichage de la grille hexagonale.
///
/// Story 1.2 : grille invisible, hexagones pointy-top, coordonnées axiales,
///             pan/zoom, hit-testing.
/// Story 1.3 : les cellules posées sont rendues via [TileComponent].
///
/// Projection isométrique : chaque [TileComponent] applique lui-même le
/// facteur kIsoScaleY sur ses coins. La position (x, y) du composant est en
/// coordonnées écran "plates" — on ne multiplie PAS y ici.
library;

import 'dart:math';
import 'dart:ui' show Canvas, Offset;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import 'hex_coords.dart';
import 'hex_cell.dart';
import 'hex_tile.dart';
import 'tile_component.dart'; // kIsoScaleY, TileComponent

/// Taille de base de l'hexagone (rayon circumscrit) en pixels logiques.
const double kBaseHexSize = 48.0;

class HexGridComponent extends PositionComponent {
  HexGridComponent({required this.screenSize})
      : super(position: Vector2.zero(), priority: 0);

  Vector2 screenSize;

  // ── État ──────────────────────────────────────────────────────────────────

  final Map<HexCoords, HexCell> placedCells = {};
  final Map<HexCoords, TileComponent> placedTiles = {};

  // ── Caméra ────────────────────────────────────────────────────────────────

  Vector2 cameraOffset = Vector2.zero();
  double zoom = 1.0;
  static const double minZoom = 0.4;
  static const double maxZoom = 3.0;

  // ── Layout ────────────────────────────────────────────────────────────────

  /// Origine de la grille en coordonnées écran (avant iso).
  /// Décalée à 42 % de la largeur pour laisser la place au HUD droit.
  HexLayout get _layout => HexLayout(
        hexSize: kBaseHexSize * zoom,
        origin: Point(
          cameraOffset.x + screenSize.x * 0.42,
          cameraOffset.y + screenSize.y * 0.38,
        ),
      );

  // ── API publique ───────────────────────────────────────────────────────────

  /// Place une [HexTile] sur [coords].
  void placeTile(HexCoords coords, HexTile tile) {
    final existing = placedTiles.remove(coords);
    if (existing != null) remove(existing);

    final center = _layout.hexToPixel(coords, isoScaleY: kIsoScaleY);

    final component = TileComponent(
      tile: tile,
      coords: coords,
      hexSize: kBaseHexSize * zoom,
      position: Vector2(center.x, center.y),
    );

    placedTiles[coords] = component;
    add(component);

    placedCells[coords] = HexCell(
      q: coords.q,
      r: coords.r,
      biome: _dominantBiome(tile),
    );
  }

  void removeTile(HexCoords coords) {
    final existing = placedTiles.remove(coords);
    if (existing != null) remove(existing);
    placedCells.remove(coords);
  }

  /// Recalcule les positions de toutes les tuiles après un changement de
  /// caméra (pan ou zoom).
  void refreshTilePositions() {
    final layout = _layout;
    for (final entry in placedTiles.entries) {
      final center = layout.hexToPixel(entry.key, isoScaleY: kIsoScaleY);
      entry.value.position = Vector2(center.x, center.y);
      entry.value.hexSize = kBaseHexSize * zoom;
    }
  }

  // ── Rendu (grille invisible — story 1.2) ──────────────────────────────────

  @override
  void render(Canvas canvas) {
    // Rien à dessiner ici : les tuiles sont des PositionComponent enfants,
    // Flame les dessine automatiquement. Les highlights (story 1.5) seront
    // dessinés ici avec la même projection iso que TileComponent.
  }

  // ── Hit-testing ───────────────────────────────────────────────────────────

  void handleTap(Offset screenPos) {
    // L'écran "plat" correspond directement aux coords HexLayout.
    final coords = _layout.pixelToHex(Point(screenPos.dx, screenPos.dy));
    debugPrint('[HexGrid] tap → $coords');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static BiomeType _dominantBiome(HexTile tile) {
    final counts = <BiomeType, int>{};
    for (final b in tile.sides) {
      counts[b] = (counts[b] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
