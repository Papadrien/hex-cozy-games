import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'hex_coords.dart';

import 'tile_component.dart'; // kIsoScaleY, kTileDepthPriorityBase

/// Dessine une écume animée sur les arêtes extérieures du plateau hexagonal.
///
/// Pour chaque arête sans voisin occupé, on génère N blobs d'écume positionnés
/// autour du milieu de cette arête. Chaque blob a sa propre phase d'animation
/// (opacité qui respire) pour désynchroniser le clignotement.
///
/// [refresh] doit être appelé après chaque placement/suppression de tuile.
/// [updateLayout] doit être appelé après chaque changement de zoom/caméra.
class FoamRingComponent extends PositionComponent {
  FoamRingComponent();

  // Blobs d'écume stockés en coordonnées pixel (monde Flame).
  final List<_FoamBlob> _blobs = [];

  double _time = 0.0;

  // Priorité : juste en dessous des tuiles (qui commencent à kTileDepthPriorityBase + Y).
  // On met -1 pour être sous toutes les tuiles mais au-dessus du fond.
  @override
  int get priority => kTileDepthPriorityBase - 1;

  // ── API publique ─────────────────────────────────────────────────────────

  /// Recalcule les blobs à partir des tuiles posées + layout courant.
  void refresh(Map<HexCoords, dynamic> placedTiles, HexLayout layout) {
    _blobs.clear();
    final rng = Random(42); // seed fixe → positions reproductibles

    for (final coords in placedTiles.keys) {
      for (int side = 0; side < 6; side++) {
        if (!placedTiles.containsKey(coords.neighbor(side))) {
          _addBlobsOnEdge(coords, side, layout, rng);
        }
      }
    }
  }

  // ── Flame lifecycle ──────────────────────────────────────────────────────

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    for (final blob in _blobs) {
      final breath = (sin(_time * blob.speed + blob.phase) + 1.0) / 2.0;
      final alpha = lerpDouble(blob.alphaMin, blob.alphaMax, breath)!;
      final r = blob.radius * lerpDouble(0.85, 1.15, breath)!;

      final paint = Paint()
        ..shader = Gradient.radial(
          blob.center,
          r,
          [Color.fromRGBO(255, 255, 255, alpha), Color.fromRGBO(255, 255, 255, 0.0)],
        );

      canvas.drawCircle(blob.center, r, paint);
    }
  }

  // ── Génération des blobs ─────────────────────────────────────────────────

  void _addBlobsOnEdge(
      HexCoords coords, int side, HexLayout layout, Random rng) {
    // Centre de la cellule en pixels.
    final cp = layout.hexToPixel(coords, isoScaleY: kIsoScaleY);
    final cx = cp.x;
    final cy = cp.y;
    final hs = layout.hexSize;

    // Coins [side] et [side+1] de l'hexagone (pointy-top, iso).
    final c0 = _corner(cx, cy, hs, side);
    final c1 = _corner(cx, cy, hs, (side + 1) % 6);

    // Milieu de l'arête.
    final midX = (c0.dx + c1.dx) / 2;
    final midY = (c0.dy + c1.dy) / 2;

    // Vecteur de l'arête et sa longueur.
    final edX = c1.dx - c0.dx;
    final edY = c1.dy - c0.dy;
    final edLen = sqrt(edX * edX + edY * edY);

    // Normale sortante (perpendiculaire, vers l'extérieur).
    // Rotation 90° sens horaire : (edY, -edX).
    final outX = edY / edLen;
    final outY = -edX / edLen;

    // 3 blobs par arête.
    const int n = 3;
    for (int b = 0; b < n; b++) {
      final t = (b / (n - 1) - 0.5) * 0.65 * edLen;
      final outDist = (0.10 + rng.nextDouble() * 0.14) * hs;
      final latNoise = (rng.nextDouble() - 0.5) * 0.12 * edLen;

      final bx = midX + edX / edLen * t + outX * outDist + latNoise * edX / edLen;
      final by = midY + edY / edLen * t + outY * outDist + latNoise * edY / edLen;

      _blobs.add(_FoamBlob(
        center: Offset(bx, by),
        radius: (0.10 + rng.nextDouble() * 0.08) * hs,
        alphaMin: 0.05 + rng.nextDouble() * 0.07,
        alphaMax: 0.30 + rng.nextDouble() * 0.22,
        speed: 0.7 + rng.nextDouble() * 1.3,
        phase: rng.nextDouble() * 2 * pi,
      ));
    }
  }

  /// Coin [i] de l'hexagone (pointy-top, projection iso).
  Offset _corner(double cx, double cy, double hs, int i) {
    final angleDeg = 60.0 * i - 90.0;
    final angleRad = angleDeg * pi / 180.0;
    return Offset(cx + hs * cos(angleRad), cy + hs * sin(angleRad) * kIsoScaleY);
  }
}

class _FoamBlob {
  const _FoamBlob({
    required this.center,
    required this.radius,
    required this.alphaMin,
    required this.alphaMax,
    required this.speed,
    required this.phase,
  });

  final Offset center;
  final double radius;
  final double alphaMin;
  final double alphaMax;
  final double speed;
  final double phase;
}
