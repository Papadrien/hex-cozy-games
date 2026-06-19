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

import 'package:flame/components.dart';

import 'hex_coords.dart';
import 'hex_cell.dart';
import 'hex_tile.dart';
import 'tile_component.dart'; // kIsoScaleY, TileComponent

/// Taille de base de l'hexagone (rayon circumscrit) en pixels logiques.
const double kBaseHexSize = 48.0;

/// Décalage vertical (en pixels écran "plat", avant projection iso) de la
/// tuile en prévisualisation pour la faire paraître "légèrement surélevée"
/// au-dessus du plateau (story 1.5a).
const double kPreviewLiftPx = 10.0;

/// Opacité de la tuile en prévisualisation.
const double kPreviewAlpha = 1.0;

/// Opacité de fond des emplacements disponibles en surbrillance.
const double kHighlightFillAlpha = 0.48;
const double kHighlightStrokeAlpha = 0.82;

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
      return;
    }

    final center = _layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    final liftedPosition = Vector2(
      center.x,
      center.y - kPreviewLiftPx,
    );

    final existing = _previewComponent;
    if (existing != null) {
      existing.tile = tile;
      existing.hexSize = kBaseHexSize * zoom;
      existing.position = liftedPosition;
      existing.highlightedSides = _previewHighlightedSides;
      _syncPreviewCoinComponents();
      return;
    }

    final component = TileComponent(
      tile: tile,
      coords: coords,
      hexSize: kBaseHexSize * zoom,
      alpha: kPreviewAlpha,
      highlightedSides: _previewHighlightedSides,
      position: liftedPosition,
    );
    component.priority = 2;
    _previewComponent = component;
    add(component);

    _syncPreviewCoinComponents();
  }

  /// Gère les icônes de pièces au niveau de chaque côté bien connecté pendant
  /// la prévisualisation.
  void _syncPreviewCoinComponents() {
    for (final c in _previewCoinComponents) {
      remove(c);
    }
    _previewCoinComponents.clear();

    if (_previewCoords == null || _previewHighlightedSides.isEmpty) return;

    final layout = _layout;
    final center = layout.hexToPixel(_previewCoords!, isoScaleY: kIsoScaleY);
    final hexSize = kBaseHexSize * zoom;

    for (final side in _previewHighlightedSides) {
      final offset = _sideEdgeMidpoint(side, hexSize);
      final pos = Vector2(center.x + offset.x, center.y + offset.y);
      final component = _PreviewCoinComponent(
        position: pos,
        hexSize: hexSize,
      );
      component.priority = 11;
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

  /// Origine de la grille en coordonnées écran (avant iso).
  /// Décalée à 42 % de la largeur pour laisser la place au HUD droit.
  HexLayout get _layout => HexLayout(
        hexSize: kBaseHexSize * zoom,
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
      {List<int>? connectedSides, Set<int>? highlightedSides}) {
    final existing = placedTiles.remove(coords);
    if (existing != null) remove(existing);

    final center = _layout.hexToPixel(coords, isoScaleY: kIsoScaleY);

    final component = TileComponent(
      tile: tile,
      coords: coords,
      hexSize: kBaseHexSize * zoom,
      position: Vector2(center.x, center.y),
      highlightedSides: const {},
    );

    if (connectedSides != null && connectedSides.isNotEmpty) {
      component.startGlow(connectedSides);
    }

    placedTiles[coords] = component;
    add(component);

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
  /// sur la tuile placée en [coords], ainsi que les tuiles bonus au-dessus de
  /// la cellule. Les indicateurs disparaissent automatiquement après animation.
  void showRewardIndicators(HexCoords coords, List<int> connectedSides,
      {int bonusTiles = 0}) {
    final layout = _layout;
    final center = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    final centerVec = Vector2(center.x, center.y);
    final hexSize = kBaseHexSize * zoom;

    // Pièces au niveau de chaque côté connecté.
    for (final side in connectedSides) {
      final offset = _sideEdgeMidpoint(side, hexSize);
      final pos = Vector2(
        centerVec.x + offset.x,
        centerVec.y + offset.y,
      );
      add(_RewardCoinComponent(position: pos, hexSize: hexSize));
    }

    // Tuiles bonus : incrémentées dans le stock via addBonusTiles,
    // pas d'icône visuelle ici.
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
      entry.value.hexSize = kBaseHexSize * zoom;
    }
    _syncPreviewComponent();
  }

  // ── Rendu (grille invisible — story 1.2 / surbrillances — story 1.5a) ────

  @override
  void render(Canvas canvas) {
    // Pendant la prévisualisation, on masque les surbrillances.
    if (_previewCoords != null && _previewTile != null) return;
    if (availableHighlights.isEmpty) return;

    final layout = _layout;
    for (final coords in availableHighlights) {
      // Une cellule déjà occupée par la prévisualisation reste surlignée
      // dessous : c'est voulu, ça montre que l'emplacement reste "valide"
      // pendant qu'on y prévisualise la tuile.
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

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFF3B0).withValues(alpha: kHighlightFillAlpha)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFE066).withValues(alpha: kHighlightStrokeAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  /// Sommets d'un hexagone pointy-top avec projection iso, pour le rendu des
  /// surbrillances (même convention d'angle que [TileComponent._isoCorners]).
  List<Offset> _isoHighlightCorners(Offset center) {
    final hexSize = kBaseHexSize * zoom;
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

  static BiomeType _dominantBiome(HexTile tile) {
    final counts = <BiomeType, int>{};
    for (final b in tile.sides) {
      counts[b] = (counts[b] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

/// Pièce de récompense animée affichée au niveau d'un côté connecté.
class _RewardCoinComponent extends PositionComponent {
  _RewardCoinComponent({required super.position, required double hexSize})
      : _radius = hexSize * 0.18,
        super(priority: 10);

  final double _radius;
  double _life = 0.0;
  static const double _kDuration = 1.2;

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
    final alpha = (_life < 0.3)
        ? (_life / 0.3)
        : (1.0 - (_life - 0.3) / (_kDuration - 0.3));
    final r = _radius + _life * 2.0;

    // Fond du cercle
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = const Color(0xFFFFD600).withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
    // Cercle intérieur
    canvas.drawCircle(
      Offset.zero,
      r * 0.7,
      Paint()
        ..color = const Color(0xFFFFA000).withValues(alpha: alpha * 0.8)
        ..style = PaintingStyle.fill,
    );
    // Symbole pièce
    canvas.drawCircle(
      Offset.zero,
      r * 0.35,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.9)
        ..style = PaintingStyle.fill,
    );
  }
}

/// Pièce statique pour la prévisualisation (au niveau d'un côté connecté).
class _PreviewCoinComponent extends PositionComponent {
  _PreviewCoinComponent({required super.position, required double hexSize})
      : _radius = hexSize * 0.18,
        super(priority: 10);

  final double _radius;

  @override
  void render(Canvas canvas) {
    const alpha = 0.85;
    final r = _radius;

    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = const Color(0xFFFFD600).withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.7,
      Paint()
        ..color = const Color(0xFFFFA000).withValues(alpha: alpha * 0.8)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.35,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.9)
        ..style = PaintingStyle.fill,
    );
  }
}



