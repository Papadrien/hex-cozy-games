/// Composant Flame gérant l'affichage de la grille hexagonale.
///
/// Story 1.2 : grille invisible, hexagones pointy-top, coordonnées axiales,
///             pan/zoom, hit-testing.
/// Story 1.3 : les cellules posées sont rendues via [TileComponent].
/// Story 1.5a : surbrillance des emplacements disponibles + prévisualisation
///              translucide/surélevée de la tuile active (voir
///              `hex_grid_preview.dart`). Seul indicateur de
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
import '../providers/placement_commit.dart' show kAtollClosureThreshold;
import 'biome_size_labels_layer.dart';
import 'bonus_animations.dart';
import 'hex_coords.dart';
import 'hex_cell.dart';
import 'hex_grid_constants.dart';
import 'hex_grid_preview.dart';
import 'hex_tile.dart';
import 'tile_component.dart'; // kIsoScaleY, TileComponent

class HexGridComponent extends PositionComponent
    with HexGridPreviewMixin {
  HexGridComponent({required this.screenSize})
      : super(position: Vector2.zero(), priority: 0);

  Vector2 screenSize;

  /// Position du compteur de pièces en haut à gauche (coordonnées jeu) —
  /// cible de vol de [showRewardIndicators] (pièces de connexion), et
  /// exposée via [coinCounterTarget] pour [UpgradeFxOverlayGame] (canevas
  /// superposé au HUD, voir `upgrade_fx_overlay_game.dart`), qui y fait
  /// voler les pièces bonus des améliorations (Pièces+ global,
  /// Rouge+/Vert+/Bleu+/Jaune+/Violet+ par biome).
  static final Vector2 _coinCounterTarget = Vector2(26, 85);

  /// Exposition publique de [_coinCounterTarget] — voir ci-dessus.
  static Vector2 get coinCounterTarget => _coinCounterTarget;

  /// Appelé lorsqu'une tuile posée en animé atteint sa position finale (fin
  /// du rebond). Permet au [FlameGame] parent de déclencher un bruitage
  /// (voir `AudioService.playTilePlaced`) sans coupler ce composant à
  /// Riverpod.
  VoidCallback? onTilePlaced;

  // ── État ──────────────────────────────────────────────────────────────────

  final Map<HexCoords, HexCell> placedCells = {};
  @override
  final Map<HexCoords, TileComponent> placedTiles = {};

  /// Mode sélection de Deuxième chance actif (voir `hex_board_game.dart`) :
  /// propage le contour doré ([TileComponent.showSecondChanceOutline]) à
  /// toutes les tuiles déjà posées, et sert de valeur par défaut pour toute
  /// nouvelle tuile ajoutée pendant que le mode reste actif (restauration de
  /// partie mise à part, ces deux modes sont mutuellement exclusifs).
  bool _secondChanceHighlightActive = false;
  bool get secondChanceHighlightActive => _secondChanceHighlightActive;
  set secondChanceHighlightActive(bool value) {
    if (_secondChanceHighlightActive == value) return;
    _secondChanceHighlightActive = value;
    for (final tile in placedTiles.values) {
      tile.showSecondChanceOutline = value;
    }
  }

  /// Zones de couleur (clusters de tuiles connectées par un même biome, hors
  /// village) à afficher avec leur taille — bascule tap sur le slot "Bonus
  /// de clôture" de l'encart des améliorations actives (voir
  /// `active_upgrades_hud.dart`, [biomeSizeOverlayProvider]). Liste vide =
  /// aucun affichage. Recalculée par [HexBoardGame] à chaque pose/retrait
  /// tant que l'overlay reste actif — voir [render]. `isClosed` (voir
  /// [GridState.allBiomeClusters]) affiche un cadenas doré sur les zones
  /// déjà scellées, avec un contour gris clair. Les zones non fermées ayant
  /// atteint [kAtollClosureThreshold] affichent un contour doré (récompense
  /// acquise si la zone se ferme) ; en dessous du seuil, le contour reste
  /// blanc. `openEdges` n'est plus utilisé pour le rendu (ancien diagnostic
  /// [Atoll], retiré) mais reste renseigné par [GridState.allBiomeClusters].
  List<
      ({
        Set<HexCoords> cluster,
        bool isClosed,
        List<({HexCoords coords, int side})> openEdges
      })> biomeSizeClusters = const [];

  /// Enfant dédié au dessin des pastilles de taille de zone, ajouté dans
  /// [onLoad] avec une priorité largement supérieure à celle de n'importe
  /// quelle [TileComponent] (voir [kTileDepthPriorityPreview] dans
  /// `tile_component.dart`) : en tant qu'enfant de ce composant, il fait
  /// partie du même arbre de rendu que les tuiles posées et est donc
  /// dessiné APRÈS elles (priorité la plus haute = dessiné en dernier),
  /// donc au-dessus du plateau plutôt qu'en dessous. Voir
  /// `biome_size_labels_layer.dart`.
  late final BiomeSizeLabelsLayer _biomeSizeLabelsLayer =
      BiomeSizeLabelsLayer(this);

  // ── Emplacements disponibles (story 1.5a) ────────────────────────────────

  /// Emplacements actuellement disponibles (surbrillance). Réassigner
  /// déclenche un recalcul du rendu au prochain frame, pas de besoin de
  /// `setState`-like ici : [render] lit directement ce champ.
  Set<HexCoords> availableHighlights = const {};

  // ── Caméra ────────────────────────────────────────────────────────────────

  Vector2 cameraOffset = Vector2.zero();
  @override
  double zoom = 1.0;
  static const double minZoom = 0.4;
  static const double maxZoom = 2.0;

  /// Marge (en pixels écran) conservée entre le centre du plateau (0,0) et
  /// le bord de l'écran une fois clampé — évite que la tuile centrale ne
  /// se retrouve collée pile au bord, à moitié masquée par le HUD.
  static const double _centerTileScreenMargin = 32.0;

  /// Ancre écran (fraction de la largeur/hauteur) de l'origine du plateau
  /// (0, 0) — utilisée à la fois par [layout] et [clampCameraOffset], qui
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
    await add(_biomeSizeLabelsLayer);
  }

  /// Origine de la grille en coordonnées écran (avant iso). Ancré au
  /// centre de l'écran ([_originAnchorX]/[_originAnchorY]).
  @override
  HexLayout get layout => HexLayout(
        hexSize: kHexSize * zoom,
        origin: Point(
          cameraOffset.x + screenSize.x * _originAnchorX,
          cameraOffset.y + screenSize.y * _originAnchorY,
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

    final center = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
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

    component.showSecondChanceOutline = _secondChanceHighlightActive;

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
    previewNeighborHighlights = const {};
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
    final layout = this.layout;
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
      final offset = sideEdgeMidpoint(side, hexSize);
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

    // Icône(s) de tuile bonus qui volent vers la pile HUD : une icône
    // individuelle "+1" par tuile bonus gagnée, avec un léger décalage
    // temporel (effet "machine à sous") — plus de fusion en une seule
    // icône "+N" au-delà d'un certain nombre : chaque tuile doit se
    // ressentir individuellement (vibration croissante à chaque arrivée,
    // voir [HapticsService.bonusTileArrived]).
    if (bonusTiles > 0) {
      for (var i = 0; i < bonusTiles; i++) {
        add(BonusTileAnimComponent(
          position: centerVec.clone(),
          hexSize: hexSize,
          bonusCount: 1,
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

  /// Recalcule les positions de toutes les tuiles après un changement de
  /// caméra (pan ou zoom).
  void refreshTilePositions() {
    final layout = this.layout;
    for (final entry in placedTiles.entries) {
      final center = layout.hexToPixel(entry.key, isoScaleY: kIsoScaleY);
      entry.value.position = Vector2(center.x, center.y);
      entry.value.hexSize = kHexSize * zoom;
      entry.value.updateDepthPriority();
    }
    syncPreviewComponent();
  }

  // ── Rendu (emplacements disponibles — story 1.7f) ─────────

  @override
  void render(Canvas canvas) {
    // Pendant la prévisualisation, on masque les emplacements libres.
    if (previewCoords != null && previewTile != null) return;
    if (availableHighlights.isEmpty) return;

    final layout = this.layout;
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
    return layout.pixelToHex(
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