/// Calque dédié aux pastilles de taille de zone (mode "Bonus de clôture")
/// du [HexGridComponent].
///
/// Ajouté comme enfant de [HexGridComponent] (voir `onLoad`) plutôt que
/// dessiné dans le `render` du parent : dans l'arbre de rendu Flame, les
/// enfants sont dessinés après le rendu propre du parent, dans l'ordre de
/// leur [priority]. Avec [priority] fixée bien au-dessus de
/// [kTileDepthPriorityPreview] (le plus élevé utilisé par les
/// [TileComponent]), ce calque est donc systématiquement dessiné en
/// dernier — au-dessus de toutes les tuiles posées — au lieu d'apparaître
/// en dessous d'elles comme c'était le cas quand les pastilles étaient
/// dessinées directement dans le `render` du parent.
library;

import 'dart:ui'
    show
        Canvas,
        Color,
        FontWeight,
        Offset,
        Paint,
        PaintingStyle,
        RRect,
        Radius,
        Rect,
        TextDirection;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import 'package:flame/components.dart';

import '../providers/placement_commit.dart' show kAtollClosureThreshold;
import 'hex_grid_component.dart';
import 'tile_component.dart'; // kIsoScaleY, kTileDepthPriorityPreview

class BiomeSizeLabelsLayer extends PositionComponent {
  BiomeSizeLabelsLayer(this._grid)
      : super(
          position: Vector2.zero(),
          priority: kTileDepthPriorityPreview + 1000,
        );

  final HexGridComponent _grid;

  @override
  void render(Canvas canvas) {
    if (_grid.biomeSizeClusters.isEmpty) return;
    _renderBiomeSizeLabels(canvas);
  }

  /// Dessine, pour chaque zone de [HexGridComponent.biomeSizeClusters], une
  /// pastille (chiffre blanc sur fond noir translucide) centrée sur le
  /// cluster — position moyenne (x, y) de toutes ses tuiles — pas de cache
  /// de positions écran : recalculé à chaque frame à partir des coordonnées
  /// de tuiles stockées, pour rester juste après un pan/zoom.
  void _renderBiomeSizeLabels(Canvas canvas) {
    final layout = _grid.layout;
    final placedAnchors = <Offset>[];
    for (final entry in _grid.biomeSizeClusters) {
      final cluster = entry.cluster;
      if (cluster.isEmpty) continue;
      var sumX = 0.0;
      var sumY = 0.0;
      for (final coords in cluster) {
        final center = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
        sumX += center.x;
        sumY += center.y;
      }
      final rawAnchor = Offset(sumX / cluster.length, sumY / cluster.length);
      final anchor = _dedupeBadgeAnchor(rawAnchor, placedAnchors);
      placedAnchors.add(anchor);
      _drawBiomeSizeBadge(canvas, anchor, cluster.length, entry.isClosed);
    }
  }

  /// Écarte [anchor] verticalement s'il chevauche une pastille déjà placée
  /// dans [placed] (deux zones de couleur proches peuvent avoir des
  /// centroïdes très rapprochés) — décale par pas de [_kBadgeOverlapGap]
  /// jusqu'à trouver une position libre, en alternant au-dessus/au-dessous
  /// de la position d'origine pour rester proche du cluster concerné.
  static const double _kBadgeOverlapGap = 22.0;

  Offset _dedupeBadgeAnchor(Offset anchor, List<Offset> placed) {
    var candidate = anchor;
    var step = 1;
    while (placed.any((p) => (p - candidate).distance < _kBadgeOverlapGap)) {
      final direction = step.isOdd ? 1 : -1;
      final magnitude = (step / 2).ceil();
      candidate = Offset(
        anchor.dx,
        anchor.dy + direction * magnitude * _kBadgeOverlapGap,
      );
      step++;
    }
    return candidate;
  }

  static final TextPainter _biomeSizeTextPainter =
      TextPainter(textDirection: TextDirection.ltr);
  static final TextPainter _biomeLockIconPainter =
      TextPainter(textDirection: TextDirection.ltr);

  /// Glyphe cadenas — code point officiel de `Icons.lock` (police
  /// MaterialIcons), lu directement sur la constante `Icons.lock` plutôt que
  /// recopié en dur pour éviter tout risque de glyphe erroné.
  static final String _kLockGlyph = String.fromCharCode(Icons.lock.codePoint);

  /// Couleur dorée utilisée ailleurs dans le jeu pour signaler un état
  /// "actif/scellé" (contour Ressac, Emplacement Joker) — reprise ici pour
  /// le contour des zones ayant atteint le seuil de fermeture (Atoll).
  static const Color _kThresholdGoldAccent = Color(0xFFFFD54F);

  /// Contour par défaut (zone en dessous du seuil de fermeture).
  static const Color _kDefaultOutline = Color(0xFFFFFFFF);

  /// Contour des zones déjà fermées — gris clair plutôt que doré pour ne
  /// pas entrer en concurrence visuelle avec le cadenas doré à l'intérieur
  /// du badge.
  static const Color _kClosedOutline = Color(0xFFE0E0E0);

  void _drawBiomeSizeBadge(
      Canvas canvas, Offset center, int size, bool isClosed) {
    _biomeSizeTextPainter.text = TextSpan(
      text: '$size',
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
    _biomeSizeTextPainter.layout();

    const paddingH = 7.0;
    const paddingV = 3.0;
    const lockGap = 3.0;

    var lockWidth = 0.0;
    if (isClosed) {
      _biomeLockIconPainter.text = TextSpan(
        text: _kLockGlyph,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'MaterialIcons',
          color: _kThresholdGoldAccent,
        ),
      );
      _biomeLockIconPainter.layout();
      lockWidth = _biomeLockIconPainter.width + lockGap;
    }

    final contentWidth = _biomeSizeTextPainter.width + lockWidth;
    final rect = Rect.fromCenter(
      center: center,
      width: contentWidth + paddingH * 2,
      height: _biomeSizeTextPainter.height + paddingV * 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xCC000000));

    final atThreshold = size >= kAtollClosureThreshold;
    final outlineColor = isClosed
        ? _kClosedOutline
        : (atThreshold ? _kThresholdGoldAccent : _kDefaultOutline);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final contentLeft = center.dx - contentWidth / 2;
    if (isClosed) {
      _biomeLockIconPainter.paint(
        canvas,
        Offset(contentLeft, center.dy - _biomeLockIconPainter.height / 2),
      );
    }
    _biomeSizeTextPainter.paint(
      canvas,
      Offset(
        contentLeft + lockWidth,
        center.dy - _biomeSizeTextPainter.height / 2,
      ),
    );
  }
}