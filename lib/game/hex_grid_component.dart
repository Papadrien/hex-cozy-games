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

// ── Animation de pose (descente + léger rebond "flottant") ─────────────────

/// Hauteur de départ de la descente : la tuile posée part de la même
/// élévation que la prévisualisation, pour un enchaînement visuel continu.
const double kDropStartLiftPx = kPreviewLiftPx;

/// Profondeur du dépassement sous l'emplacement final, avant le rebond de
/// remontée (effet "posée dans l'eau, qui flotte légèrement en remontant").
const double kDropBounceOvershootPx = 2.0;

/// Durée de la phase de descente.
const double kDropDescendDurationSec = 0.20;

/// Durée de la phase de rebond (remontée jusqu'à la position finale).
const double kDropBounceDurationSec = 0.16;

/// Durée de la montée en puissance de l'ondulation du bord bas une fois la
/// tuile arrivée à son emplacement final.
const double kDropWaveRampInDurationSec = 0.45;

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
      final sameCell = _lastSyncedPreviewCoords == coords;
      existing.tile = tile;
      existing.hexSize = kHexSize * zoom;
      existing.position = liftedPosition;
      existing.highlightedSides = _previewHighlightedSides;
      if (sameCell && previousTile != null) {
        final steps = _detectRotationSteps(previousTile, tile);
        if (steps != null) {
          existing.animateRotationSwirl(steps);
        }
      }
      _lastSyncedPreviewCoords = coords;
      _lastSyncedPreviewTile = tile;
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
  static const double maxZoom = 3.0;

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
      // visible immédiatement.
      initialWaveIntensity: animated ? 0.0 : 1.0,
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
          component.startWaveRampIn(duration: kDropWaveRampInDurationSec);
        };
      component.add(SequenceEffect([descend, bounceBack]));
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

  void removeTile(HexCoords coords) {
    final existing = placedTiles.remove(coords);
    if (existing != null) remove(existing);
    placedCells.remove(coords);
  }

  /// Affiche des pièces (pièces de monnaie) au niveau de chaque côté connecté
  /// sur la tuile placée en [coords], les tuiles bonus au-dessus de la cellule,
  /// et des particules pour les connexions parfaites.
  /// Les indicateurs disparaissent automatiquement après animation.
  void showRewardIndicators(HexCoords coords, List<int> connectedSides,
      {int bonusTiles = 0}) {
    final layout = _layout;
    final center = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    final centerVec = Vector2(center.x, center.y);
    final hexSize = kHexSize * zoom;

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

    // Icône de tuile bonus qui flotte et disparaît.
    if (bonusTiles > 0) {
      add(_BonusTileAnimComponent(
        position: centerVec,
        hexSize: hexSize,
        bonusCount: bonusTiles,
      ));
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

  void _renderHighlight(Canvas canvas, Offset center) {
    final corners = _isoHighlightCorners(center);

    final path = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (var i = 1; i < 6; i++) {
      path.lineTo(corners[i].dx, corners[i].dy);
    }
    path.close();

    // Contour sombre seulement (story 1.7f), sans remplissage.
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(0xFF0A1420).withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  /// Sommets d'un hexagone pointy-top avec projection iso, pour le rendu des
  /// surbrillances.
  List<Offset> _isoHighlightCorners(Offset center) {
    final hexSize = kHexSize * zoom;
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
  }
}

/// Icône de tuile bonus animée après placement — flotte vers le haut
/// puis disparaît (Story 4.2b).
class _BonusTileAnimComponent extends PositionComponent {
  _BonusTileAnimComponent({
    required super.position,
    required double hexSize,
    required this.bonusCount,
  })  : _radius = hexSize * 0.22,
        super(priority: kTileDepthPriorityPreview + 1);

  final double _radius;
  final int bonusCount;

  double _life = 0.0;
  static const double _kDuration = 0.9;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(MoveEffect.by(
      Vector2(0, -40),
      EffectController(duration: _kDuration, curve: Curves.easeOut),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= _kDuration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_life / _kDuration).clamp(0.0, 1.0);
    final alpha = 0.9 * (1.0 - progress);
    final r = _radius;

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
