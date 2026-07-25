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
/// Story B11 : mode sélection Deuxième chance — quand actif, un tap
///             intercepte le flux normal pour retirer la tuile posée sous
///             le doigt (voir [removePlacedTile]) au lieu de prévisualiser
///             ou valider un placement.
///
/// Gestes :
///  - [MultiTouchTapDetector.onTapDown/onTapUp] : tap immobile → sélection
///    (premier tap sur un emplacement disponible) ou confirmation (tap
///    suivant, n'importe où sur l'écran, une fois qu'une sélection existe).
///    La sélection est faite dans onTapUp, pas onTapDown, pour qu'un
///    premier tap ne valide pas (story 1.7d). Le tap ne permet plus
///    d'annuler la prévisualisation : seule la croix sur la pile HUD
///    (ui/tile_stack_hud.dart) le permet désormais.
///  - [ScaleGestureRecognizer] : pan 1 doigt + zoom pinch 2 doigts. Pendant
///    la prévisualisation, un geste à un doigt fait pivoter la tuile en
///    suivant l'angle du doigt autour de son centre — le joueur peut tourner
///    dans n'importe quelle direction, sur 360° (story 1.7c, puis geste
///    circulaire).
///  - La distance de mouvement est mesurée entre [onTapDown] et [onTapUp]
///    pour filtrer les swipes (story 1.7d).
library;

import 'dart:math' show atan2, pi;
import 'dart:ui' show Color, Offset;

import 'package:flame/events.dart';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/grid_state_provider.dart';
import '../providers/pause_provider.dart';
import '../providers/placement_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/second_chance_ops.dart';
import '../providers/second_chance_provider.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import 'hex_coords.dart';
import 'hex_grid_component.dart';
import 'hex_tile.dart';

class HexBoardGame extends FlameGame
    with MultiTouchTapDetector {
  HexBoardGame({required this._container, this.onCameraMove});

  /// Appelé à chaque déplacement de caméra avec le delta cumulé (dx, dy).
  final void Function(double dx, double dy)? onCameraMove;

  final ProviderContainer _container;

  /// Retourne la position (coordonnées jeu) vers laquelle les tuiles bonus
  /// doivent voler après placement. Null = animation stationnaire par défaut.
  Vector2? Function()? getBonusFlyTarget;

  /// Retourne la position (coordonnées jeu) de l'icône Combo+ dans l'encart
  /// des améliorations actives — point de départ de la particule dédiée
  /// déclenchée par [spawnComboBonusParticle]. Null = amélioration non
  /// sélectionnée dans le build en cours (pas d'animation possible).
  Vector2? Function()? getComboUpgradeOrigin;

  /// Appelé à chaque fois qu'une icône de tuile bonus arrive sur la pile
  /// HUD — permet au widget Flutter du HUD de faire "pop" le compteur en
  /// rythme avec l'échelonnement des icônes plutôt qu'un seul pop global.
  void Function()? onBonusImpact;

  /// Appelé à chaque fois qu'une pièce (côté connecté) termine son vol vers
  /// le compteur de pièces — c'est ce callback, et non la pose de la tuile,
  /// qui doit déclencher le bruitage `coin.mp3` correspondant pour rester
  /// synchronisé avec l'impact visuel (voir [HexGridComponent.showRewardIndicators]).
  void Function(int count)? onCoinImpact;

  double get zoom => _grid?.zoom ?? 1.0;

  HexGridComponent? _grid;

  /// Flag dirty pour la synchronisation de prévisualisation.
  /// Positionné par les abonnements Riverpod (voir [_setupPreviewListeners]),
  /// évite de relire les providers à chaque frame quand rien n'a changé.
  bool _previewDirty = true;

  /// Convertit une position écran (repère du [GameWidget], voir
  /// `game_screen.dart`) en coordonnées hexagonales. Délègue à
  /// [HexGridComponent.hexAt] — exposé publiquement ici pour que
  /// [GameScreen] puisse cibler une case pendant un glisser-déposer de
  /// tuile depuis la pile HUD, en dehors du flux de tap normal de ce
  /// [FlameGame]. Retourne une coordonnée arbitraire (0, 0) tant que la
  /// grille n'est pas encore chargée — ne devrait pas se produire en
  /// pratique puisque le drag ne peut démarrer qu'une fois la partie
  /// affichée.
  HexCoords hexAt(Offset screenPos) =>
      _grid?.hexAt(screenPos) ?? const HexCoords(0, 0);

  bool _cameraDirty = false;

  /// Stocke la position du onTapDown par pointerId, pour mesurer la distance
  /// parcourue dans onTapUp : si le doigt a bougé > 5 px, c'était un swipe
  /// (rotation/pan) et on ignore l'événement.
  final Map<int, Offset> _tapDownPositions = {};

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _grid = HexGridComponent(screenSize: size.clone())
      ..onTilePlaced = () { _container.read(audioServiceProvider).playTilePlaced(); };
    add(_grid!);
    _initBoard();
    _setupPreviewListeners();
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
    final gridState = _container.read(gridProvider);
    for (final entry in gridState.placedTiles.entries) {
      grid.placeTile(entry.key, entry.value, animated: false);
    }
  }

  /// Met en place des abonnements Riverpod pour positionner le flag
  /// [_previewDirty] quand l'état pertinent change. Évite de relire les
  /// providers à chaque frame dans [update()].
  void _setupPreviewListeners() {
    // Placement (sélection / rotation / clear).
    _container.listen(placementProvider, (prev, next) {
      _previewDirty = true;
    });
    // PreviewReward dépend de placementProvider + gridProvider + previewTile.
    _container.listen(previewRewardProvider, (prev, next) {
      _previewDirty = true;
    });
    // Grille (pose / annulation). Nécessaire en plus de [previewRewardProvider]
    // ci-dessus : quand aucun emplacement n'est sélectionné (cas de
    // [undoPlacement], qui retire une tuile sans jamais toucher à la
    // sélection), la valeur de [previewRewardProvider] ne change pas — son
    // écouteur ne se déclenche donc pas — alors que les cases disponibles
    // ([HexGridComponent.availableHighlights]) doivent quand même être
    // recalculées pour refléter la tuile retirée.
    _container.listen(gridProvider, (prev, next) {
      _previewDirty = true;
    });
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
    // Synchronisation pilotée par un flag dirty plutôt qu'à chaque frame.
    // Les abonnements Riverpod (voir [_setupPreviewListeners]) positionnent
    // [_previewDirty] quand placement/previewReward/grid changent.
    if (_previewDirty) {
      _previewDirty = false;
      _syncPlacementPreview();
    }
  }

  /// Lit l'état courant des providers de placement/pile et met à jour le
  /// rendu de [HexGridComponent] (highlights + preview) en conséquence.
  /// Appelé uniquement quand [_previewDirty] est true (abonnements Riverpod
  /// dans [_setupPreviewListeners]).
  void _syncPlacementPreview() {
    final grid = _grid;
    if (grid == null) return;

    final placement = _container.read(placementProvider);
    final placementNotifier = _container.read(placementProvider.notifier);

    grid.availableHighlights = placementNotifier.availableCells;
    grid.previewCoords = placement.selected;
    // DOIT être défini avant previewTile : previewTile s'appuie sur ce
    // compteur pour détecter une rotation (voir doc de
    // [HexGridComponent.previewRotationSteps]), notamment sur les tuiles à
    // un seul biome où la comparaison visuelle des côtés ne suffit pas.
    grid.previewRotationSteps = placement.rotationSteps;
    grid.previewTile = placementNotifier.previewTile;

    // Côtés bien connectés et tuiles bonus à montrer sur la prévisualisation.
    // previewBonusTiles DOIT être défini AVANT previewHighlightedSides car ce
    // dernier déclenche _syncPreviewCoinComponents() qui lit previewBonusTiles.
    final reward = _container.read(previewRewardProvider);
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
    int bonusTiles, {
    int bonusCoins = 0,
  }) {
    _grid?.placeTile(coords, tile,
        connectedSides: connectedSides);
    if (connectedSides.isNotEmpty || bonusTiles > 0) {
      _grid?.showRewardIndicators(coords, connectedSides,
          bonusTiles: bonusTiles,
          bonusFlyTarget: getBonusFlyTarget?.call(),
          onBonusImpact: onBonusImpact,
          onCoinImpact: onCoinImpact);
    }
  }

  /// Déclenche la particule dédiée de tuile bonus Combo+ : contrairement au
  /// bonus de connexion (géré dans [placeTileOnFlame]), la tuile bonus de
  /// Combo+ n'est liée à aucun côté de la tuile posée — sa particule part
  /// donc de l'icône de l'amélioration dans l'encart HUD ([getComboUpgradeOrigin])
  /// plutôt que de la tuile, avec la même animation d'envol vers la pile
  /// (voir [HexGridComponent.showBonusParticleFrom]).
  void spawnComboBonusParticle(int count) {
    final origin = getComboUpgradeOrigin?.call();
    if (origin == null) return;
    _grid?.showBonusParticleFrom(origin, count,
        flyTarget: getBonusFlyTarget?.call(), onImpact: onBonusImpact);
  }

  /// Retire une tuile du rendu Flame (appelé depuis le bouton Annuler).
  ///
  /// [flyTarget] : position (coordonnées jeu) de la pile de prévisualisation
  /// vers laquelle animer le retour de la tuile — voir [HexGridComponent.removeTile].
  void removeTileFromFlame(HexCoords coords, {Vector2? flyTarget}) {
    _grid?.removeTile(coords, flyTarget: flyTarget);
  }

  /// Vrai si le jeu est en pause — les gestes doivent être ignorés.
  bool get _isPaused => _container.read(pauseProvider).isPaused;

  // ── Rotation par geste circulaire autour de la tuile ─────────────────────
  //
  // Avant, la rotation ne suivait que le déplacement vertical (dy) du doigt,
  // avec une inversion de sens selon la moitié d'écran de départ — ce qui
  // ne permettait de tourner que sur un axe haut/bas, pas de "faire le
  // tour" complet de la tuile comme on tournerait une molette.
  //
  // Le nombre de crans est maintenant dérivé de l'angle du doigt autour du
  // centre écran de la tuile prévisualisée (voir
  // [HexGridComponent.previewScreenCenter]) : le joueur peut poser le doigt
  // n'importe où autour de la tuile et la faire tourner en suivant un arc de
  // cercle dans n'importe quelle direction, sur 360°.
  //
  // L'angle est accumulé de façon continue (delta d'angle non-signé remis
  // dans (-π, π] à chaque frame, puis sommé) plutôt que recalculé en absolu
  // depuis le départ du geste — contrairement au swipe vertical, un calcul
  // absolu ferait un saut de 2π quand le doigt traverse la démarcation
  // ±180° de atan2, ce qui est courant dès qu'on tourne sur plus d'un demi-
  // tour. L'accumulation par petits deltas reste fiable ici : contrairement
  // au cas du swipe vertical (voir ancien commentaire, conservé plus bas
  // pour mémoire), un saut de plus de 180° entre deux frames consécutives
  // d'un même geste tactile est extrêmement improbable en pratique.
  Vector2? _rotationAnchor;
  double? _rotationLastAngle;
  double _rotationAccumulatedAngle = 0;
  int _rotationNotchesApplied = 0;

  /// Distance minimale (px) entre le doigt et l'ancre pour que l'angle soit
  /// pris en compte — trop près du centre, l'angle devient instable (bruit
  /// de mesure amplifié par la faible distance).
  static const double _kMinRotationRadius = 16;

  /// Angle (radians) correspondant à un cran de rotation (60° = 1/6 de tour,
  /// une tuile hexagonale ayant 6 orientations).
  static const double _kRotationRadiansPerNotch = pi / 3;

  void _handleRotation(Offset focalPoint) {
    final anchor = _rotationAnchor;
    if (anchor == null) return;

    final dx = focalPoint.dx - anchor.x;
    final dy = focalPoint.dy - anchor.y;
    if (dx * dx + dy * dy < _kMinRotationRadius * _kMinRotationRadius) {
      return;
    }

    // atan2 en coordonnées écran (y vers le bas) : un déplacement du doigt
    // dans le sens horaire visuel produit un angle croissant, cohérent avec
    // rotate() dans placementProvider (positif = sens horaire).
    final angle = atan2(dy, dx);
    final lastAngle = _rotationLastAngle;
    if (lastAngle != null) {
      var delta = angle - lastAngle;
      if (delta > pi) delta -= 2 * pi;
      if (delta < -pi) delta += 2 * pi;
      _rotationAccumulatedAngle += delta;
    }
    _rotationLastAngle = angle;

    final targetNotches =
        (_rotationAccumulatedAngle / _kRotationRadiansPerNotch).truncate();
    final delta = targetNotches - _rotationNotchesApplied;
    if (delta != 0) {
      _container.read(placementProvider.notifier).rotate(delta);
      _rotationNotchesApplied = targetNotches;
      // Un clic haptique par mise à jour de rotation (un ou plusieurs crans
      // d'un coup lors d'un swipe rapide comptent pour un seul retour, afin
      // de ne pas spammer de vibrations en rafale).
      _container.read(hapticsServiceProvider).tileRotated();
    }
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

    // Mode sélection Deuxième chance (Story B11) : un tap sur une tuile
    // posée la retire et la réinjecte en pile, plutôt que de suivre le
    // flux normal de placement ci-dessous — les deux modes sont mutuellement
    // exclusifs (voir [toggleSecondChanceMode]).
    if (_container.read(secondChanceModeProvider)) {
      final coords = grid.hexAt(info.eventPosition.widget.toOffset());
      removePlacedTile(_container, coords, onRemove: removeTileFromFlame);
      return;
    }

    final placement = _container.read(placementProvider);
    final placementNotifier = _container.read(placementProvider.notifier);

    if (!placement.hasSelection) {
      // Premier tap : sélectionner la cellule pour la prévisualisation
      // (uniquement si le tap tombe sur un emplacement disponible).
      final coords = grid.hexAt(info.eventPosition.widget.toOffset());
      if (placementNotifier.availableCells.contains(coords)) {
        placementNotifier.selectCell(coords);
        _container.read(hapticsServiceProvider).tilePreviewed();
      }
      return;
    }

    // Une prévisualisation est en cours : n'importe quel tap sur l'écran
    // valide le placement (demande utilisateur — ce n'est plus limité à un
    // second tap sur la tuile prévisualisée). confirmPlacement() lit
    // placement.selected en interne, donc l'emplacement tapé n'a pas
    // d'importance ici.
    //
    // Le tap n'annule plus la prévisualisation : le seul moyen de
    // l'annuler est désormais la croix sur la pile HUD (clearSelection()
    // appelé depuis ui/tile_stack_hud.dart), qui positionne le flag dirty
    // via l'abonnement Riverpod (voir [_setupPreviewListeners]).
    await confirmPlacement(_container,
        onConfirm: placeTileOnFlame,
        onComboBonusTiles: spawnComboBonusParticle);
  }

  // ── Pan / Zoom / Rotation (via ScaleGestureRecognizer) ──────────────────

  double _scaleStart = 1.0;

  void _handleScaleStart(ScaleStartDetails details) {
    if (_isPaused) return;
    _scaleStart = _grid?.zoom ?? 1.0;
    // Ancre de la rotation circulaire : le centre écran de la tuile en
    // prévisualisation. Reste `null` (donc rotation ignorée) s'il n'y a pas
    // de sélection en cours.
    _rotationAnchor = _grid?.previewScreenCenter;
    _rotationLastAngle = null;
    _rotationAccumulatedAngle = 0;
    _rotationNotchesApplied = 0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isPaused) return;
    final grid = _grid;
    if (grid == null) return;

    final delta = details.focalPointDelta;

    // Pendant la prévisualisation, un geste à un doigt fait pivoter la
    // tuile en suivant l'angle du doigt autour de son centre (rotation
    // circulaire, voir _handleRotation). Le pan est désactivé pendant la
    // prévisualisation (story 1.7e).
    final placement = _container.read(placementProvider);
    if (placement.hasSelection && (details.scale - 1.0).abs() < 0.05) {
      _handleRotation(details.focalPoint);
    } else {
      grid.cameraOffset.add(Vector2(delta.dx, delta.dy));
      onCameraMove?.call(delta.dx, delta.dy);
    }

    grid.zoom = (_scaleStart * details.scale)
        .clamp(HexGridComponent.minZoom, HexGridComponent.maxZoom);

    // Empêche le pan (et un zoom arrière qui agrandirait la marge requise)
    // de faire sortir le centre du plateau de l'écran — sans ça, un pan
    // trop ample fait perdre le joueur.
    grid.clampCameraOffset();

    _cameraDirty = true;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isPaused) return;
    _scaleStart = _grid?.zoom ?? 1.0;
    _rotationAnchor = null;
    _rotationLastAngle = null;
    _rotationAccumulatedAngle = 0;
    _rotationNotchesApplied = 0;
  }
}
