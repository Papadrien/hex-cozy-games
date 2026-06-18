/// Point d'entrée Flame du jeu.
///
/// Story 1.2 : pan (1 doigt), zoom (2 doigts).
/// Story 1.3 : placement de tuiles de test pour valider le rendu.
///
/// Gestes — tout géré dans Flame, pas de GestureDetector Flutter par-dessus :
///  - Pan 1 doigt   → [PanDetector.onPanUpdate]
///  - Zoom 2 doigts → [ScaleDetector]  (note : PanDetector + ScaleDetector
///    coexistent correctement dans Flame ; le Scale absorbe le multi-touch)
///  - Tap           → [TapDetector.onTapDown]
library;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'hex_coords.dart';
import 'hex_grid_component.dart';
import 'hex_tile.dart';

class HexBoardGame extends FlameGame
    with PanDetector, ScaleDetector, MultiTouchTapDetector {
  HexGridComponent? _grid;

  bool _cameraDirty = false;

  @override
  Color backgroundColor() => const Color(0xFF1A2332);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _grid = HexGridComponent(screenSize: size.clone());
    add(_grid!);
    _placeSampleTiles();
  }

  void _placeSampleTiles() {
    final grid = _grid;
    if (grid == null) return;

    grid.placeTile(HexCoords(0, 0),  kTilePool[2]);
    grid.placeTile(HexCoords(1, -1), kTilePool[3]);
    grid.placeTile(HexCoords(1, 0),  kTilePool[7]);
    grid.placeTile(HexCoords(0, 1),  kTilePool[8]);
    grid.placeTile(HexCoords(-1, 1), kTilePool[9]);
    grid.placeTile(HexCoords(-1, 0), kTilePool[10]);
    grid.placeTile(HexCoords(0, -1), kTilePool[11]);
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

  // ── Tap ───────────────────────────────────────────────────────────────────

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    _grid?.handleTap(info.eventPosition.widget.toOffset());
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
