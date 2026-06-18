/// Point d'entrée Flame du jeu.
///
/// Story 1.2 : pan (1 doigt), zoom (2 doigts).
/// Story 1.3 : placement de tuiles de test pour valider le rendu.
/// Story 1.5a : sélection d'emplacement, prévisualisation, rotation.
/// Story 1.5b : validation du placement (second tap), bouton annuler.
///
/// Gestes — tout géré dans Flame, pas de GestureDetector Flutter par-dessus :
///  - Pan 1 doigt   → [PanDetector.onPanUpdate] : déplace la caméra si AUCUNE
///    prévisualisation n'est en cours ; sinon le delta vertical fait tourner
///    la tuile prévisualisée (swipe vertical = rotation, voir story 1.5a).
///    Ces deux usages ne coexistent jamais sur le même geste, donc pas
///    d'interférence (cf. critère d'acceptance story 1.2b).
///  - Zoom 2 doigts → [ScaleGestureRecognizer] enregistré manuellement dans
///    `onLoad()` pour éviter les conflits d'arène avec PanDetector
///  - Tap           → [MultiTouchTapDetector.onTapDown] : sélectionne/déplace
///    la prévisualisation sur un emplacement disponible (story 1.5a), ou
///    valide le placement si tap sur la cellule déjà sélectionnée (story 1.5b).
library;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/grid_state_provider.dart';
import '../providers/pause_provider.dart';
import '../providers/placement_provider.dart';
import '../providers/placement_commit.dart';
import 'hex_coords.dart';
import 'hex_grid_component.dart';
import 'hex_tile.dart';

/// Nombre de pixels logiques de swipe vertical nécessaires pour déclencher
/// une rotation de 60°. Une valeur assez petite pour qu'un swipe franc sur
/// quelques crans reste confortable en un seul geste (multi-crans).
const double kSwipePixelsPerRotationStep = 36.0;

class HexBoardGame extends FlameGame
    with PanDetector, MultiTouchTapDetector {
  HexBoardGame({required this._ref});

  final WidgetRef _ref;

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
    _syncPlacementPreview();

    // Enregistre ScaleGestureRecognizer manuellement pour le pinch-zoom.
    // On ne mixe PAS ScaleDetector (qui entrerait en conflit d'arène
    // gestuelle avec PanDetector).
    gestureDetectors.add<ScaleGestureRecognizer>(
      ScaleGestureRecognizer.new,
      (ScaleGestureRecognizer instance) {
        instance
          ..onStart = _handleScaleStart
          ..onUpdate = _handleScaleUpdate
          ..onEnd = _handleScaleEnd;
      },
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (_isPaused) return;
    _scaleStart = _grid?.zoom ?? 1.0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isPaused) return;
    final grid = _grid;
    if (grid == null) return;
    grid.zoom = (_scaleStart * details.scale)
        .clamp(HexGridComponent.minZoom, HexGridComponent.maxZoom);
    _cameraDirty = true;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isPaused) return;
    _scaleStart = _grid?.zoom ?? 1.0;
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

    // Reflète l'état initial du plateau de démo dans gridProvider pour
    // que la logique de disponibilité (story 1.5a) soit cohérente avec ce
    // qui est affiché. À terme (story 1.6+), placeTile passera exclusivement
    // par le provider plutôt que par cet appel direct à Flame.
    final notifier = _ref.read(gridProvider.notifier);
    for (final coords in grid.placedTiles.keys) {
      notifier.placeTile(coords, grid.placedTiles[coords]!.tile);
    }
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
    _syncPlacementPreview();
  }

  /// Lit l'état courant des providers de placement/pile et met à jour le
  /// rendu de [HexGridComponent] (highlights + preview) en conséquence.
  /// Polling léger dans `update()` plutôt qu'un abonnement Riverpod direct :
  /// évite de complexifier le cycle de vie du [FlameGame] (qui n'est pas un
  /// widget) pour un état qui change peu souvent (tap/swipe), au prix d'une
  /// lecture par frame qui reste négligeable (comparaisons de Set/objets).
  void _syncPlacementPreview() {
    final grid = _grid;
    if (grid == null) return;

    final placement = _ref.read(placementProvider);
    final placementNotifier = _ref.read(placementProvider.notifier);

    grid.availableHighlights = placementNotifier.availableCells;
    grid.previewCoords = placement.selected;
    grid.previewTile = placementNotifier.previewTile;
  }

  /// Pose la tuile prévisualisée sur la grille Flame (appelé depuis
  /// [confirmPlacement] via le callback [onConfirm]).
  void placeTileOnFlame(HexCoords coords, HexTile tile) {
    _grid?.placeTile(coords, tile);
    _syncPlacementPreview();
  }

  /// Retire une tuile du rendu Flame (appelé depuis le bouton Annuler).
  void removeTileFromFlame(HexCoords coords) {
    _grid?.removeTile(coords);
    _syncPlacementPreview();
  }

  /// Vrai si le jeu est en pause — les gestes doivent être ignorés.
  bool get _isPaused => _ref.read(pauseProvider).isPaused;

  // ── Tap ───────────────────────────────────────────────────────────────────

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (_isPaused) return;
    final grid = _grid;
    if (grid == null) return;

    final coords = grid.hexAt(info.eventPosition.widget.toOffset());
    final placement = _ref.read(placementProvider);

    if (placement.selected == coords) {
      // Second tap sur la même cellule → validation du placement (story 1.5b)
      confirmPlacement(_ref, onConfirm: placeTileOnFlame);
      _syncPlacementPreview();
      return;
    }

    _ref.read(placementProvider.notifier).selectCell(coords);
  }

  // ── Pan : déplacement caméra OU rotation de la prévisualisation ────────────

  double _verticalDragAccumPx = 0.0;

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_isPaused) return;
    final hasSelection = _ref.read(placementProvider).hasSelection;

    if (hasSelection) {
      // Swipe vertical pendant la prévisualisation = rotation (story 1.5a).
      // Le delta global est en pixels logiques d'écran, indépendant du zoom
      // caméra — on veut un geste de rotation à sensibilité constante.
      _verticalDragAccumPx += info.delta.global.y;
      final steps = (_verticalDragAccumPx / kSwipePixelsPerRotationStep)
          .truncate();
      if (steps != 0) {
        _ref.read(placementProvider.notifier).rotate(steps);
        _verticalDragAccumPx -= steps * kSwipePixelsPerRotationStep;
      }
      return;
    }

    _grid?.cameraOffset.add(info.delta.global);
    _cameraDirty = true;
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (_isPaused) return;
    _verticalDragAccumPx = 0.0;
  }

  @override
  void onPanCancel() {
    if (_isPaused) return;
    _verticalDragAccumPx = 0.0;
  }

  // ── Zoom ──────────────────────────────────────────────────────────────────

  double _scaleStart = 1.0;
}
