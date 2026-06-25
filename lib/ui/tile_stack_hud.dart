/// UI de la pile de tuiles (HUD) — Story 1.4b.
///
/// Affiche les 3 prochaines tuiles en disposition horizontale :
/// tuile active à gauche, suivantes empilées à droite (75% visibles).
library;

import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_cell.dart';
import '../game/hex_tile.dart';
import '../game/tile_component.dart' show BiomeColor;
import '../providers/placement_provider.dart';
import '../providers/tile_stack_provider.dart';

const double _kActiveTileRadius = 34.0;
const double _kUpcomingTileRadius = 26.0;
const double _kHudHexFlattenY = 1.0;

// ── Widget principal ─────────────────────────────────────────────────────────

class TileStackHud extends ConsumerWidget {
  const TileStackHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stackState = ref.watch(tileStackProvider);
    final placement = ref.watch(placementProvider);
    final visible = stackState.visible;

    if (visible.isEmpty) return const SizedBox.shrink();

    final activeTile = visible[0];
    final nextTiles = visible.length > 1 ? visible.sublist(1) : <HexTile>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5BA4D4).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF7EC8E3).withValues(alpha: 0.38),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tuile active à gauche
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _HexTilePreview(
                        tile: activeTile,
                        radius: _kActiveTileRadius,
                        highlighted: true,
                        dim: false,
                      ),
                      if (placement.hasSelection)
                        GestureDetector(
                          onTap: () => ref
                              .read(placementProvider.notifier)
                              .clearSelection(),
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
                    ],
                  ),
                  // Tuiles suivantes à droite, 75% visibles
                  if (nextTiles.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      width: _kUpcomingTileRadius * sqrt(3) * 0.75 + 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < nextTiles.length; i++) ...[
                            if (i > 0) const SizedBox(height: 4),
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.75,
                                child: _HexTilePreview(
                                  tile: nextTiles[i],
                                  radius: _kUpcomingTileRadius,
                                  highlighted: false,
                                  dim: true,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _RemainingBadge(remaining: stackState.remaining),
      ],
    );
  }
}

class _HexTilePreview extends StatelessWidget {
  const _HexTilePreview({
    required this.tile,
    required this.radius,
    required this.highlighted,
    required this.dim,
  });

  final HexTile tile;
  final double radius;
  final bool highlighted;
  final bool dim;

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
        ),
      ),
    );
  }
}

class _HexTilePainter extends CustomPainter {
  const _HexTilePainter({
    required this.tile,
    required this.highlighted,
    required this.alpha,
  });

  final HexTile tile;
  final bool highlighted;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2;
    final corners = _corners(center, radius);

    // Sixièmes colorés
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

    // Contour
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
      old.alpha != alpha;
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
