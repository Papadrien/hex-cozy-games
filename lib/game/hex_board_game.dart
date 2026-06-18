/// Point d'entrée Flame du jeu.
///
/// Story 1.2 : pan (1 doigt), zoom (2 doigts), tap déléguée à HexGridComponent.
/// Story 1.3 : placement de tuiles de test pour valider le rendu [TileComponent].
library;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'hex_coords.dart';
import 'hex_grid_component.dart';
import 'hex_tile.dart';

class HexBoardGame extends FlameGame with PanDetector, ScaleDetector {
  HexGridComponent? _grid;

  bool _cameraDirty = false;

  /// Callback appelé par le GestureDetector Flutter lors d'un tap.
  void onTap(Offset screenPosition) {
    _grid?.handleTap(screenPosition);
  }

  @override
  Color backgroundColor() => const Color(0xFF1A2332);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _grid = HexGridComponent(screenSize: size.clone());
    add(_grid!);

    // ── Tuiles de test (story 1.3) ────────────────────────────────────────
    // Pose quelques tuiles du pool sur les premières cellules pour valider
    // le rendu. Ces appels seront retirés dès la story 1.5 (placement joueur).
    _placeSampleTiles();
  }

  void _placeSampleTiles() {
    final grid = _grid;
    if (grid == null) return;

    // Tuile centrale : forêt/eau (index 2 du pool)
    grid.placeTile(HexCoords(0, 0), kTilePool[2]);
    // Voisins immédiats avec des tuiles variées
    grid.placeTile(HexCoords(1, -1), kTilePool[3]);
    grid.placeTile(HexCoords(1, 0), kTilePool[7]);
    grid.placeTile(HexCoords(0, 1), kTilePool[8]);
    grid.placeTile(HexCoords(-1, 1), kTilePool[9]);
    grid.placeTile(HexCoords(-1, 0), kTilePool[10]);
    grid.placeTile(HexCoords(0, -1), kTilePool[11]);
    // Deuxième couronne partielle
    grid.placeTile(HexCoords(2, -1), kTilePool[4]);
    grid.placeTile(HexCoords(2, -2), kTilePool[5]);
    grid.placeTile(HexCoords(1, -2), kTilePool[6]);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _grid?.screenSize.setFrom(size);
    _grid?.size.setFrom(size);
    _cameraDirty = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_cameraDirty) {
      _grid?.refreshTilePositions();
      _cameraDirty = false;
    }
  }

  // ── Pan ───────────────────────────────────────────────────────────────────

  @override
  void onPanUpdate(DragUpdateInfo info) {
    _grid?.cameraOffset.add(info.delta.global);
    _cameraDirty = true;
  }

  // ── Zoom ──────────────────────────────────────────────────────────────────

  double? _scaleStart;

  @override
  void onScaleStart(ScaleStartInfo info) {
    _scaleStart = _grid?.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final grid = _grid;
    if (grid != null && _scaleStart != null) {
      grid.zoom = (_scaleStart! * info.scale.global.x)
          .clamp(HexGridComponent.minZoom, HexGridComponent.maxZoom);
      _cameraDirty = true;
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _scaleStart = null;
  }
}
