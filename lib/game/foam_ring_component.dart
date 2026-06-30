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
      final pulse = lerpDouble(0.9, 1.1, breath)!;

      final length = blob.length * pulse;
      final width = blob.width * pulse;

      // On dessine un cercle dans un repère local, puis on l'écrase et
      // l'oriente le long de l'arête pour obtenir un trait fin (effet
      // écume/vague) au lieu d'un blob rond.
      canvas.save();
      canvas.translate(blob.center.dx, blob.center.dy);
      canvas.rotate(blob.angle);
      canvas.scale(length / width, 1.0);

      final paint = Paint()
        ..shader = Gradient.radial(
          Offset.zero,
          width,
          [
            Color.fromRGBO(255, 255, 255, alpha),
            Color.fromRGBO(255, 255, 255, alpha * 0.6),
            Color.fromRGBO(255, 255, 255, 0.0),
          ],
          [0.0, 0.55, 1.0],
        );

      canvas.drawCircle(Offset.zero, width, paint);
      canvas.restore();
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

    // Direction le long de l'arête (angle utilisé pour orienter les traits).
    final edgeAngle = atan2(edY, edX);

    // 5 traits d'écume par arête (au lieu de 3 blobs ronds).
    const int n = 5;
    for (int b = 0; b < n; b++) {
      final t = (b / (n - 1) - 0.5) * 0.75 * edLen;
      final outDist = (0.08 + rng.nextDouble() * 0.12) * hs;
      final latNoise = (rng.nextDouble() - 0.5) * 0.10 * edLen;
      final angleJitter = (rng.nextDouble() - 0.5) * 0.35; // léger zigzag

      final bx = midX + edX / edLen * t + outX * outDist + latNoise * edX / edLen;
      final by = midY + edY / edLen * t + outY * outDist + latNoise * edY / edLen;

      _blobs.add(_FoamBlob(
        center: Offset(bx, by),
        angle: edgeAngle + angleJitter,
        length: (0.16 + rng.nextDouble() * 0.10) * hs,
        width: (0.022 + rng.nextDouble() * 0.012) * hs,
        alphaMin: 0.18 + rng.nextDouble() * 0.10,
        alphaMax: 0.55 + rng.nextDouble() * 0.25,
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
    required this.angle,
    required this.length,
    required this.width,
    required this.alphaMin,
    required this.alphaMax,
    required this.speed,
    required this.phase,
  });

  final Offset center;
  final double angle;
  final double length;
  final double width;
  final double alphaMin;
  final double alphaMax;
  final double speed;
  final double phase;
}
