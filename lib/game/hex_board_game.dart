/// Point d'entrée Flame du jeu — story 1.2.
///
/// Gestion des gestes :
///  - Pan 1 doigt : [PanDetector] → met à jour [HexGridComponent.cameraOffset]
///  - Zoom 2 doigts : [ScaleDetector] → met à jour [HexGridComponent.zoom]
///  - Tap : géré en Flutter (GestureDetector dans [GameScreen]) via [onTap]
library;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'hex_grid_component.dart';

class HexBoardGame extends FlameGame with PanDetector, ScaleDetector {
  HexGridComponent? _grid;

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
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    _grid?.screenSize.setFrom(newSize);
    _grid?.size.setFrom(newSize);
  }

  // ── Pan ───────────────────────────────────────────────────────────────────

  @override
  void onPanUpdate(DragUpdateInfo info) {
    _grid?.cameraOffset.add(info.delta.global);
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
      grid.zoom = (_scaleStart! * info.scale.global)
          .clamp(HexGridComponent.minZoom, HexGridComponent.maxZoom);
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _scaleStart = null;
  }
}
