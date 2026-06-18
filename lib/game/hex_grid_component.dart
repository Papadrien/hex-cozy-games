/// Composant Flame gérant l'affichage de la grille hexagonale.
///
/// Story 1.2 : grille invisible, hexagones pointy-top, coordonnées axiales,
///             projection isométrique à 45°, pan/zoom, hit-testing.
/// Story 1.3 : les cellules posées sont rendues via [TileComponent] au lieu
///             d'un rectangle uni — [placedTiles] mappe les coordonnées vers
///             les composants tuiles actifs.
library;

import 'dart:math';
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import 'hex_coords.dart';
import 'hex_cell.dart';
import 'hex_tile.dart';
import 'tile_component.dart';

/// Taille de base de l'hexagone (rayon circumscrit) en pixels logiques.
const double kBaseHexSize = 44.0;

/// Facteur d'écrasement vertical pour simuler la vue isométrique à 45°.
const double kIsoScaleY = 0.5;

class HexGridComponent extends PositionComponent {
  HexGridComponent({required this.screenSize})
      : super(position: Vector2.zero(), priority: 0);

  Vector2 screenSize;

  // ── État ──────────────────────────────────────────────────────────────────

  /// Données de cellule (biome majoritaire) — conservé pour la compatibilité
  /// avec les stories suivantes (hit-testing, adjacence, etc.).
  final Map<HexCoords, HexCell> placedCells = {};

  /// Composants [TileComponent] actifs, indexés par coordonnées axiales.
  final Map<HexCoords, TileComponent> placedTiles = {};

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

  // ── API publique (story 1.3) ───────────────────────────────────────────────

  /// Place une [HexTile] sur les coordonnées [coords].
  ///
  /// Crée (ou remplace) le [TileComponent] correspondant et l'ajoute à ce
  /// composant. Met à jour [placedCells] pour les logiques d'adjacence.
  void placeTile(HexCoords coords, HexTile tile) {
    // Supprimer un éventuel composant existant
    final existing = placedTiles.remove(coords);
    if (existing != null) remove(existing);

    final layout = _layout;
    final center = layout.hexToPixel(coords);

    final component = TileComponent(
      tile: tile,
      coords: coords,
      hexSize: kBaseHexSize * zoom,
      position: Vector2(center.x, center.y * kIsoScaleY),
    );

    placedTiles[coords] = component;
    add(component);

    // Mettre à jour placedCells (biome majoritaire pour la logique métier)
    placedCells[coords] = HexCell(
      q: coords.q,
      r: coords.r,
      biome: _dominantBiome(tile),
    );
  }

  /// Supprime la tuile posée sur [coords], si elle existe.
  void removeTile(HexCoords coords) {
    final component = placedTiles.remove(coords);
    if (component != null) remove(component);
    placedCells.remove(coords);
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    canvas.save();
    // Projection isométrique : on aplatit l'axe Y (vue à ~45°).
    // Les TileComponent sont positionnés avec Y déjà écrasé (voir placeTile),
    // donc on n'applique PAS kIsoScaleY ici — la transformation reste identité
    // pour le rendu des enfants PositionComponent.
    // En revanche on l'applique pour dessiner les highlights (story 1.5).
    canvas.restore();
  }

  /// Reblit toutes les tuiles existantes quand le zoom/offset change.
  ///
  /// Appelé par [HexBoardGame] à chaque frame si la caméra a bougé.
  void refreshTilePositions() {
    final layout = _layout;
    for (final entry in placedTiles.entries) {
      final center = layout.hexToPixel(entry.key);
      entry.value.position = Vector2(center.x, center.y * kIsoScaleY);
      entry.value.hexSize = kBaseHexSize * zoom;
    }
  }

  // ── Visible coords (pour highlights futurs) ───────────────────────────────

  Set<HexCoords> visibleCoords() {
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

  // ── Hit-testing ───────────────────────────────────────────────────────────

  /// Reçoit un tap depuis l'écran Flutter (coordonnées logiques), le convertit
  /// en [HexCoords] en tenant compte de la projection isométrique.
  void handleTap(Offset screenPos) {
    final worldX = screenPos.dx;
    final worldY = screenPos.dy / kIsoScaleY;
    final coords = _layout.pixelToHex(Point(worldX, worldY));
    debugPrint('[HexGrid] tap → $coords');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Retourne le biome le plus présent sur la tuile (pour [HexCell]).
  static BiomeType _dominantBiome(HexTile tile) {
    final counts = <BiomeType, int>{};
    for (final b in tile.sides) {
      counts[b] = (counts[b] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
