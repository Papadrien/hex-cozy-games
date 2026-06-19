/// Point d'entrée Flame du jeu.
///
/// Story 1.2 : pan (1 doigt), zoom (2 doigts).
/// Story 1.3 : placement de tuiles de test pour valider le rendu.
/// Story 1.5a : sélection d'emplacement, prévisualisation, rotation.
/// Story 1.5b : validation du placement (second tap), bouton annuler.
///
/// Gestes — tout géré dans Flame, pas de GestureDetector Flutter par-dessus :
///  - Scale (pan+zoom) → [ScaleDetector.onScaleUpdate] : pan 1 doigt + zoom
///    pinch 2 doigts, fonctionne même pendant la prévisualisation.
///  - Tap → [MultiTouchTapDetector.onTapDown] : sélectionne/déplace la
///    prévisualisation sur un emplacement disponible (story 1.5a), valide le
///    placement si tap sur la cellule déjà sélectionnée (story 1.5b), annule
///    la prévisualisation si tap en dehors.
library;

import 'dart:ui' show Color;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/grid_state_provider.dart';
import '../providers/pause_provider.dart';
import '../providers/placement_provider.dart';
import '../providers/placement_commit.dart';
import 'hex_coords.dart';
import 'hex_grid_component.dart';
import 'hex_tile.dart';

class HexBoardGame extends FlameGame
    with MultiTouchTapDetector {
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
    _initBoard();
    _syncPlacementPreview();

    // Gesture unique pour pan (1 doigt) + zoom (pinch 2 doigts).
    // ScaleGestureRecognizer gère les deux sans conflit d'arène.
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

    // Pan : déplacement caméra (1 ou 2 doigts)
    final delta = details.focalPointDelta;
    grid.cameraOffset.add(Vector2(delta.dx, delta.dy));

    // Zoom : pinch à 2 doigts
    grid.zoom = (_scaleStart * details.scale)
        .clamp(HexGridComponent.minZoom, HexGridComponent.maxZoom);

    _cameraDirty = true;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isPaused) return;
    _scaleStart = _grid?.zoom ?? 1.0;
  }

  void _initBoard() {
    final grid = _grid;
    if (grid == null) return;

    final gridState = _ref.read(gridProvider);
    if (gridState.isEmpty) {
      _placeSampleTiles();
    } else {
      // Partie reprise : placer toutes les tuiles restaurées sur Flame.
      for (final entry in gridState.placedTiles.entries) {
        grid.placeTile(entry.key, entry.value);
      }
    }
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

    // Reflète l'état initial du plateau de démo dans gridProvider.
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

    // Côtés bien connectés et tuiles bonus à montrer sur la prévisualisation.
    final reward = _ref.read(previewRewardProvider);
    grid.previewHighlightedSides = reward.connectedSides.toSet();
    grid.previewBonusTiles = reward.bonusTiles;

    // Surbrillance des voisins qui seront connectés.
    final neighborHighlights = <HexCoords, Set<int>>{};
    if (placement.selected != null) {
      for (final side in reward.connectedSides) {
        final neighborCoords = placement.selected!.neighbor(side);
        final facingSide = (side + 3) % 6;
        neighborHighlights.putIfAbsent(neighborCoords, () => {}).add(facingSide);
      }
    }
    grid.previewNeighborHighlights = neighborHighlights;
  }

  /// Pose la tuile prévisualisée sur la grille Flame (appelé depuis
  /// [confirmPlacement] via le callback [onConfirm]).
  void placeTileOnFlame(
    HexCoords coords,
    HexTile tile,
    List<int> connectedSides,
    int bonusTiles,
  ) {
    _grid?.placeTile(coords, tile,
        connectedSides: connectedSides,
        highlightedSides: connectedSides.toSet());
    if (connectedSides.isNotEmpty || bonusTiles > 0) {
      _grid?.showRewardIndicators(coords, connectedSides, bonusTiles: bonusTiles);
    }
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
    final placementNotifier = _ref.read(placementProvider.notifier);

    if (placement.selected == coords) {
      // Second tap sur la même cellule → validation du placement (story 1.5b)
      confirmPlacement(_ref, onConfirm: placeTileOnFlame);
      _syncPlacementPreview();
      return;
    }

    if (placement.hasSelection && !placementNotifier.availableCells.contains(coords)) {
      // Tap en dehors des emplacements disponibles → annuler la prévisualisation.
      placementNotifier.clearSelection();
      return;
    }

    placementNotifier.selectCell(coords);
  }

  double _scaleStart = 1.0;
}
