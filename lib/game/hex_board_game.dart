/// Point d'entrée Flame du jeu.
///
/// Story 1.2 : pan (1 doigt), zoom (2 doigts).
/// Story 1.3 : placement de tuiles de test pour valider le rendu.
/// Story 1.5a : sélection d'emplacement, prévisualisation, rotation.
/// Story 1.5b : validation du placement (second tap), bouton annuler.
/// Story 1.7d : [MultiTouchTapDetector] et [ScaleGestureRecognizer] coexistent
///              mais un flag [_scaleGestureActive] (posé dès le début du scale)
///              empêche onTapUp d'agir après un swipe de rotation. Au lieu de
///              mettre [_skipNextTap] dans [_handleScaleEnd] (trop tard), on
///              utilise [_scaleGestureActive] posé dans [_handleScaleStart].
///              Annulation via croix sur la pile HUD.
///
/// Gestes :
///  - [MultiTouchTapDetector.onTapDown/onTapUp] : tap immobile → sélection,
///    confirmation ou annulation (story 1.7d : la sélection est faite dans
///    onTapUp, pas onTapDown, pour qu'un premier tap ne valide pas).
///  - [ScaleGestureRecognizer] : pan 1 doigt + zoom pinch 2 doigts. Pendant
///    la prévisualisation, le swipe vertical pivote la tuile (story 1.7c).
///  - Le flag [_scaleGestureActive] est levé dans [_handleScaleStart] (dès le
///    début du mouvement) pour désamorcer le onTapUp qui suit inévitablement
///    un swipe (les deux systèmes d'event sont sur des chemins différents).
///    Le flag est nettoyé au microtask suivant via [_handleScaleEnd]. (story 1.7d)
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

  /// Flag actif tant qu'un scale gesture (pan/zoom/rotation) est en cours.
  /// Permet à [onTapUp] de savoir si le pointer up fait partie d'un swipe
  /// (auquel cas il ne doit pas agir). Posé dans [_handleScaleStart] car
  /// [_handleScaleEnd] arrive trop tard (possiblement après [onTapUp]).
  bool _scaleGestureActive = false;

  @override
  Color backgroundColor() => const Color(0xFF1A2332);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _grid = HexGridComponent(screenSize: size.clone());
    add(_grid!);
    _initBoard();
    _syncPlacementPreview();

    // Gesture pour pan (1 doigt) + zoom (pinch 2 doigts).
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
        connectedSides: connectedSides);
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

  // ── Rotation par swipe vertical ──────────────────────────────────────────

  double _rotationAccumulator = 0;
  static const double _kRotationThreshold = 40; // pixels pour 1 cran de 60°

  void _handleRotation(double dy) {
    _rotationAccumulator += dy;
    while (_rotationAccumulator.abs() >= _kRotationThreshold) {
      final step = _rotationAccumulator > 0 ? -1 : 1; // haut = horaire
      _ref.read(placementProvider.notifier).rotate(step);
      _rotationAccumulator -= step.sign * _kRotationThreshold;
    }
  }

  // ── Tap (via MultiTouchTapDetector) ───────────────────────────────────────

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    // Ne rien faire ici — la sélection est gérée dans onTapUp pour éviter
    // qu'un seul tap valide immédiatement le placement (le premier tap doit
    // seulement prévisualiser, pas confirmer).
  }

  @override
  void onTapUp(int pointerId, TapUpInfo info) {
    if (_isPaused) return;
    if (_scaleGestureActive) {
      // Le pointer up fait partie d'un swipe (rotation/pan) — ignorer.
      return;
    }
    final grid = _grid;
    if (grid == null) return;

    final placement = _ref.read(placementProvider);
    final placementNotifier = _ref.read(placementProvider.notifier);
    final coords = grid.hexAt(info.eventPosition.widget.toOffset());

    if (!placement.hasSelection) {
      // Premier tap : sélectionner la cellule pour la prévisualisation.
      if (placementNotifier.availableCells.contains(coords)) {
        placementNotifier.selectCell(coords);
      }
      return;
    }

    if (placement.selected == coords) {
      // Second tap sur la même cellule → validation du placement (story 1.5b)
      confirmPlacement(_ref, onConfirm: placeTileOnFlame);
      _syncPlacementPreview();
      return;
    }

    if (!placementNotifier.availableCells.contains(coords)) {
      // Tap en dehors des emplacements disponibles → annuler la prévisualisation.
      placementNotifier.clearSelection();
      return;
    }

    placementNotifier.selectCell(coords);
  }

  // ── Pan / Zoom / Rotation (via ScaleGestureRecognizer) ──────────────────

  double _scaleStart = 1.0;

  void _handleScaleStart(ScaleStartDetails details) {
    if (_isPaused) return;
    _scaleGestureActive = true;
    _scaleStart = _grid?.zoom ?? 1.0;
    _rotationAccumulator = 0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isPaused) return;
    final grid = _grid;
    if (grid == null) return;

    final delta = details.focalPointDelta;

    // Pendant la prévisualisation, le swipe vertical fait pivoter la tuile.
    final placement = _ref.read(placementProvider);
    if (placement.hasSelection && (details.scale - 1.0).abs() < 0.05) {
      _handleRotation(delta.dy);
      // Pan horizontal seulement pendant la prévisualisation.
      grid.cameraOffset.add(Vector2(delta.dx, 0));
    } else {
      grid.cameraOffset.add(Vector2(delta.dx, delta.dy));
    }

    grid.zoom = (_scaleStart * details.scale)
        .clamp(HexGridComponent.minZoom, HexGridComponent.maxZoom);

    _cameraDirty = true;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isPaused) return;
    _scaleStart = _grid?.zoom ?? 1.0;
    _rotationAccumulator = 0;
    // On ne nettoie pas _scaleGestureActive ici car onTapUp n'a peut-être
    // pas encore été appelé (les deux systèmes d'event sont sur des chemins
    // différents). On le fait au prochain microtask pour laisser à onTapUp
    // le temps de vérifier le flag et de l'ignorer.
    Future.microtask(() => _scaleGestureActive = false);
  }
}
