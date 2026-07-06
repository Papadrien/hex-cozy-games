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
///    la prévisualisation, le swipe vertical pivote la tuile (story 1.7c).
///    Le sens de rotation est inversé si le geste démarre sur la moitié
///    gauche de l'écran par rapport à la moitié droite.
///  - La distance de mouvement est mesurée entre [onTapDown] et [onTapUp]
///    pour filtrer les swipes (story 1.7d).
library;

import 'dart:ui' show Color, Offset;

import 'package:flame/events.dart';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/grid_state_provider.dart';
import '../providers/pause_provider.dart';
import '../providers/placement_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/second_chance_provider.dart';
import '../services/haptics_service.dart';
import 'hex_coords.dart';
import 'hex_grid_component.dart';
import 'hex_tile.dart';

class HexBoardGame extends FlameGame
    with MultiTouchTapDetector {
  HexBoardGame({required this._ref, this.onCameraMove});

  /// Appelé à chaque déplacement de caméra avec le delta cumulé (dx, dy).
  final void Function(double dx, double dy)? onCameraMove;

  final WidgetRef _ref;

  double get zoom => _grid?.zoom ?? 1.0;

  HexGridComponent? _grid;

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
    // Resynchronisé à chaque frame plutôt que via un flag "dirty" posé
    // uniquement par les gestes internes au jeu (tap/swipe sur la grille) :
    // la croix d'annulation de la pile HUD (widget Flutter externe) modifie
    // aussi [placementProvider] via clearSelection(), sans passer par ces
    // gestes. Avec l'ancien flag, ce changement externe n'était jamais
    // détecté et le fantôme de prévisualisation restait affiché après un
    // clic sur la croix. Les setters de [HexGridComponent] ci-dessous font
    // déjà de la détection de changement (no-op si valeur identique), donc
    // cet appel systématique reste bon marché.
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
    // DOIT être défini avant previewTile : previewTile s'appuie sur ce
    // compteur pour détecter une rotation (voir doc de
    // [HexGridComponent.previewRotationSteps]), notamment sur les tuiles à
    // un seul biome où la comparaison visuelle des côtés ne suffit pas.
    grid.previewRotationSteps = placement.rotationSteps;
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
  }

  /// Retire une tuile du rendu Flame (appelé depuis le bouton Annuler).
  ///
  /// [flyTarget] : position (coordonnées jeu) de la pile de prévisualisation
  /// vers laquelle animer le retour de la tuile — voir [HexGridComponent.removeTile].
  void removeTileFromFlame(HexCoords coords, {Vector2? flyTarget}) {
    _grid?.removeTile(coords, flyTarget: flyTarget);
  }

  /// Vrai si le jeu est en pause — les gestes doivent être ignorés.
  bool get _isPaused => _ref.read(pauseProvider).isPaused;

  // ── Rotation par swipe vertical ──────────────────────────────────────────
  //
  // Le nombre de crans est recalculé à chaque frame à partir du déplacement
  // ABSOLU depuis le début du geste (focalPoint courant - focalPoint de
  // départ), et non plus par accumulation de deltas incrémentaux
  // (onUpdate.focalPointDelta, frame par frame).
  //
  // Avant, un accumulateur mutable (_rotationAccumulator) sommait les
  // deltas au fil des appels à onUpdate. Problème : ces deltas incrémentaux
  // peuvent être fusionnés ou partiellement perdus par le pipeline
  // tactile — en particulier lors du tout premier geste suivant un retour
  // d'arrière-plan, où la reprise du pipeline d'événements peut livrer un
  // batch d'updates différent de la normale. Le résultat observé : un
  // swipe qui aurait dû produire plusieurs crans n'en appliquait qu'un
  // seul, et l'accumulateur pouvait rester dans un état incohérent d'un
  // geste à l'autre (ce qui donnait aussi une impression de sens de
  // rotation aléatoire).
  //
  // En repartant à chaque frame de la position ABSOLUE (start vs courant),
  // le nombre de crans "cible" est toujours recalculé intégralement : il ne
  // peut jamais dériver ni dépendre de deltas manqués, et le sens ne dépend
  // que du signe du déplacement total (haut = anti-horaire, bas = horaire),
  // sauf inversion côté gauche de l'écran — voir [_rotationInverted]
  // ci-dessous.
  Offset? _rotationStartFocalPoint;
  int _rotationNotchesApplied = 0;
  static const double _kRotationThreshold = 40; // pixels pour 1 cran de 60°

  /// Vrai si le geste de rotation en cours a démarré sur la moitié gauche de
  /// l'écran — dans ce cas le sens de rotation est inversé par rapport à la
  /// moitié droite (demande utilisateur : la moitié droite reste la
  /// référence, la gauche fait "miroir"). Figé au [_handleScaleStart] du
  /// geste, ne change pas si le doigt traverse le milieu de l'écran en
  /// cours de geste.
  bool _rotationInverted = false;

  void _handleRotation(Offset focalPoint) {
    final start = _rotationStartFocalPoint;
    if (start == null) return;
    var totalDy = focalPoint.dy - start.dy;
    // haut (dy négatif) = anti-horaire, bas (dy positif) = horaire — cohérent
    // avec rotate() dans placementProvider (positif = sens horaire). Côté
    // gauche de l'écran : sens inversé par rapport au côté droit.
    if (_rotationInverted) totalDy = -totalDy;
    final targetNotches = (totalDy / _kRotationThreshold).truncate();
    final delta = targetNotches - _rotationNotchesApplied;
    if (delta != 0) {
      _ref.read(placementProvider.notifier).rotate(delta);
      _rotationNotchesApplied = targetNotches;
      // Un clic haptique par mise à jour de rotation (un ou plusieurs crans
      // d'un coup lors d'un swipe rapide comptent pour un seul retour, afin
      // de ne pas spammer de vibrations en rafale).
      _ref.read(hapticsServiceProvider).tileRotated();
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
    if (_ref.read(secondChanceModeProvider)) {
      final coords = grid.hexAt(info.eventPosition.widget.toOffset());
      removePlacedTile(_ref, coords, onRemove: removeTileFromFlame);
      return;
    }

    final placement = _ref.read(placementProvider);
    final placementNotifier = _ref.read(placementProvider.notifier);

    if (!placement.hasSelection) {
      // Premier tap : sélectionner la cellule pour la prévisualisation
      // (uniquement si le tap tombe sur un emplacement disponible).
      final coords = grid.hexAt(info.eventPosition.widget.toOffset());
      if (placementNotifier.availableCells.contains(coords)) {
        placementNotifier.selectCell(coords);
        _ref.read(hapticsServiceProvider).tilePreviewed();
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
    // appelé depuis ui/tile_stack_hud.dart), qui déclenche sa propre
    // resynchronisation via _syncPlacementPreview() dans update().
    await confirmPlacement(_ref, onConfirm: placeTileOnFlame);
  }

  // ── Pan / Zoom / Rotation (via ScaleGestureRecognizer) ──────────────────

  double _scaleStart = 1.0;

  void _handleScaleStart(ScaleStartDetails details) {
    if (_isPaused) return;
    _scaleStart = _grid?.zoom ?? 1.0;
    _rotationStartFocalPoint = details.focalPoint;
    _rotationNotchesApplied = 0;
    // Moitié gauche de l'écran → rotation inversée (voir [_rotationInverted]).
    _rotationInverted = details.focalPoint.dx < size.x / 2;
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
      _handleRotation(details.focalPoint);
    } else {
      grid.cameraOffset.add(Vector2(delta.dx, delta.dy));
      onCameraMove?.call(delta.dx, delta.dy);
    }

    grid.zoom = (_scaleStart * details.scale)
        .clamp(HexGridComponent.minZoom, HexGridComponent.maxZoom);

    _cameraDirty = true;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isPaused) return;
    _scaleStart = _grid?.zoom ?? 1.0;
    _rotationStartFocalPoint = null;
    _rotationNotchesApplied = 0;
    _rotationInverted = false;
  }
}
