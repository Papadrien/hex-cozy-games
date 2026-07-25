/// Composant Flame gérant l'affichage de la grille hexagonale.
///
/// Story 1.2 : grille invisible, hexagones pointy-top, coordonnées axiales,
///             pan/zoom, hit-testing.
/// Story 1.3 : les cellules posées sont rendues via [TileComponent].
/// Story 1.5a : surbrillance des emplacements disponibles + prévisualisation
///              translucide/surélevée de la tuile active. Seul indicateur de
///              grille visible — aucun contour n'est dessiné par ailleurs.
///
/// Projection isométrique : chaque [TileComponent] applique lui-même le
/// facteur kIsoScaleY sur ses coins. La position (x, y) du composant est en
/// coordonnées écran "plates" — on ne multiplie PAS y ici. Les highlights
/// dessinés directement dans [render] appliquent kIsoScaleY manuellement
/// pour rester cohérents avec les tuiles.
library;

import 'dart:math';
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show VoidCallback;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../core/constants.dart';
import 'bonus_animations.dart';
import 'hex_coords.dart';
import 'hex_cell.dart';
import 'hex_tile.dart';
import 'tile_component.dart'; // kIsoScaleY, TileComponent

/// Décalage vertical (en pixels écran "plat", avant projection iso) de la
/// tuile en prévisualisation pour la faire paraître "légèrement surélevée"
/// au-dessus du plateau (story 1.5a).
const double kPreviewLiftPx = 10.0;

/// Opacité de la tuile en prévisualisation.
const double kPreviewAlpha = 1.0;

/// Distance (en pixels écran) dont chaque icône de pièce de prévisualisation
/// est à la fois poussée vers l'extérieur (à l'opposé du centre de la tuile
/// en cours de pose) et surélevée (effet 3D), pour qu'elle se détache
/// visuellement de la tuile plutôt que de sembler posée dessus.
const double kPreviewCoinOffsetPx = 20.0;

/// Surélévation supplémentaire (en pixels écran), en plus de [kPreviewLiftPx],
/// de l'icône de tuile bonus centrée sur la prévisualisation — pour qu'elle
/// se détache mieux au-dessus de la tuile plutôt que de sembler posée dessus.
const double kPreviewBonusExtraLiftPx = 5.0;

/// Nombre maximum d'icônes de tuile bonus envoyées individuellement (effet
/// "machine à sous" échelonné) sur une même pose. Au-delà, le surplus est
/// regroupé dans la dernière icône affichée pour éviter de surcharger
/// l'écran de tuiles très rentables (grosses chaînes d'améliorations).
const int kMaxStaggeredBonusIcons = 4;

// ── Animation de pose (descente + léger rebond "flottant") ─────────────────

/// Hauteur de départ de la descente : la tuile posée part de la même
/// élévation que la prévisualisation, pour un enchaînement visuel continu.
const double kDropStartLiftPx = kPreviewLiftPx;

/// Profondeur du dépassement sous l'emplacement final, avant le rebond de
/// remontée (effet "posée dans l'eau, qui flotte légèrement en remontant").
const double kDropBounceOvershootPx = 1.0 / 3;

/// Durée de la phase de descente.
const double kDropDescendDurationSec = 0.10;

/// Durée de la phase de rebond (remontée jusqu'à la position finale).
const double kDropBounceDurationSec = 0.08;

/// Durée de la montée en puissance de l'ondulation du bord bas une fois la
/// tuile arrivée à son emplacement final.
const double kDropWaveRampInDurationSec = 0.45;

// ── Animation d'annulation (retour vers la pile) ────────────────────────────

/// Durée du vol de retour de la tuile annulée vers la pile de prévisualisation.
const double kUndoFlyDurationSec = 0.32;

/// Échelle finale (quasi nulle) atteinte par la tuile juste avant sa
/// disparition dans la pile.
const double kUndoFlyEndScale = 0.12;

class HexGridComponent extends PositionComponent {
  HexGridComponent({required this.screenSize})
      : super(position: Vector2.zero(), priority: 0);

  Vector2 screenSize;

  /// Position du compteur de pièces en haut à gauche (coordonnées jeu) —
  /// cible de vol partagée par [showRewardIndicators] (pièces de connexion)
  /// et [showCoinParticleFrom] (pièces bonus des améliorations Pièces+/
  /// Rouge+/Vert+/Bleu+/Jaune+/Violet+).
  static final Vector2 _coinCounterTarget = Vector2(26, 85);

  /// Appelé lorsqu'une tuile posée en animé atteint sa position finale (fin
  /// du rebond). Permet au [FlameGame] parent de déclencher un bruitage
  /// (voir `AudioService.playTilePlaced`) sans coupler ce composant à
  /// Riverpod.
  VoidCallback? onTilePlaced;

  // ── État ──────────────────────────────────────────────────────────────────

  final Map<HexCoords, HexCell> placedCells = {};
  final Map<HexCoords, TileComponent> placedTiles = {};

  // ── Prévisualisation de placement (story 1.5a) ──────────────────────────

  /// Emplacements actuellement disponibles (surbrillance). Réassigner
  /// déclenche un recalcul du rendu au prochain frame, pas de besoin de
  /// `setState`-like ici : [render] lit directement ce champ.
  Set<HexCoords> availableHighlights = const {};

  HexCoords? _previewCoords;
  HexTile? _previewTile;
  TileComponent? _previewComponent;

  /// Dernier couple (coords, tuile) synchronisé, utilisé pour distinguer une
  /// simple rotation de la tuile prévisualisée (même emplacement) d'une
  /// nouvelle sélection (déclenche l'animation de rotation plutôt qu'un
  /// remplacement instantané — voir [_syncPreviewComponent]).
  HexCoords? _lastSyncedPreviewCoords;
  HexTile? _lastSyncedPreviewTile;

  /// Dernier nombre de crans de rotation (0-5) synchronisé pour la tuile en
  /// prévisualisation. Sert à détecter une rotation même quand la tuile a un
  /// seul biome (dans ce cas [_detectRotationSteps] ne peut rien détecter en
  /// comparant les côtés, puisqu'ils sont tous identiques après rotation).
  int? _lastSyncedPreviewRotationSteps;

  Set<int> _previewHighlightedSides = const {};
  final List<PositionComponent> _previewCoinComponents = [];

  /// Surbrillance des voisins pendant la prévisualisation.
  Map<HexCoords, Set<int>> _previewNeighborHighlights = const {};

  /// Côtés de la tuile prévisualisée qui seraient connectés (story 1.7a).
  /// Met à jour la surbrillance sur le composant de prévisualisation existant
  /// ou servira lors de la création d'un nouveau.
  Set<int> get previewHighlightedSides => _previewHighlightedSides;
  set previewHighlightedSides(Set<int> value) {
    if (_previewHighlightedSides == value) return;
    _previewHighlightedSides = value;
    if (_previewComponent != null) {
      _previewComponent!.highlightedSides = value;
    }
    _syncPreviewCoinComponents();
  }

  /// Nombre de tuiles bonus.
  int previewBonusTiles = 0;

  /// Surbrillance des côtés des tuiles voisines qui seront connectées.
  set previewNeighborHighlights(Map<HexCoords, Set<int>> value) {
    for (final entry in _previewNeighborHighlights.entries) {
      final tile = placedTiles[entry.key];
      if (tile != null) {
        tile.highlightedSides = const {};
      }
    }
    _previewNeighborHighlights = value;
    for (final entry in value.entries) {
      final tile = placedTiles[entry.key];
      if (tile != null) {
        tile.highlightedSides = entry.value;
      }
    }
  }

  /// Coordonnées de la prévisualisation en cours, ou null si aucune
  /// sélection. Mettre à jour ce champ recrée/déplace le composant de
  /// prévisualisation si nécessaire.
  HexCoords? get previewCoords => _previewCoords;
  set previewCoords(HexCoords? value) {
    if (_previewCoords == value) return;
    _previewCoords = value;
    _syncPreviewComponent();
  }

  /// Nombre de crans de rotation (0-5) actuellement appliqués à la tuile en
  /// prévisualisation. Doit être défini AVANT [previewTile] à chaque
  /// synchronisation : c'est ce compteur (et non une comparaison visuelle des
  /// côtés) qui permet de détecter une rotation, y compris sur une tuile à un
  /// seul biome où tous les côtés sont identiques quel que soit l'angle.
  int? _previewRotationSteps;
  set previewRotationSteps(int? value) {
    _previewRotationSteps = value;
  }

  /// Tuile (déjà tournée) affichée en prévisualisation, ou null.
  HexTile? get previewTile => _previewTile;
  set previewTile(HexTile? value) {
    if (_previewTile == value) return;
    _previewTile = value;
    _syncPreviewComponent();
  }

  /// Crée, met à jour ou retire le [TileComponent] de prévisualisation selon
  /// l'état courant de [_previewCoords] / [_previewTile]. Rendu translucide
  /// et légèrement surélevé (décalage vertical négatif en écran "plat", donc
  /// vers le haut de l'écran une fois la projection iso appliquée) pour le
  /// distinguer clairement d'une tuile réellement posée.
  void _syncPreviewComponent() {
    final coords = _previewCoords;
    final tile = _previewTile;

    if (coords == null || tile == null) {
      final existing = _previewComponent;
      if (existing != null) {
        remove(existing);
        _previewComponent = null;
      }
      for (final c in _previewCoinComponents) {
        remove(c);
      }
      _previewCoinComponents.clear();
      _lastSyncedPreviewCoords = null;
      _lastSyncedPreviewTile = null;
      _lastSyncedPreviewRotationSteps = null;
      return;
    }

    final center = _layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    final liftedPosition = Vector2(
      center.x,
      center.y - kPreviewLiftPx,
    );

    final existing = _previewComponent;
    if (existing != null) {
      // Si l'emplacement n'a pas changé mais que la tuile a changé, il ne
      // peut s'agir que d'une rotation (voir doc de [PlacementState]) : on
      // anime la rotation plutôt que de basculer instantanément l'affichage.
      final previousTile = _lastSyncedPreviewTile;
      final previousSteps = _lastSyncedPreviewRotationSteps;
      final sameCell = _lastSyncedPreviewCoords == coords;
      existing.tile = tile;
      existing.hexSize = kHexSize * zoom;
      existing.position = liftedPosition;
      existing.highlightedSides = _previewHighlightedSides;
      if (sameCell && previousTile != null) {
        final steps = _detectRotationSteps(previousTile, tile) ??
            _rotationDeltaFromCounters(previousSteps, _previewRotationSteps);
        if (steps != null) {
          existing.animateRotationSwirl(steps);
        }
      }
      _lastSyncedPreviewCoords = coords;
      _lastSyncedPreviewTile = tile;
      _lastSyncedPreviewRotationSteps = _previewRotationSteps;
      _syncPreviewCoinComponents();
      return;
    }

    final component = TileComponent(
      tile: tile,
      coords: coords,
      hexSize: kHexSize * zoom,
      alpha: kPreviewAlpha,
      highlightedSides: _previewHighlightedSides,
      position: liftedPosition,
      // Pas d'ondulation pendant la prévisualisation (elle n'apparaît qu'une
      // fois la tuile réellement posée, voir [placeTile]).
      initialWaveIntensity: 0.0,
    );
    component.priority = kTileDepthPriorityPreview;
    _previewComponent = component;
    add(component);

    _lastSyncedPreviewCoords = coords;
    _lastSyncedPreviewTile = tile;
    _lastSyncedPreviewRotationSteps = _previewRotationSteps;

    _syncPreviewCoinComponents();
  }

  /// Gère les icônes de pièces au niveau de chaque côté bien connecté pendant
  /// la prévisualisation, ainsi que l'icône de tuile bonus centrée sur la
  /// prévisualisation si une ou plusieurs tuiles bonus sont gagnées (story 1.7e).
  void _syncPreviewCoinComponents() {
    for (final c in _previewCoinComponents) {
      remove(c);
    }
    _previewCoinComponents.clear();

    if (_previewCoords == null) return;

    final layout = _layout;
    final center = layout.hexToPixel(_previewCoords!, isoScaleY: kIsoScaleY);
    final hexSize = kHexSize * zoom;

    // Pièces au niveau de chaque côté connecté. On les décale légèrement
    // vers l'extérieur (à l'opposé du centre de la tuile en cours de pose)
    // et on les surélève de la même distance pour un effet de profondeur
    // 3D — l'icône se détache ainsi mieux de la tuile qui va être posée
    // au lieu de sembler collée dessus. Opacité pleine (pas de
    // [staticAlpha] réduit) pour rester bien visible pendant la prévisualisation.
    for (final side in _previewHighlightedSides) {
      final offset = _sideEdgeMidpoint(side, hexSize);
      final direction = offset.normalized();
      final pos = Vector2(
        center.x + offset.x + direction.x * kPreviewCoinOffsetPx,
        center.y + offset.y + direction.y * kPreviewCoinOffsetPx -
            kPreviewCoinOffsetPx,
      );
      final component = CoinComponent(
        position: pos,
        hexSize: hexSize,
        animated: false,
        staticAlpha: 1.0,
      );
      component.priority = kTileDepthPriorityPreview + 1;
      _previewCoinComponents.add(component);
      add(component);
    }

    // Tuile bonus centrée sur la prévisualisation (story 1.7e) — même
    // surélévation ([kPreviewLiftPx]) que le [TileComponent] de
    // prévisualisation (voir [_syncPreviewComponent]) pour être bien
    // centrée dessus plutôt qu'à mi-hauteur entre le sol et la tuile, plus
    // [kPreviewBonusExtraLiftPx] pour se détacher visuellement au-dessus de
    // la tuile plutôt que de sembler posée dessus.
    if (previewBonusTiles > 0) {
      final pos = Vector2(
        center.x,
        center.y - kPreviewLiftPx - kPreviewBonusExtraLiftPx,
      );
      final component = PreviewBonusComponent(
        position: pos,
        hexSize: hexSize,
        bonusCount: previewBonusTiles,
      );
      component.priority = kTileDepthPriorityPreview + 1;
      _previewCoinComponents.add(component);
      add(component);
    }
  }

  // ── Caméra ────────────────────────────────────────────────────────────────

  Vector2 cameraOffset = Vector2.zero();
  double zoom = 1.0;
  static const double minZoom = 0.4;
  static const double maxZoom = 2.0;

  /// Marge (en pixels écran) conservée entre le centre du plateau (0,0) et
  /// le bord de l'écran une fois clampé — évite que la tuile centrale ne
  /// se retrouve collée pile au bord, à moitié masquée par le HUD.
  static const double _centerTileScreenMargin = 32.0;

  /// Ancre écran (fraction de la largeur/hauteur) de l'origine du plateau
  /// (0, 0) — utilisée à la fois par [_layout] et [clampCameraOffset], qui
  /// doivent rester synchronisés. Plateau centré à l'écran (0.5/0.5) : au
  /// lancement d'une partie (`cameraOffset` à zéro), la première tuile
  /// posée apparaît donc pile au centre de l'écran plutôt que décalée.
  static const double _originAnchorX = 0.5;
  static const double _originAnchorY = 0.5;

  /// Empêche le plateau posé (l'ensemble des tuiles jouées, pas seulement
  /// la toute première tuile en (0, 0)) de sortir de l'écran pendant le
  /// pan — sans ça, un pan trop ample fait perdre le joueur, qui ne sait
  /// plus dans quelle direction revenir vers ses tuiles posées. Avant, seul
  /// le centre (0, 0) était contraint à rester visible : la marge de
  /// sécurité était donc correcte tant qu'on restait près de la première
  /// tuile, mais devenait insuffisante dès qu'on posait loin d'elle (le
  /// bord du plateau pouvait sortir de l'écran alors que (0, 0), lui,
  /// restait dans la marge).
  ///
  /// On calcule ici la bounding box (en pixels, indépendante de la caméra)
  /// des tuiles réellement posées, puis on clampe [cameraOffset] pour que
  /// cette bounding box — et non plus seulement (0, 0) — reste comprise
  /// entre la marge et `screenSize - marge` sur chaque axe. Avec une seule
  /// tuile (ou aucune), la bounding box est réduite à (0, 0) et le calcul
  /// redevient identique à l'ancien comportement.
  void clampCameraOffset() {
    final margin = _centerTileScreenMargin * zoom;
    final worldLayout = HexLayout(hexSize: kHexSize * zoom, origin: const Point(0, 0));

    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    for (final coords in placedTiles.keys) {
      final p = worldLayout.hexToPixel(coords, isoScaleY: kIsoScaleY);
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final minOffsetX = margin - screenSize.x * _originAnchorX - maxX;
    final maxOffsetX = screenSize.x * (1 - _originAnchorX) - margin - minX;
    final minOffsetY = margin - screenSize.y * _originAnchorY - maxY;
    final maxOffsetY = screenSize.y * (1 - _originAnchorY) - margin - minY;

    // Écran trop petit pour la marge demandée (ex: tests, fenêtre réduite) :
    // `clamp` plante si min > max, donc on retombe sur un unique point fixe
    // plutôt que de crasher.
    cameraOffset.x = minOffsetX <= maxOffsetX
        ? cameraOffset.x.clamp(minOffsetX, maxOffsetX)
        : (minOffsetX + maxOffsetX) / 2;
    cameraOffset.y = minOffsetY <= maxOffsetY
        ? cameraOffset.y.clamp(minOffsetY, maxOffsetY)
        : (minOffsetY + maxOffsetY) / 2;
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  /// Origine de la grille en coordonnées écran (avant iso). Ancrée au
  /// centre de l'écran ([_originAnchorX]/[_originAnchorY]).
  HexLayout get _layout => HexLayout(
        hexSize: kHexSize * zoom,
        origin: Point(
          cameraOffset.x + screenSize.x * _originAnchorX,
          cameraOffset.y + screenSize.y * _originAnchorY,
        ),
      );

  /// Centre écran (coordonnées jeu, confondues avec les pixels écran — pas
  /// de caméra Flame séparée ici) de la tuile actuellement en
  /// prévisualisation, ou `null` si aucune sélection. Utilisé comme ancre
  /// pour la rotation circulaire au doigt (voir [HexBoardGame._handleRotation]).
  Vector2? get previewScreenCenter {
    final coords = _previewCoords;
    if (coords == null) return null;
    final center = _layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    return Vector2(center.x, center.y);
  }

  // ── API publique ───────────────────────────────────────────────────────────

  /// Place une [HexTile] sur [coords].
  ///
  /// [connectedSides] : si fourni, les côtés correspondants s'illuminent
  /// brièvement (glow — story 1.6b).
  void placeTile(HexCoords coords, HexTile tile,
      {List<int>? connectedSides, Set<int>? highlightedSides, bool animated = true}) {
    final existing = placedTiles.remove(coords);
    if (existing != null) remove(existing);

    final center = _layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    final finalPosition = Vector2(center.x, center.y);

    // Au-delà d'un certain nombre de tuiles posées, l'ondulation du bord bas
    // est désactivée (perf) — voir [kEdgeWaveTileCountThreshold].
    final waveEnabled =
        placedTiles.length + 1 <= kEdgeWaveTileCountThreshold;

    final component = TileComponent(
      tile: tile,
      coords: coords,
      hexSize: kHexSize * zoom,
      position: animated
          ? Vector2(center.x, center.y - kDropStartLiftPx)
          : finalPosition,
      highlightedSides: const {},
      // En pose animée, l'ondulation n'apparaît qu'une fois la tuile arrivée
      // (voir plus bas) ; sans animation (restauration de partie), elle est
      // visible immédiatement — sauf si le palier de tuiles est dépassé.
      initialWaveIntensity: (animated || !waveEnabled) ? 0.0 : 1.0,
    );
    // Calculée sur la position finale (et non la position de départ
    // surélevée) pour que l'empilement visuel reste correct pendant toute
    // l'animation de descente.
    component.priority = kTileDepthPriorityBase + finalPosition.y.round();

    if (connectedSides != null && connectedSides.isNotEmpty) {
      component.startGlow(connectedSides);
    }

    placedTiles[coords] = component;
    add(component);

    if (animated) {
      // Descente vers l'emplacement final, puis léger rebond (dépassement
      // sous la cible et remontée) pour un effet "posée dans l'eau qui
      // flotte". L'ondulation du bord bas démarre sa montée en puissance une
      // fois la tuile arrivée à son emplacement définitif.
      final overshootPosition =
          Vector2(center.x, center.y + kDropBounceOvershootPx);
      final descend = MoveEffect.to(
        overshootPosition,
        EffectController(duration: kDropDescendDurationSec, curve: Curves.easeIn),
      );
      final bounceBack = MoveEffect.to(
        finalPosition,
        EffectController(duration: kDropBounceDurationSec, curve: Curves.easeOut),
      )..onComplete = () {
          if (waveEnabled) {
            component.startWaveRampIn(duration: kDropWaveRampInDurationSec);
          }
          // Tuile arrivée à sa position finale — joué sans attendre la fin
          // du bruitage de descente (voir AudioService.playTilePlaced).
          onTilePlaced?.call();
        };
      component.add(SequenceEffect([descend, bounceBack]));
    }

    // Le palier vient d'être franchi avec cette pose : on fige aussi
    // l'ondulation des tuiles déjà posées pour maximiser le gain de perf.
    if (!waveEnabled) {
      for (final t in placedTiles.values) {
        t.freezeWave();
      }
    }

    placedCells[coords] = HexCell(
      q: coords.q,
      r: coords.r,
      biome: _dominantBiome(tile),
    );

    // Nettoyer les surbrillances de prévisualisation.
    for (final entry in _previewNeighborHighlights.entries) {
      final tile = placedTiles[entry.key];
      if (tile != null) {
        tile.highlightedSides = const {};
      }
    }
    _previewNeighborHighlights = const {};
  }

  /// Retire la tuile en [coords].
  ///
  /// Si [flyTarget] est fourni (position écran/jeu de la pile de
  /// prévisualisation d'où la tuile est sortie), la tuile s'envole vers ce
  /// point en rétrécissant et en s'estompant avant de disparaître —
  /// utilisé par le bouton Annuler pour montrer visuellement que la tuile
  /// "retourne" dans la pile. Sans [flyTarget], la tuile est retirée
  /// instantanément (comportement historique).
  void removeTile(HexCoords coords, {Vector2? flyTarget}) {
    final existing = placedTiles.remove(coords);
    placedCells.remove(coords);
    if (existing == null) return;

    if (flyTarget == null) {
      remove(existing);
      return;
    }

    // Passe au-dessus de toutes les autres tuiles pendant son vol de retour.
    existing.priority = kTileDepthPriorityPreview + 10;
    existing.startFadeOut(duration: kUndoFlyDurationSec);
    existing.add(
      MoveEffect.to(
        flyTarget,
        EffectController(duration: kUndoFlyDurationSec, curve: Curves.easeInCubic),
      )..onComplete = () => remove(existing),
    );
    existing.add(
      ScaleEffect.to(
        Vector2.all(kUndoFlyEndScale),
        EffectController(duration: kUndoFlyDurationSec, curve: Curves.easeIn),
      ),
    );
  }

  /// Affiche des pièces (pièces de monnaie) au niveau de chaque côté connecté
  /// sur la tuile placée en [coords], les tuiles bonus au-dessus de la cellule,
  /// et des particules pour les connexions parfaites.
  /// Les indicateurs disparaissent automatiquement après animation.
  void showRewardIndicators(HexCoords coords, List<int> connectedSides,
      {int bonusTiles = 0,
      Vector2? bonusFlyTarget,
      VoidCallback? onBonusImpact,
      void Function(int count)? onCoinImpact}) {
    final layout = _layout;
    final center = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    final centerVec = Vector2(center.x, center.y);
    final hexSize = kHexSize * zoom;

    // Pièces volant vers le compteur depuis chaque côté connecté. Toutes
    // les pièces d'un même placement s'envolent en même temps (même durée
    // de vol) et atterrissent donc quasi simultanément — un `onImpact` par
    // pièce déclencherait alors plusieurs lectures de `coin.mp3` sur la
    // même frame, ce qui ne laisse pas le temps au léger décalage de
    // [AudioService.playCoinsGained] de s'exprimer (on n'entendrait qu'un
    // seul bruitage). On ne déclenche donc [onCoinImpact] qu'une fois, à
    // l'arrivée de la première pièce, avec le nombre total de pièces
    // gagnées : c'est [playCoinsGained] qui se charge ensuite d'échelonner
    // lui-même les N lectures.
    for (var i = 0; i < connectedSides.length; i++) {
      final side = connectedSides[i];
      final offset = _sideEdgeMidpoint(side, hexSize);
      final pos = Vector2(
        centerVec.x + offset.x,
        centerVec.y + offset.y,
      );
      add(CoinComponent(
        position: pos,
        hexSize: hexSize,
        animated: true,
        flyTarget: _coinCounterTarget,
        onImpact: i == 0
            ? () => onCoinImpact?.call(connectedSides.length)
            : null,
        priority: kTileDepthPriorityPreview + 1,
      ));
    }

    // Icône(s) de tuile bonus qui volent vers la pile HUD. Au-delà d'une
    // seule tuile bonus, on envoie plusieurs icônes individuelles avec un
    // léger décalage temporel (effet "machine à sous") plutôt qu'un seul
    // "+N" — chaque arrivée fait "pop" le compteur HUD via [onBonusImpact].
    // Au-delà de [kMaxStaggeredBonusIcons], le surplus est regroupé dans
    // une dernière icône "+N" pour ne pas surcharger l'écran.
    if (bonusTiles > 0) {
      final individualCount = min(bonusTiles, kMaxStaggeredBonusIcons);
      for (var i = 0; i < individualCount; i++) {
        final isLast = i == individualCount - 1;
        final remainder = bonusTiles - kMaxStaggeredBonusIcons;
        final count = (isLast && remainder > 0) ? 1 + remainder : 1;
        add(BonusTileAnimComponent(
          position: centerVec.clone(),
          hexSize: hexSize,
          bonusCount: count,
          flyTarget: bonusFlyTarget,
          startDelay: i * kBonusIconStaggerInterval,
          onImpact: onBonusImpact,
          totalBonusTiles: bonusTiles,
          // Nombre de pièces (`coin.mp3`) attendues sur cette pose — étend
          // dynamiquement la phase de soulèvement pour que l'éclaboussure
          // et l'envol n'enchaînent qu'une fois le dernier son de pièce
          // terminé (voir [BonusTileAnimComponent._liftDurationSec]).
          coinCount: connectedSides.length,
        ));
      }
    }
  }

  /// Fait s'envoler une icône de tuile bonus depuis [origin] (coordonnées
  /// jeu, hors plateau) vers [flyTarget] — même animation
  /// ([BonusTileAnimComponent]) que celle jouée depuis la tuile posée dans
  /// [showRewardIndicators]. Utilisée par Combo+ (voir
  /// [HexBoardGame.spawnComboBonusParticle]) : contrairement au bonus de
  /// connexion, sa tuile bonus n'est pas liée à un côté de la tuile posée,
  /// donc sa particule part de l'icône de l'amélioration dans l'encart HUD
  /// plutôt que de la tuile.
  ///
  /// [coinCount] : nombre de `coin.mp3` attendus sur cette même pose
  /// (pièces de connexion + pièces bonus) — comme pour la tuile bonus de
  /// connexion dans [showRewardIndicators], la phase de soulèvement est
  /// étendue dynamiquement pour que l'envol ne démarre qu'une fois le
  /// dernier son de pièce terminé (voir [BonusTileAnimComponent.coinCount]).
  void showBonusParticleFrom(Vector2 origin, int count,
      {Vector2? flyTarget, VoidCallback? onImpact, int coinCount = 0}) {
    final hexSize = kHexSize * zoom;
    add(BonusTileAnimComponent(
      position: origin.clone(),
      hexSize: hexSize,
      bonusCount: count,
      flyTarget: flyTarget,
      onImpact: onImpact,
      totalBonusTiles: count,
      coinCount: coinCount,
    ));
  }

  /// Fait s'envoler une pièce depuis [origin] (coordonnées jeu, hors
  /// plateau) vers le compteur de pièces — même animation ([CoinComponent])
  /// que celles jouées depuis les côtés connectés dans
  /// [showRewardIndicators]. Utilisée par les améliorations de gain de
  /// pièces (Pièces+ global, Rouge+/Vert+/Bleu+/Jaune+/Violet+ par
  /// biome) : comme pour la particule dédiée de Combo+
  /// ([showBonusParticleFrom]), ce gain n'est lié à aucun côté de la tuile
  /// posée, donc la pièce part de l'icône de l'amélioration dans l'encart
  /// HUD plutôt que de la tuile. [startDelay] permet d'échelonner plusieurs
  /// particules si plusieurs améliorations se déclenchent sur la même pose.
  void showCoinParticleFrom(Vector2 origin,
      {VoidCallback? onImpact, double startDelay = 0.0}) {
    final hexSize = kHexSize * zoom;
    add(CoinComponent(
      position: origin.clone(),
      hexSize: hexSize,
      animated: true,
      flyTarget: _coinCounterTarget,
      onImpact: onImpact,
      startDelay: startDelay,
      priority: kTileDepthPriorityPreview + 1,
    ));
  }

  /// Calcule le décalage (dx, dy) du point milieu du côté [side] (0-5) par
  /// rapport au centre de l'hexagone, pour un hexagone pointy-top de rayon
  /// [hexSize] avec projection iso.
  Vector2 _sideEdgeMidpoint(int side, double hexSize) {
    // Sommets pointy-top, angles : 60*i - 90 degrés.
    // Le côté i va du sommet i au sommet (i+1)%6.
    // On calcule le point milieu en moyennant les deux sommets.
    final angle0 = (60.0 * side - 90.0) * pi / 180.0;
    final angle1 = (60.0 * (side + 1) - 90.0) * pi / 180.0;

    final x0 = hexSize * cos(angle0);
    final y0 = hexSize * sin(angle0) * kIsoScaleY;
    final x1 = hexSize * cos(angle1);
    final y1 = hexSize * sin(angle1) * kIsoScaleY;

    return Vector2((x0 + x1) / 2, (y0 + y1) / 2);
  }

  /// Recalcule les positions de toutes les tuiles après un changement de
  /// caméra (pan ou zoom).
  void refreshTilePositions() {
    final layout = _layout;
    for (final entry in placedTiles.entries) {
      final center = layout.hexToPixel(entry.key, isoScaleY: kIsoScaleY);
      entry.value.position = Vector2(center.x, center.y);
      entry.value.hexSize = kHexSize * zoom;
      entry.value.updateDepthPriority();
    }
    _syncPreviewComponent();
  }

  // ── Rendu (emplacements disponibles — story 1.7f) ─────────

  @override
  void render(Canvas canvas) {
    // Pendant la prévisualisation, on masque les emplacements libres.
    if (_previewCoords != null && _previewTile != null) return;
    if (availableHighlights.isEmpty) return;

    final layout = _layout;
    for (final coords in availableHighlights) {
      final center = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
      _renderHighlight(canvas, Offset(center.x, center.y));
    }
  }

  /// Ratio de surface occupée par le remplissage des emplacements
  /// disponibles (70 % de la surface de la case, en partant du centre —
  /// laisse donc une marge de 30 % visible autour, sur tout le pourtour).
  static const double _kAvailableFillAreaRatio = 0.7;

  void _renderHighlight(Canvas canvas, Offset center) {
    // On réduit le rayon (échelle linéaire) de sorte que la SURFACE occupée
    // corresponde à _kAvailableFillAreaRatio : aire ∝ rayon², donc
    // rayon_ratio = sqrt(ratio_aire).
    final scale = sqrt(_kAvailableFillAreaRatio);
    final corners = _isoHighlightCorners(center, scale: scale);

    final path = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (var i = 1; i < 6; i++) {
      path.lineTo(corners[i].dx, corners[i].dy);
    }
    path.close();

    // Case entière remplie (mais réduite à 70 % de sa surface réelle, donc
    // visuellement plus petite avec une marge tout autour), sans contour.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0A1420).withValues(alpha: 0.11)
        ..style = PaintingStyle.fill,
    );
  }

  /// Sommets d'un hexagone pointy-top avec projection iso, pour le rendu des
  /// surbrillances. [scale] permet de réduire (ou agrandir) l'hexagone
  /// depuis son centre, tout en gardant la même projection iso.
  List<Offset> _isoHighlightCorners(Offset center, {double scale = 1.0}) {
    final hexSize = kHexSize * zoom * scale;
    return List.generate(6, (i) {
      final angleDeg = 60.0 * i - 90.0;
      final angleRad = angleDeg * pi / 180.0;
      final x = hexSize * cos(angleRad);
      final y = hexSize * sin(angleRad) * kIsoScaleY;
      return Offset(center.dx + x, center.dy + y);
    });
  }

  // ── Hit-testing ───────────────────────────────────────────────────────────

  /// Convertit une position écran en coordonnées hexagonales, en tenant
  /// compte de la projection iso (story 1.5a — corrige le décalage qui
  /// existait quand le hit-testing ignorait kIsoScaleY).
  HexCoords hexAt(Offset screenPos) {
    return _layout.pixelToHex(
      Point(screenPos.dx, screenPos.dy),
      isoScaleY: kIsoScaleY,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Détecte de combien de crans de 60° [newTile] est la rotation de
  /// [oldTile] (positif ou négatif selon le sens le plus court), ou null si
  /// [newTile] n'est pas une simple rotation de [oldTile] (ex : biomes
  /// différents — nouvelle tuile plutôt que rotation).
  static int? _detectRotationSteps(HexTile oldTile, HexTile newTile) {
    // Sur une tuile à un seul biome, tous les côtés sont strictement
    // identiques quel que soit l'angle : la boucle ci-dessous "détecterait"
    // toujours n = 1 (premier cran testé, toujours égal), quel que soit le
    // nombre réel de crans appliqués par le joueur. Ce faux positif empêchait
    // le repli [_rotationDeltaFromCounters] (basé sur le compteur de crans,
    // seul fiable dans ce cas) de jamais être utilisé. On renvoie donc null
    // immédiatement pour laisser la main à ce repli.
    if (oldTile.biomeCount == 1) return null;
    for (var n = 1; n < 6; n++) {
      final rotated = oldTile.rotated(n);
      var equal = true;
      for (var i = 0; i < 6; i++) {
        if (rotated.sides[i] != newTile.sides[i]) {
          equal = false;
          break;
        }
      }
      if (equal) {
        // Ramène vers le chemin de rotation le plus court (ex : 5 crans
        // dans un sens équivaut à 1 cran dans l'autre sens).
        return n > 3 ? n - 6 : n;
      }
    }
    return null;
  }

  /// Calcule le delta de crans entre deux compteurs de rotation (0-5),
  /// ramené vers le chemin le plus court, ou null si l'un des compteurs est
  /// absent ou s'ils sont identiques (aucune rotation à animer).
  ///
  /// Sert de repli à [_detectRotationSteps] : cette dernière compare les
  /// côtés des tuiles et ne peut rien détecter pour une tuile à un seul
  /// biome (tous les côtés identiques, quel que soit l'angle). En se basant
  /// directement sur le compteur de crans plutôt que sur l'apparence de la
  /// tuile, la rotation reste détectée — et donc animée — même dans ce cas.
  static int? _rotationDeltaFromCounters(int? previous, int? current) {
    if (previous == null || current == null) return null;
    final raw = ((current - previous) % 6 + 6) % 6;
    if (raw == 0) return null;
    return raw > 3 ? raw - 6 : raw;
  }

  static BiomeType _dominantBiome(HexTile tile) {
    final counts = <BiomeType, int>{};
    for (final b in tile.sides) {
      counts[b] = (counts[b] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
