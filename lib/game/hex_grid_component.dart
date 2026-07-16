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
import 'dart:ui' show Canvas, Color, FontWeight, Offset, Paint, PaintingStyle, Path, TextDirection;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../core/colors.dart';
import '../core/constants.dart';
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

/// Gain total (pièces de base + pièces bonus + tuiles bonus) au-delà duquel
/// l'intensité du burst d'impact générique ([_TileGainBurst]) plafonne à
/// son maximum — au-delà, l'effet ne grossit plus, pour éviter qu'un très
/// gros multiplicateur d'amélioration ne devienne écrasant à l'écran.
const int kGainBurstMaxGain = 9;

/// Nombre maximum d'icônes de tuile bonus envoyées individuellement (effet
/// "machine à sous" échelonné) sur une même pose. Au-delà, le surplus est
/// regroupé dans la dernière icône affichée pour éviter de surcharger
/// l'écran de tuiles très rentables (grosses chaînes d'améliorations).
const int kMaxStaggeredBonusIcons = 4;

/// Délai (secondes) entre deux icônes de tuile bonus envoyées vers la pile
/// HUD lors d'une même pose.
const double kBonusIconStaggerInterval = 0.12;

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

    // Pièces au niveau de chaque côté connecté.
    for (final side in _previewHighlightedSides) {
      final offset = _sideEdgeMidpoint(side, hexSize);
      final pos = Vector2(center.x + offset.x, center.y + offset.y);
      final component = _CoinComponent(
        position: pos,
        hexSize: hexSize,
        animated: false,
      );
      component.priority = kTileDepthPriorityPreview + 1;
      _previewCoinComponents.add(component);
      add(component);
    }

    // Tuile bonus centrée sur la prévisualisation (story 1.7e).
    if (previewBonusTiles > 0) {
      final pos = Vector2(center.x, center.y - kPreviewLiftPx * 0.5);
      final component = _PreviewBonusComponent(
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

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  /// Origine de la grille en coordonnées écran (avant iso).
  /// Décalée à 42 % de la largeur pour laisser la place au HUD droit.
  HexLayout get _layout => HexLayout(
        hexSize: kHexSize * zoom,
        origin: Point(
          cameraOffset.x + screenSize.x * 0.42,
          cameraOffset.y + screenSize.y * 0.38,
        ),
      );

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
      int totalGain = 0,
      VoidCallback? onBonusImpact}) {
    final layout = _layout;
    final center = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    final centerVec = Vector2(center.x, center.y);
    final hexSize = kHexSize * zoom;

    // Impact générique à chaque pose gagnante — l'intensité (particules,
    // flash, ondes) grandit avec le gain total de la pose (pièces + bonus),
    // plafonnée à 1.0 au-delà d'un gain de kGainBurstMaxGain.
    if (totalGain > 0) {
      final intensity = (totalGain / kGainBurstMaxGain).clamp(0.0, 1.0);
      add(_TileGainBurst(
        position: centerVec,
        hexSize: hexSize,
        intensity: intensity,
      ));
      // Ondes concentriques partant de la tuile posée — habillage
      // thématique cohérent avec le shader océan, en complément du burst
      // de particules (plus perceptible sur les gains élevés).
      add(_TileRippleEffect(
        position: centerVec,
        hexSize: hexSize,
        intensity: intensity,
      ));
    }

    // Position du compteur de pièces en haut à gauche (coordonnées jeu).
    final coinCounterTarget = Vector2(26, 85);

    // Pièces volant vers le compteur depuis chaque côté connecté.
    for (final side in connectedSides) {
      final offset = _sideEdgeMidpoint(side, hexSize);
      final pos = Vector2(
        centerVec.x + offset.x,
        centerVec.y + offset.y,
      );
      add(_CoinComponent(
        position: pos,
        hexSize: hexSize,
        animated: true,
        flyTarget: coinCounterTarget,
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
        add(_BonusTileAnimComponent(
          position: centerVec.clone(),
          hexSize: hexSize,
          bonusCount: count,
          flyTarget: bonusFlyTarget,
          startDelay: i * kBonusIconStaggerInterval,
          onImpact: onBonusImpact,
        ));
      }
    }

    // Particules pour connexion parfaite (5-6 côtés).
    if (connectedSides.length >= 5) {
      add(_PerfectConnectionParticles(
        position: centerVec,
        hexSize: hexSize,
      ));
    }
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
        ..color = Color(0xFF0A1420).withValues(alpha: 0.11)
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

/// Pièce affichée au niveau d'un côté connecté — animée ou statique selon [animated].
/// Si [flyTarget] est non-null, la pièce vole vers cette position.
class _CoinComponent extends PositionComponent {
  _CoinComponent({
    required super.position,
    required double hexSize,
    this.animated = false,
    this.flyTarget,
    int priority = 10,
  })  : _radius = hexSize * 0.18,
        _alpha = animated ? null : 0.85,
        super(priority: priority);

  final double _radius;
  final bool animated;

  /// Non-null en mode statique, null en mode animé.
  final double? _alpha;

  /// Position cible pour le vol vers le compteur (null = pas de vol).
  final Vector2? flyTarget;

  double _life = 0.0;
  static const double _kDuration = 1.2;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (flyTarget != null) {
      add(MoveEffect.to(
        flyTarget!,
        EffectController(duration: 0.6, curve: Curves.easeInOut),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!animated) return;
    _life += dt;
    if (_life >= _kDuration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = animated
        ? (_life < 0.3)
            ? (_life / 0.3)
            : (1.0 - (_life - 0.3) / (_kDuration - 0.3))
        : _alpha!;
    final r = animated ? _radius + _life * 2.0 : _radius;

    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = kRewardGold.withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.7,
      Paint()
        ..color = kRewardGoldDark.withValues(alpha: alpha * 0.8)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.35,
      Paint()
        ..color = kRewardWhite.withValues(alpha: alpha * 0.9)
        ..style = PaintingStyle.fill,
    );
  }
}

/// Icône de tuile bonus centrée sur la prévisualisation (story 1.7e).
class _PreviewBonusComponent extends PositionComponent {
  _PreviewBonusComponent({
    required super.position,
    required double hexSize,
    required this.bonusCount,
  })  : _radius = hexSize * 0.22,
        super(priority: kTileDepthPriorityPreview + 1);

  final double _radius;
  final int bonusCount;

  @override
  void render(Canvas canvas) {
    const alpha = 0.9;
    final r = _radius;

    // Hexagone extérieur (fond).
    canvas.drawPath(
      _hexagonPath(r),
      Paint()
        ..color = kBonusBlueLight.withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      _hexagonPath(r * 0.75),
      Paint()
        ..color = kBonusBlueLighter.withValues(alpha: alpha * 0.7)
        ..style = PaintingStyle.fill,
    );

    // Nombre de tuiles bonus (+N) centré en blanc.
    final text = '+$bonusCount';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: kRewardWhite.withValues(alpha: alpha),
          fontSize: r * 1.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
  }

  /// Sommets d'un hexagone pointy-top de rayon [radius], centré sur
  /// l'origine — même orientation que les tuiles du plateau.
  Path _hexagonPath(double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (60.0 * i - 90.0) * pi / 180.0;
      final x = radius * cos(angle);
      final y = radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}

/// Icône de tuile bonus animée après placement — vole vers la pile HUD
/// comme les pièces (Story 4.2b).
///
/// Enrichie (effet de gain renforcé) : halo qui pulse pendant le vol,
/// traînée de particules fantômes laissée derrière l'icône, et un léger
/// "squash & stretch" à l'arrivée sur le HUD plutôt qu'une disparition
/// sèche.
class _BonusTileAnimComponent extends PositionComponent {
  _BonusTileAnimComponent({
    required super.position,
    required double hexSize,
    required this.bonusCount,
    this.flyTarget,
    double startDelay = 0.0,
    this.onImpact,
  })  : _radius = hexSize * 0.22,
        _startDelay = startDelay,
        super(priority: kTileDepthPriorityPreview + 1);

  final double _radius;
  final int bonusCount;

  /// Position cible pour le vol vers la pile HUD (null = vol stationnaire).
  final Vector2? flyTarget;

  /// Délai avant le début du vol — permet d'échelonner plusieurs icônes
  /// bonus envoyées lors d'une même pose (effet "machine à sous").
  final double _startDelay;
  double _delayElapsed = 0.0;

  /// Appelé une fois à l'arrivée sur le HUD (utilisé pour faire "pop" le
  /// compteur de pile en rythme avec chaque icône, plutôt qu'un seul pop
  /// global pour toute la pose).
  final VoidCallback? onImpact;

  double _life = 0.0;
  static const double _kFlyDuration = 0.6;
  static const double _kDuration = 0.9;

  /// Durée du rebond squash & stretch joué à l'arrivée sur le HUD.
  static const double _kArrivalBounceDuration = 0.22;
  bool _arrived = false;
  double _arrivalLife = 0.0;

  /// Intervalle entre deux dépôts de particule de traînée.
  static const double _kTrailInterval = 0.035;
  double _sinceLastTrail = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (flyTarget != null) {
      add(MoveEffect.to(
        flyTarget!,
        EffectController(
          duration: _kFlyDuration,
          curve: Curves.easeInOut,
          startDelay: _startDelay,
        ),
      )..onComplete = () {
          _arrived = true;
          onImpact?.call();
        });
    } else {
      add(MoveEffect.by(
        Vector2(0, -40),
        EffectController(
          duration: _kDuration,
          curve: Curves.easeOut,
          startDelay: _startDelay,
        ),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Tant que le délai d'échelonnement n'est pas écoulé, l'icône reste
    // invisible et immobile (voir [render]) — évite que plusieurs icônes
    // apparaissent toutes en même temps avant de s'envoler l'une après
    // l'autre.
    if (_delayElapsed < _startDelay) {
      _delayElapsed += dt;
      return;
    }
    _life += dt;

    // Traînée de particules fantômes pendant le vol vers le HUD.
    if (flyTarget != null && !_arrived) {
      _sinceLastTrail += dt;
      if (_sinceLastTrail >= _kTrailInterval) {
        _sinceLastTrail = 0.0;
        parent?.add(_TrailDot(
          position: position.clone(),
          radius: _radius * 0.4,
          color: kBonusBlueLighter,
        ));
      }
    }

    if (_arrived) {
      _arrivalLife += dt;
      if (_arrivalLife >= _kArrivalBounceDuration) {
        removeFromParent();
      }
    } else if (_life >= _kDuration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_delayElapsed < _startDelay) return;

    final progress = (_life / _kDuration).clamp(0.0, 1.0);
    final double alpha = flyTarget != null
        ? _arrived
            ? (1.0 - _arrivalLife / _kArrivalBounceDuration)
            : (_life < 0.3)
                ? (_life / 0.3)
                : (1.0 - (_life - 0.3) / (_kFlyDuration - 0.3))
        : 0.9 * (1.0 - progress);

    // Halo qui pulse légèrement pendant le vol (fréquence indépendante de
    // la durée pour rester perceptible même sur un vol bref).
    final pulse = flyTarget != null && !_arrived
        ? 1.0 + sin(_life * 18) * 0.08
        : 1.0;
    var r = (flyTarget != null ? _radius + _life * 2.0 : _radius) * pulse;

    // Squash & stretch à l'arrivée : la forme s'aplatit puis rebondit au
    // lieu de simplement s'estomper.
    var scaleX = 1.0;
    var scaleY = 1.0;
    if (_arrived) {
      final t = (_arrivalLife / _kArrivalBounceDuration).clamp(0.0, 1.0);
      // Aplatissement rapide suivi d'un léger sur-rebond avant de s'effacer.
      final squash = sin(t * pi);
      scaleX = 1.0 + squash * 0.5;
      scaleY = 1.0 - squash * 0.35;
      r *= 1.0 + t * 0.6;
    }

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Cercle extérieur (fond).
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = kBonusBlueLight.withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.75,
      Paint()
        ..color = kBonusBlueLighter.withValues(alpha: alpha * 0.7)
        ..style = PaintingStyle.fill,
    );

    // Nombre de tuiles bonus (+N) centré en blanc.
    final text = '+$bonusCount';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: kRewardWhite.withValues(alpha: alpha),
          fontSize: r * 1.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }
}

/// Particule fantôme laissée en traînée derrière une icône volante (tuile
/// bonus). Se contente de rétrécir et s'estomper rapidement sur place.
class _TrailDot extends PositionComponent {
  _TrailDot({
    required super.position,
    required double radius,
    required this.color,
  })  : _radius = radius,
        super(priority: kTileDepthPriorityPreview);

  final double _radius;
  final Color color;
  double _life = 0.0;
  static const double _kDuration = 0.25;

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= _kDuration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _kDuration).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      _radius * (1.0 - t * 0.7),
      Paint()
        ..color = color.withValues(alpha: 0.55 * (1.0 - t))
        ..style = PaintingStyle.fill,
    );
  }
}

/// Ondes concentriques partant du centre de la tuile posée — habillage
/// thématique cohérent avec le shader océan de la grille, en complément du
/// [_TileGainBurst]. Le nombre d'anneaux et leur portée grandissent avec
/// [intensity] (0.0 = gain minimal, 1.0 = gain élevé).
class _TileRippleEffect extends PositionComponent {
  _TileRippleEffect({
    required super.position,
    required double hexSize,
    required double intensity,
  })  : _hexSize = hexSize,
        _intensity = intensity.clamp(0.0, 1.0),
        super(priority: kTileDepthPriorityPreview);

  final double _hexSize;
  final double _intensity;

  double _life = 0.0;
  static const double _kDuration = 0.55;
  static const double _kRingStagger = 0.08;

  /// Deux anneaux pour un gain minimal, jusqu'à quatre pour un gain élevé.
  late final int _ringCount = 2 + (_intensity * 2).round();

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= _kDuration + _ringCount * _kRingStagger) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < _ringCount; i++) {
      final ringDelay = i * _kRingStagger;
      final ringLife = _life - ringDelay;
      if (ringLife <= 0) continue;
      final t = (ringLife / _kDuration).clamp(0.0, 1.0);
      if (t >= 1.0) continue;
      final radius = _hexSize * (0.35 + t * (1.0 + _intensity * 0.7));
      final alpha = (1.0 - t) * 0.32 * (0.6 + _intensity * 0.4);
      if (alpha <= 0.01) continue;
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..color = kBonusBlueLighter.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 + _intensity * 1.5,
      );
    }
  }
}

/// Impact visuel joué à *chaque* pose qui rapporte un gain (pièces et/ou
/// tuiles bonus), pas uniquement sur les connexions parfaites — un flash
/// radial bref et un burst de particules dont l'intensité (nombre de
/// particules, portée, opacité du flash) grandit avec [intensity]
/// (0.0 = gain minimal, 1.0 = gain élevé).
///
/// Complète [_PerfectConnectionParticles] (qui reste dédié aux connexions
/// 5-6 côtés) plutôt que de le remplacer : sur une connexion parfaite les
/// deux effets se superposent, ce qui renforce encore la sensation de
/// "gros coup".
class _TileGainBurst extends PositionComponent {
  _TileGainBurst({
    required super.position,
    required double hexSize,
    required double intensity,
  })  : _intensity = intensity.clamp(0.0, 1.0),
        _particles = _generateParticles(hexSize, intensity.clamp(0.0, 1.0)),
        super(priority: kTileDepthPriorityPreview + 1);

  final double _intensity;
  final List<_Particle> _particles;

  static List<_Particle> _generateParticles(double hexSize, double intensity) {
    final rng = Random();
    final count = 4 + (intensity * 12).round() + rng.nextInt(3);
    return List.generate(count, (_) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = (35 + rng.nextDouble() * 40) * (0.6 + intensity * 0.8);
      return _Particle(
        position: Vector2.zero(),
        velocity: Vector2(cos(angle) * speed, sin(angle) * speed),
        radius: (1.2 + rng.nextDouble() * 1.6) * (0.7 + intensity * 0.6),
        alpha: 0.85,
      );
    });
  }

  double _life = 0;
  static const double _kDuration = 0.5;

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= _kDuration) {
      removeFromParent();
      return;
    }
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.velocity *= 0.90;
      p.alpha = 0.85 * (1.0 - _life / _kDuration);
      p.radius *= max(0.3, 1.0 - dt * 1.8);
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _kDuration).clamp(0.0, 1.0);

    // Flash radial bref, uniquement perceptible pour les gains conséquents.
    if (_intensity > 0.05) {
      final flashAlpha = (1.0 - t) * 0.35 * _intensity;
      if (flashAlpha > 0.01) {
        canvas.drawCircle(
          Offset.zero,
          6 + 30 * _intensity * t,
          Paint()
            ..color = kRewardGold.withValues(alpha: flashAlpha)
            ..style = PaintingStyle.fill,
        );
      }
    }

    for (final p in _particles) {
      final color = p.alpha > 0.5
          ? kBonusBlueLighter.withValues(alpha: p.alpha)
          : kRewardWhite.withValues(alpha: p.alpha);
      canvas.drawCircle(
        Offset(p.position.x, p.position.y),
        p.radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }
}

/// Particules légères pour connexion parfaite (5-6 côtés — Story 4.2b).
class _PerfectConnectionParticles extends PositionComponent {
  _PerfectConnectionParticles({
    required super.position,
    required double hexSize,
  }) : _particles = _generateParticles(hexSize),
       super(priority: kTileDepthPriorityPreview + 1);

  static List<_Particle> _generateParticles(double hexSize) {
    final rng = Random();
    final count = 10 + rng.nextInt(6);
    return List.generate(count, (_) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 50 + rng.nextDouble() * 60;
      return _Particle(
        position: Vector2.zero(),
        velocity: Vector2(cos(angle) * speed, sin(angle) * speed),
        radius: 1.5 + rng.nextDouble() * 2.0,
        alpha: 0.9,
      );
    });
  }

  final List<_Particle> _particles;
  double _life = 0;
  static const double _kDuration = 0.7;

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= _kDuration) {
      removeFromParent();
      return;
    }
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.velocity *= 0.93;
      p.alpha = 0.9 * (1.0 - _life / _kDuration);
      p.radius *= max(0.3, 1.0 - dt * 1.5);
    }
  }

  @override
  void render(Canvas canvas) {
    for (final p in _particles) {
      final color = p.alpha > 0.5
          ? kRewardGold.withValues(alpha: p.alpha)
          : kRewardWhite.withValues(alpha: p.alpha);
      canvas.drawCircle(
        Offset(p.position.x, p.position.y),
        p.radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }
}

/// Donnée d'une particule individuelle.
class _Particle {
  _Particle({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.alpha,
  });

  Vector2 position;
  Vector2 velocity;
  double radius;
  double alpha;
}
