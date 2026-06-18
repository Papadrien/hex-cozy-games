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

/// Opacité de la tuile en prévisualisation (translucide — story 1.5a).
const double kPreviewAlpha = 0.62;

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
      return;
    }

    final component = TileComponent(
      tile: tile,
      coords: coords,
      hexSize: kBaseHexSize * zoom,
      alpha: kPreviewAlpha,
      position: liftedPosition,
    );
    // Priorité plus élevée que les tuiles posées (priority: 1) pour que la
    // prévisualisation "surélevée" reste visuellement au-dessus en cas de
    // chevauchement avec une tuile voisine déjà posée.
    component.priority = 2;
    _previewComponent = component;
    add(component);
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
  void placeTile(HexCoords coords, HexTile tile) {
    final existing = placedTiles.remove(coords);
    if (existing != null) remove(existing);

    final center = _layout.hexToPixel(coords, isoScaleY: kIsoScaleY);

    final component = TileComponent(
      tile: tile,
      coords: coords,
      hexSize: kBaseHexSize * zoom,
      position: Vector2(center.x, center.y),
    );

    placedTiles[coords] = component;
    add(component);

    placedCells[coords] = HexCell(
      q: coords.q,
      r: coords.r,
      biome: _dominantBiome(tile),
    );
  }

  void removeTile(HexCoords coords) {
    final existing = placedTiles.remove(coords);
    if (existing != null) remove(existing);
    placedCells.remove(coords);
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
    // Les tuiles posées et la prévisualisation sont des PositionComponent
    // enfants, Flame les dessine automatiquement par-dessus. Ici on ne
    // dessine QUE les surbrillances des emplacements disponibles — c'est le
    // seul indicateur de grille visible, aucun contour de grille par
    // ailleurs (règle story 1.2 / 1.5a).
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
