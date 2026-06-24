/// Point d'entrée Flame du jeu.
///
/// Story 1.2 : pan (1 doigt), zoom (2 doigts).
/// Story 1.3 : placement de tuiles de test pour valider le rendu.
/// Story 1.5a : sélection d'emplacement, prévisualisation, rotation.
/// Story 1.5b : validation du placement (second tap), bouton annuler.
/// Story 1.7g — ajout tag bonus :
///              Pour éviter que le onTapUp systématique après un swipe ne
///              valide le placement, on enregistre la position du onTapDown
///              et on mesure la distance parcourue — si > 5 px, c'était un
///              swipe, pas un tap, donc on ignore.
///              Annulation via croix sur la pile HUD.
///
/// Gestes :
///  - [MultiTouchTapDetector.onTapDown/onTapUp] : tap immobile → sélection,
///    confirmation ou annulation (story 1.7d : la sélection est faite dans
///    onTapUp, pas onTapDown, pour qu'un premier tap ne valide pas).
///  - [ScaleGestureRecognizer] : pan 1 doigt + zoom pinch 2 doigts. Pendant
///    la prévisualisation, le swipe vertical pivote la tuile (story 1.7c).
///  - La distance de mouvement est mesurée entre [onTapDown] et [onTapUp]
///    pour filtrer les swipes (story 1.7d).
library;

import 'dart:ui' show Color;

import 'package:flame/events.dart';

import '../core/colors.dart';
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
import 'palm_sprite_component.dart';

class HexBoardGame extends FlameGame
    with MultiTouchTapDetector {
  HexBoardGame({required this._ref});

  final WidgetRef _ref;

  HexGridComponent? _grid;

  bool _cameraDirty = false;
  bool _previewDirty = true;

  /// Stocke la position du onTapDown par pointerId, pour mesurer la distance
  /// parcourue dans onTapUp : si le doigt a bougé > 5 px, c'était un swipe
  /// (rotation/pan) et on ignore l'événement.
  final Map<int, Offset> _tapDownPositions = {};

  @override
  Color backgroundColor() => kBackgroundColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Préchargement des sprites palmier (story 1.10a).
    await PalmSpriteCache.instance.preload();
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

    // Partie reprise : placer toutes les tuiles restaurées sur Flame.
    final gridState = _ref.read(gridProvider);
    for (final entry in gridState.placedTiles.entries) {
      grid.placeTile(entry.key, entry.value, animated: false);
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
    if (_previewDirty) {
      _syncPlacementPreview();
      _previewDirty = false;
    }
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
    // previewBonusTiles DOIT être défini AVANT previewHighlightedSides car ce
    // dernier déclenche _syncPreviewCoinComponents() qui lit previewBonusTiles.
    final reward = _ref.read(previewRewardProvider);
    grid.previewBonusTiles = reward.bonusTiles;
    grid.previewHighlightedSides = reward.connectedSides.toSet();

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
    _previewDirty = true;
  }

  /// Retire une tuile du rendu Flame (appelé depuis le bouton Annuler).
  void removeTileFromFlame(HexCoords coords) {
    _grid?.removeTile(coords);
    _previewDirty = true;
  }

  /// Vrai si le jeu est en pause — les gestes doivent être ignorés.
  bool get _isPaused => _ref.read(pauseProvider).isPaused;

  // ── Rotation par swipe vertical ──────────────────────────────────────────

  double _rotationAccumulator = 0;
  static const double _kRotationThreshold = 40; // pixels pour 1 cran de 60°

  void _handleRotation(double dy) {
    _rotationAccumulator += dy;
    while (_rotationAccumulator.abs() >= _kRotationThreshold) {
      final step = _rotationAccumulator > 0 ? 1 : -1; // haut = anti-horaire
      _ref.read(placementProvider.notifier).rotate(step);
      _rotationAccumulator -= step.sign * _kRotationThreshold;
    }
    _previewDirty = true;
  }

  // ── Tap (via MultiTouchTapDetector) ───────────────────────────────────────

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    // Enregistrer la position pour mesurer le déplacement dans onTapUp.
    _tapDownPositions[pointerId] = info.eventPosition.widget.toOffset();
  }

  @override
  void onTapCancel(int pointerId) {
    _tapDownPositions.remove(pointerId);
  }

  @override
  Future<void> onTapUp(int pointerId, TapUpInfo info) async {
    if (_isPaused) return;
    // Si le doigt a bougé de plus de 5 px, c'était un swipe (rotation/pan),
    // pas un tap — on ignore pour ne pas valider le placement par erreur.
    final startPos = _tapDownPositions.remove(pointerId);
    final endPos = info.eventPosition.widget.toOffset();
    if (startPos != null && (endPos - startPos).distance > 5.0) return;
    final grid = _grid;
    if (grid == null) return;

    final placement = _ref.read(placementProvider);
    final placementNotifier = _ref.read(placementProvider.notifier);
    final coords = grid.hexAt(info.eventPosition.widget.toOffset());

    if (!placement.hasSelection) {
      // Premier tap : sélectionner la cellule pour la prévisualisation.
      if (placementNotifier.availableCells.contains(coords)) {
        placementNotifier.selectCell(coords);
        _previewDirty = true;
      }
      return;
    }

    if (placement.selected == coords) {
      // Second tap sur la même cellule → validation du placement (story 1.5b)
      await confirmPlacement(_ref, onConfirm: placeTileOnFlame);
      _previewDirty = true;
      return;
    }

    if (!placementNotifier.availableCells.contains(coords)) {
      // Tap en dehors des emplacements disponibles → annuler la prévisualisation.
      placementNotifier.clearSelection();
      _previewDirty = true;
      return;
    }

    placementNotifier.selectCell(coords);
  }

  // ── Pan / Zoom / Rotation (via ScaleGestureRecognizer) ──────────────────

  double _scaleStart = 1.0;

  void _handleScaleStart(ScaleStartDetails details) {
    if (_isPaused) return;
    _scaleStart = _grid?.zoom ?? 1.0;
    _rotationAccumulator = 0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isPaused) return;
    final grid = _grid;
    if (grid == null) return;

    final delta = details.focalPointDelta;

    // Pendant la prévisualisation, le swipe vertical fait pivoter la tuile.
    // Le pan horizontal est désactivé pendant la prévisualisation (story 1.7e).
    final placement = _ref.read(placementProvider);
    if (placement.hasSelection && (details.scale - 1.0).abs() < 0.05) {
      _handleRotation(delta.dy);
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
  }
}
