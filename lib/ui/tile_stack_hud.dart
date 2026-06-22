/// UI de la pile de tuiles (HUD) — Story 1.4b.
///
/// Affiche les 3 prochaines tuiles ([tileStackProvider]) en haut à droite de
/// l'écran de jeu, sous le bouton Pause (story 1.5bis-a).
///
/// Référence (contexte 7.4 / 7.5) : esprit Dorfromantik PC — badge compact,
/// sobre, sans cadre lourd, qui flotte sur la vue du plateau. Taille des
/// tuiles doublée par rapport à un badge HUD standard pour que les 2-3
/// couleurs/biomes restent lisibles à cette échelle.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_cell.dart';
import '../game/hex_tile.dart';
import '../game/tile_component.dart' show BiomeColor, kIsoScaleY;
import '../providers/placement_provider.dart';
import '../providers/tile_stack_provider.dart';

/// Rayon (centre → sommet) de la tuile active dans la pile, en px logiques.
/// "Taille doublée par rapport à un badge HUD standard" (contexte 7.5) — un
/// badge standard ferait ~16-18px de rayon ; on double donc vers ~34px pour
/// la tuile active, les suivantes étant légèrement plus petites en retrait.
const double _kActiveTileRadius = 34.0;
const double _kUpcomingTileRadius = 26.0;

/// Écrasement vertical de l'aperçu hex dans le HUD (projection isométrique,
/// identique à celle du plateau pour une cohérence visuelle).
const double _kHudHexFlattenY = kIsoScaleY;

class TileStackHud extends ConsumerWidget {
  const TileStackHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stackState = ref.watch(tileStackProvider);
    final placement = ref.watch(placementProvider);
    final visible = stackState.visible;

    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Pile : tuile active devant, les suivantes en arc derrière ──────
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
                  totalVisible: visible.length,
                ),
              if (placement.hasSelection)
                Center(
                  child: GestureDetector(
                    onTap: () => ref.read(placementProvider.notifier).clearSelection(),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.white70),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // ── Stock restant ───────────────────────────────────────────────────
        _RemainingBadge(remaining: stackState.remaining),
      ],
    );
  }
}

/// Une tuile positionnée dans la pile visuelle.
///
/// [indexInStack] == 0 → tuile active (premier plan, légèrement plus grande).
/// Les tuiles suivantes sont distribuées en arc contigu multi-couleur derrière,
/// décalées vers le haut-gauche pour rester visibles sans se superposer
/// totalement (validé sur wireframe).
class _StackedTile extends StatelessWidget {
  const _StackedTile({
    required this.tile,
    required this.indexInStack,
    required this.totalVisible,
  });

  final HexTile tile;
  final int indexInStack;
  final int totalVisible;

  bool get _isActive => indexInStack == 0;

  @override
  Widget build(BuildContext context) {
    final radius = _isActive ? _kActiveTileRadius : _kUpcomingTileRadius;

    // Décalage en arc : chaque tuile suivante se décale vers le haut-gauche.
    final step = indexInStack.toDouble();
    final dx = -step * (_kUpcomingTileRadius * 0.62);
    final dy = -step * (_kUpcomingTileRadius * 0.46);

    return Positioned(
      // Les tuiles derrière (index plus grand) sont dessinées en premier
      // (boucle décroissante dans le parent), donc l'active finit au-dessus.
      left: null,
      right: null,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: _HexTilePreview(
          tile: tile,
          radius: radius,
          // La tuile active a une bordure distincte (identification claire).
          highlighted: _isActive,
          // Les tuiles derrière sont légèrement assombries pour creuser la
          // profondeur de la pile sans nuire à la lisibilité des couleurs.
          dim: !_isActive,
        ),
      ),
    );
  }
}

/// Mini-rendu hexagonal "à plat" d'une tuile (sans projection iso plateau).
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
  _HexTilePainter({
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

    // Décoration selon le biome dominant.
    _drawHudDecoration(canvas, center, radius);

    // Contour sobre — discret pour les tuiles en attente, un peu plus marqué
    // (avec halo clair) pour la tuile active afin de l'identifier clairement.
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

  void _drawHudDecoration(Canvas canvas, Offset center, double radius) {
    final counts = <BiomeType, int>{};
    for (final side in tile.sides) {
      counts[side] = (counts[side] ?? 0) + 1;
    }
    final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final seed = Object.hashAll(tile.sides);
    final rng = Random(seed);
    final s = radius / 24;

    switch (dominant) {
      case BiomeType.plain:
        if (rng.nextDouble() < 0.3) {
          _drawHudPalm(canvas, center.dx, center.dy, s, rng);
        }
      case BiomeType.flowerField:
        for (var i = 0; i < 3; i++) {
          final fx = center.dx + (rng.nextDouble() - 0.5) * 8 * s;
          final fy = center.dy + (rng.nextDouble() - 0.5) * 5 * s;
          final r = (1.5 + rng.nextDouble() * 1.5) * s;
          canvas.drawCircle(Offset(fx, fy), r,
              Paint()..color = const Color(0xFFF48FB1).withValues(alpha: 0.7));
          canvas.drawCircle(Offset(fx, fy), r * 0.5,
              Paint()..color = const Color(0xFFFFF176));
        }
      case BiomeType.forest:
        final count = 2 + rng.nextInt(2);
        for (var i = 0; i < count; i++) {
          _drawHudPalm(canvas, center.dx, center.dy, s * 0.6, rng);
        }
      case BiomeType.mountain:
        _drawHudRock(canvas, center.dx, center.dy, s * 0.5, rng);
      case BiomeType.beach:
        if (rng.nextDouble() < 0.3) {
          _drawHudRock(canvas, center.dx, center.dy, s * 0.3, rng);
        }
      case BiomeType.water:
        final ripple = Path()
          ..addOval(Rect.fromCenter(
              center: center, width: 4 * s, height: 1.5 * s));
        canvas.drawPath(
          ripple,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      case BiomeType.village:
        _drawHudHouse(canvas, center.dx, center.dy, s * 0.6, rng);
    }
  }

  void _drawHudPalm(Canvas canvas, double cx, double cy, double s, Random rng) {
    final baseX = cx + (rng.nextDouble() - 0.5) * 6 * s;
    final baseY = cy + (rng.nextDouble() - 0.5) * 4 * s;
    final h = 6 * s;
    final trunk = Path()
      ..moveTo(baseX - 1 * s, baseY)
      ..quadraticBezierTo(baseX + 0.5 * s, baseY - h * 0.5, baseX - 0.5 * s, baseY - h);
    canvas.drawPath(
      trunk,
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s,
    );
    for (var i = 0; i < 2; i++) {
      final angle = rng.nextDouble() * pi * 0.6 - pi * 0.3 - pi / 2;
      final len = (3 + rng.nextDouble() * 3) * s;
      final leaf = Path()
        ..moveTo(baseX - 0.5 * s, baseY - h)
        ..quadraticBezierTo(
          baseX - 0.5 * s + cos(angle) * len * 0.5,
          baseY - h + sin(angle) * len * 0.5,
          baseX - 0.5 * s + cos(angle) * len,
          baseY - h + sin(angle) * len,
        );
      canvas.drawPath(
        leaf,
        Paint()
          ..color = const Color(0xFF4CAF50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * s,
      );
    }
  }

  void _drawHudRock(Canvas canvas, double cx, double cy, double s, Random rng) {
    final vertices = 4 + rng.nextInt(3);
    final rockPath = Path();
    for (var i = 0; i < vertices; i++) {
      final angle = 2 * pi * i / vertices + (rng.nextDouble() - 0.5) * 0.4;
      final r = (1.5 + rng.nextDouble() * 2) * s;
      final x = cx + cos(angle) * r;
      final y = cy + sin(angle) * r * 0.7;
      if (i == 0) { rockPath.moveTo(x, y); } else { rockPath.lineTo(x, y); }
    }
    rockPath.close();
    canvas.drawPath(rockPath, Paint()..color = const Color(0xFF616161));
    final highPath = Path();
    for (var i = 0; i < vertices; i++) {
      final angle = 2 * pi * i / vertices + (rng.nextDouble() - 0.5) * 0.4;
      final r = (1 + rng.nextDouble() * 1.5) * s;
      final x = cx + cos(angle) * r - 0.5 * s;
      final y = cy + sin(angle) * r * 0.7 - 0.5 * s;
      if (i == 0) { highPath.moveTo(x, y); } else { highPath.lineTo(x, y); }
    }
    highPath.close();
    canvas.drawPath(highPath, Paint()..color = const Color(0xFF9E9E9E));
  }

  void _drawHudHouse(Canvas canvas, double cx, double cy, double s, Random rng) {
    final hx2 = cx + (rng.nextDouble() - 0.5) * 6 * s;
    final hy = cy + 2 * s;
    for (var i = -1; i <= 1; i += 1) {
      canvas.drawLine(
        Offset(hx2 + i * 2 * s, hy), Offset(hx2 + i * 2 * s, hy - 5 * s),
        Paint()..color = const Color(0xFF5D4037)..strokeWidth = 1.0 * s,
      );
    }
    canvas.drawRect(
      Rect.fromCenter(center: Offset(hx2, hy - 5 * s), width: 8 * s, height: 1.5 * s),
      Paint()..color = const Color(0xFF8D6E63),
    );
    final roof = Path()
      ..moveTo(hx2 - 5 * s, hy - 6 * s)
      ..lineTo(hx2, hy - 11 * s)
      ..lineTo(hx2 + 5 * s, hy - 6 * s)
      ..close();
    canvas.drawPath(
      roof,
      Paint()..color = const Color(0xFFD84315).withValues(alpha: 0.8),
    );
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
  bool shouldRepaint(covariant _HexTilePainter oldDelegate) {
    return oldDelegate.tile != tile ||
        oldDelegate.highlighted != highlighted ||
        oldDelegate.alpha != alpha;
  }
}

/// Badge sobre affichant le nombre de tuiles restantes dans la pile.
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
          Icon(Icons.layers, size: 12, color: Colors.white.withValues(alpha: 0.85)),
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
