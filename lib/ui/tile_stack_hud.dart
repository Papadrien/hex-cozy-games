/// UI de la pile de tuiles (HUD) — Story 1.4b / 1.10a.
///
/// Affiche les 3 prochaines tuiles ([tileStackProvider]) en haut à droite.
///
/// Story 1.10a — Palmiers sprites :
/// Les tuiles avec des [PalmPlacement] affichent les sprites PNG dans le HUD
/// via un [PalmHudPainter] qui dessine l'image positionnée sur le sixième
/// forêt correspondant.
library;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_cell.dart';
import '../game/hex_tile.dart';
import '../game/tile_component.dart' show BiomeColor;
import '../providers/placement_provider.dart';
import '../providers/tile_stack_provider.dart';

const double _kActiveTileRadius = 34.0;
const double _kUpcomingTileRadius = 26.0;
const double _kHudHexFlattenY = 1.0;

// ── Cache des images PNG pour le HUD ────────────────────────────────────────

/// Cache statique des ui.Image décodés pour le HUD Flutter.
/// (Séparé du PalmSpriteCache Flame — Flutter et Flame ont des types Image
/// distincts ; le HUD est un widget Flutter, pas un composant Flame.)
class _PalmImageCache {
  _PalmImageCache._();
  static final _PalmImageCache instance = _PalmImageCache._();

  ui.Image? img1;
  ui.Image? img2;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    img1 = await _loadAssetImage('assets/palm_tree_1.png');
    img2 = await _loadAssetImage('assets/palm_tree_2.png');
    _loaded = true;
  }

  ui.Image? get(int variantIndex) =>
      variantIndex == 0 ? img1 : img2;

  static Future<ui.Image> _loadAssetImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

// ── Widget principal ─────────────────────────────────────────────────────────

class TileStackHud extends ConsumerStatefulWidget {
  const TileStackHud({super.key});

  @override
  ConsumerState<TileStackHud> createState() => _TileStackHudState();
}

class _TileStackHudState extends ConsumerState<TileStackHud> {
  bool _imagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _PalmImageCache.instance.load().then((_) {
      if (mounted) setState(() => _imagesLoaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stackState = ref.watch(tileStackProvider);
    final placement = ref.watch(placementProvider);
    final visible = stackState.visible;

    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _kActiveTileRadius * sqrt(3) + 28,
          height: _kActiveTileRadius * 2 + 24,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (var i = visible.length - 1; i >= 0; i--)
                _StackedTile(
                  tile: visible[i],
                  indexInStack: i,
                  imagesLoaded: _imagesLoaded,
                ),
              if (placement.hasSelection)
                Center(
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(placementProvider.notifier).clearSelection(),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white70),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _RemainingBadge(remaining: stackState.remaining),
      ],
    );
  }
}

class _StackedTile extends StatelessWidget {
  const _StackedTile({
    required this.tile,
    required this.indexInStack,
    required this.imagesLoaded,
  });

  final HexTile tile;
  final int indexInStack;
  final bool imagesLoaded;

  bool get _isActive => indexInStack == 0;

  @override
  Widget build(BuildContext context) {
    final radius = _isActive ? _kActiveTileRadius : _kUpcomingTileRadius;
    final step = indexInStack.toDouble();
    final dx = -step * (_kUpcomingTileRadius * 0.62);
    final dy = -step * (_kUpcomingTileRadius * 0.46);

    return Positioned(
      left: null,
      right: null,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: _HexTilePreview(
          tile: tile,
          radius: radius,
          highlighted: _isActive,
          dim: !_isActive,
          imagesLoaded: imagesLoaded,
        ),
      ),
    );
  }
}

class _HexTilePreview extends StatelessWidget {
  const _HexTilePreview({
    required this.tile,
    required this.radius,
    required this.highlighted,
    required this.dim,
    required this.imagesLoaded,
  });

  final HexTile tile;
  final double radius;
  final bool highlighted;
  final bool dim;
  final bool imagesLoaded;

  @override
  Widget build(BuildContext context) {
    final size = Size(radius * sqrt(3), radius * 2 * _kHudHexFlattenY);

    return DecoratedBox(
      decoration: highlighted
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : const BoxDecoration(),
      child: CustomPaint(
        size: size,
        painter: _HexTilePainter(
          tile: tile,
          highlighted: highlighted,
          alpha: dim ? 0.62 : 1.0,
          imagesLoaded: imagesLoaded,
          palmImageCache: _PalmImageCache.instance,
        ),
      ),
    );
  }
}

class _HexTilePainter extends CustomPainter {
  _HexTilePainter({
    required this.tile,
    required this.highlighted,
    required this.alpha,
    required this.imagesLoaded,
    required this.palmImageCache,
  });

  final HexTile tile;
  final bool highlighted;
  final double alpha;
  final bool imagesLoaded;
  final _PalmImageCache palmImageCache;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2;
    final corners = _corners(center, radius);

    // ── Sixièmes colorés ──────────────────────────────────────────────────
    for (var i = 0; i < 6; i++) {
      final c0 = corners[i];
      final c1 = corners[(i + 1) % 6];
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = tile.sides[i].color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Contour ───────────────────────────────────────────────────────────
    final outline = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (var i = 1; i < 6; i++) {
      outline.lineTo(corners[i].dx, corners[i].dy);
    }
    outline.close();

    canvas.drawPath(
      outline,
      Paint()
        ..color = Colors.black.withValues(alpha: alpha * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    if (highlighted) {
      canvas.drawPath(
        outline,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // ── Palmiers sprites (story 1.10a) ─────────────────────────────────────
    if (imagesLoaded && tile.palms.isNotEmpty) {
      _paintPalmSprites(canvas, center, radius, corners);
    }
  }

  void _paintPalmSprites(
    Canvas canvas,
    Offset center,
    double radius,
    List<Offset> corners,
  ) {
    for (final palm in tile.palms) {
      if (tile.sides[palm.sideIndex] != BiomeType.forest) continue;

      final img = palmImageCache.get(palm.variantIndex);
      if (img == null) continue;

      final c0 = corners[palm.sideIndex];
      final c1 = corners[(palm.sideIndex + 1) % 6];

      // Centre du sixième.
      final midX = (center.dx + c0.dx + c1.dx) / 3;
      final midY = (center.dy + c0.dy + c1.dy) / 3;

      // Position du pied du palmier.
      final baseAngle = atan2(midY - center.dy, midX - center.dx);
      final angle = baseAngle + palm.angleFrac * 2 * pi;
      final dist = palm.offsetFrac * radius;

      final footX = center.dx + cos(angle) * dist;
      final footY = center.dy + sin(angle) * dist;

      // Taille d'affichage : hauteur proportionnelle au radius du HUD.
      final h = radius * 0.85 * palm.scaleFrac;
      final imgW = img.width.toDouble();
      final imgH = img.height.toDouble();
      final w = h * (imgW / imgH);

      // Rect de destination : ancré en bas-centre au point du pied.
      final dst = Rect.fromLTWH(footX - w / 2, footY - h, w, h);
      final src = Rect.fromLTWH(0, 0, imgW, imgH);

      // Clipper l'hexagone pour que les palmiers ne débordent pas à l'extérieur.
      canvas.save();
      final hexClip = Path()..moveTo(corners[0].dx, corners[0].dy);
      for (var i = 1; i < 6; i++) hexClip.lineTo(corners[i].dx, corners[i].dy);
      hexClip.close();
      canvas.clipPath(hexClip);

      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(255, 255, 255, alpha),
      );

      canvas.restore();
    }
  }

  List<Offset> _corners(Offset center, double radius) {
    return List.generate(6, (i) {
      final angleDeg = 60.0 * i - 90.0;
      final angleRad = angleDeg * pi / 180.0;
      return Offset(
        center.dx + radius * cos(angleRad),
        center.dy + radius * sin(angleRad),
      );
    });
  }

  @override
  bool shouldRepaint(covariant _HexTilePainter old) =>
      old.tile != tile ||
      old.highlighted != highlighted ||
      old.alpha != alpha ||
      old.imagesLoaded != imagesLoaded;
}

class _RemainingBadge extends StatelessWidget {
  const _RemainingBadge({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers,
              size: 12, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
          Text(
            '$remaining',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
