/// Prévisualisation de placement (story 1.5a) du [HexGridComponent] — mixin
/// permettant d'isoler cette logique dans un fichier dédié tout en partageant
/// l'état et l'arbre de rendu du composant parent.
///
/// Gère : la surbrillance des emplacements disponibles, le [TileComponent]
/// de prévisualisation translucide/surélevé, la rotation animée, les icônes
/// de pièces des côtés connectés et l'icône de tuile bonus.
library;

import 'dart:math';

import 'package:flame/components.dart';

import '../core/constants.dart';
import 'bonus_animations.dart';
import 'hex_coords.dart';
import 'hex_grid_constants.dart';
import 'hex_tile.dart';
import 'tile_component.dart'; // kIsoScaleY, TileComponent

/// Calcule le décalage (dx, dy) du point milieu du côté [side] (0-5) par
/// rapport au centre de l'hexagone, pour un hexagone pointy-top de rayon
/// [hexSize] avec projection iso.
Vector2 sideEdgeMidpoint(int side, double hexSize) {
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

/// Logique de prévisualisation de placement, appliquée au composant de grille.
///
/// Le mixin repose sur le contrat suivant fourni par l'hôte (voir
/// [HexGridComponent]) : [layout], [zoom], [placedTiles], [add] et [remove].
mixin HexGridPreviewMixin on PositionComponent {
  /// Origine de la grille en coordonnées écran (voir [HexGridComponent.layout]).
  HexLayout get layout;

  /// Zoom courant de la grille (voir [HexGridComponent.zoom]).
  double get zoom;

  /// Tuiles posées par coordonnées (voir [HexGridComponent.placedTiles]).
  Map<HexCoords, TileComponent> get placedTiles;

  HexCoords? _previewCoords;
  HexTile? _previewTile;
  TileComponent? _previewComponent;

  /// Dernier couple (coords, tuile) synchronisé, utilisé pour distinguer une
  /// simple rotation de la tuile prévisualisée (même emplacement) d'une
  /// nouvelle sélection (déclenche l'animation de rotation plutôt qu'un
  /// remplacement instantané — voir [syncPreviewComponent]).
  HexCoords? _lastSyncedPreviewCoords;
  HexTile? _lastSyncedPreviewTile;

  /// Dernier nombre de crans de rotation (0-5) synchronisé pour la tuile en
  /// prévisualisation. Sert à détecter une rotation même quand la tuile a un
  /// seul biome (dans ce cas [detectRotationSteps] ne peut rien détecter en
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
    syncPreviewCoinComponents();
  }

  /// Nombre de tuiles bonus.
  int previewBonusTiles = 0;

  /// Surbrillance des côtés des tuiles voisines qui seront connectées.
  Map<HexCoords, Set<int>> get previewNeighborHighlights =>
      _previewNeighborHighlights;
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
    syncPreviewComponent();
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
    syncPreviewComponent();
  }

  /// Crée, met à jour ou retire le [TileComponent] de prévisualisation selon
  /// l'état courant de [_previewCoords] / [_previewTile]. Rendu translucide
  /// et légèrement surélevé (décalage vertical négatif en écran "plat", donc
  /// vers le haut de l'écran une fois la projection iso appliquée) pour le
  /// distinguer clairement d'une tuile réellement posée.
  void syncPreviewComponent() {
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

    final center = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
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
        final steps = detectRotationSteps(previousTile, tile) ??
            rotationDeltaFromCounters(previousSteps, _previewRotationSteps);
        if (steps != null) {
          existing.animateRotationSwirl(steps);
        }
      }
      _lastSyncedPreviewCoords = coords;
      _lastSyncedPreviewTile = tile;
      _lastSyncedPreviewRotationSteps = _previewRotationSteps;
      syncPreviewCoinComponents();
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

    syncPreviewCoinComponents();
  }

  /// Gère les icônes de pièces au niveau de chaque côté bien connecté pendant
  /// la prévisualisation, ainsi que l'icône de tuile bonus centrée sur la
  /// prévisualisation si une ou plusieurs tuiles bonus sont gagnées (story 1.7e).
  void syncPreviewCoinComponents() {
    for (final c in _previewCoinComponents) {
      remove(c);
    }
    _previewCoinComponents.clear();

    if (_previewCoords == null) return;

    final layout = this.layout;
    final center = layout.hexToPixel(_previewCoords!, isoScaleY: kIsoScaleY);
    final hexSize = kHexSize * zoom;

    // Pièces au niveau de chaque côté connecté. On les décale légèrement
    // vers l'extérieur (à l'opposé du centre de la tuile en cours de pose)
    // et on les surélève de la même distance pour un effet de profondeur
    // 3D — l'icône se détache ainsi mieux de la tuile qui va être posée
    // au lieu de sembler collée dessus. Opacité pleine (pas de
    // [staticAlpha] réduit) pour rester bien visible pendant la prévisualisation.
    for (final side in _previewHighlightedSides) {
      final offset = sideEdgeMidpoint(side, hexSize);
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
    // prévisualisation (voir [syncPreviewComponent]) pour être bien
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

  /// Centre écran (coordonnées jeu, confondues avec les pixels écran — pas
  /// de caméra Flame séparée ici) de la tuile actuellement en
  /// prévisualisation, ou `null` si aucune sélection. Utilisé comme ancre
  /// pour la rotation circulaire au doigt (voir [HexBoardGame._handleRotation]).
  Vector2? get previewScreenCenter {
    final coords = _previewCoords;
    if (coords == null) return null;
    final center = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    return Vector2(center.x, center.y);
  }

  /// Détecte de combien de crans de 60° [newTile] est la rotation de
  /// [oldTile] (positif ou négatif selon le sens le plus court), ou null si
  /// [newTile] n'est pas une simple rotation de [oldTile] (ex : biomes
  /// différents — nouvelle tuile plutôt que rotation).
  static int? detectRotationSteps(HexTile oldTile, HexTile newTile) {
    // Sur une tuile à un seul biome, tous les côtés sont strictement
    // identiques quel que soit l'angle : la boucle ci-dessous "détecterait"
    // toujours n = 1 (premier cran testé, toujours égal), quel que soit le
    // nombre réel de crans appliqués par le joueur. Ce faux positif empêchait
    // le repli [rotationDeltaFromCounters] (basé sur le compteur de crans,
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
  /// Sert de repli à [detectRotationSteps] : cette dernière compare les
  /// côtés des tuiles et ne peut rien détecter pour une tuile à un seul
  /// biome (tous les côtés identiques, quel que soit l'angle). En se basant
  /// directement sur le compteur de crans plutôt que sur l'apparence de la
  /// tuile, la rotation reste détectée — et donc animée — même dans ce cas.
  static int? rotationDeltaFromCounters(int? previous, int? current) {
    if (previous == null || current == null) return null;
    final raw = ((current - previous) % 6 + 6) % 6;
    if (raw == 0) return null;
    return raw > 3 ? raw - 6 : raw;
  }
}
