/// Composants de fond d'écran — ciel, soleil, nuages, océan.
///
/// Style low-poly / HD2D île paradisiaque. Rendu purement procédural via
/// Canvas. Ajouté au [FlameGame] avant la grille (priorité 0).
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

// ── Constantes ───────────────────────────────────────────────────────────────

/// Hauteur relative du ciel (0.0 = haut écran, 1.0 = horizon).
const double _kSkyHeightFraction = 0.78;

/// Hauteur relative de l'océan (de _kSkyHeightFraction à 1.0).
const double _kOceanTopFraction = 0.75;

/// Couleurs du ciel (haut → horizon).
const Color _kSkyTop = Color(0xFF4FC3F7);   // bleu ciel clair
const Color _kSkyMid = Color(0xFF81D4FA);   // bleu plus pâle
const Color _kSkyHorizon = Color(0xFFFFF3E0);// blanc/rose coucher

/// Couleurs de l'océan.
const Color _kOceanDeep = Color(0xFF00838F);   // turquoise foncé
const Color _kOceanLight = Color(0xFF26C6DA);  // turquoise clair
const Color _kOceanFoam = Color(0xFFB2EBF2);   // écume

/// Couleurs du soleil.
const Color _kSunColor = Color(0xFFFFF176);
const Color _kSunGlow = Color(0xFFFFF8E1);

/// Nombre de nuages.
const int _kCloudCount = 4;

// ── Composant ciel ───────────────────────────────────────────────────────────

/// Dessine le ciel dégradé + soleil + nuages + océan.
class BackgroundComponent extends PositionComponent {
  BackgroundComponent() : super(priority: 0);

  late final List<_Cloud> _clouds;
  double _time = 0;

  @override
  Future<void> onLoad() async {
    final rng = Random(42); // seed fixe pour reproductibilité
    _clouds = List.generate(_kCloudCount, (_) => _Cloud._random(rng));
  }

  @override
  void update(double dt) {
    _time += dt;
    for (final cloud in _clouds) {
      cloud.x += cloud.speed * dt;
      if (cloud.x > size.x + cloud.width) {
        cloud.x = -cloud.width;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final skyH = h * _kSkyHeightFraction;
    final oceanTop = h * _kOceanTopFraction;

    // ── Ciel dégradé ──────────────────────────────────────────────────────
    final skyRect = Rect.fromLTWH(0, 0, w, skyH);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, 0),
          Offset(0, skyH),
          [_kSkyTop, _kSkyMid, _kSkyHorizon],
          [0.0, 0.5, 1.0],
        ),
    );

    // ── Soleil (demi-cercle à l'horizon) ──────────────────────────────────
    final sunCenter = Offset(w * 0.75, skyH - 10);
    final sunRadius = w * 0.06;

    // Halo extérieur
    canvas.drawCircle(
      sunCenter,
      sunRadius * 2.5,
      Paint()
        ..shader = Gradient.radial(
          sunCenter,
          sunRadius * 2.5,
          [_kSunGlow.withValues(alpha: 0.4), _kSunGlow.withValues(alpha: 0.0)],
        ),
    );

    // Soleil (caché sous l'horizon = clip)
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, skyH));
    canvas.drawCircle(sunCenter, sunRadius, Paint()..color = _kSunColor);
    canvas.restore();

    // ── Nuages low-poly ───────────────────────────────────────────────────
    for (final cloud in _clouds) {
      _drawCloud(canvas, cloud);
    }

    // ── Océan turquoise ────────────────────────────────────────────────────
    final oceanRect = Rect.fromLTWH(0, oceanTop, w, h - oceanTop);
    canvas.drawRect(
      oceanRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, oceanTop),
          Offset(0, h),
          [_kOceanLight, _kOceanDeep],
        ),
    );

    // Ligne d'horizon (fine ligne claire)
    canvas.drawLine(
      Offset(0, oceanTop),
      Offset(w, oceanTop),
      Paint()
        ..color = _kOceanFoam.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );

    // ── Vagues animées ─────────────────────────────────────────────────────
    final wavePaint = Paint()
      ..color = _kOceanFoam.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var row = 0; row < 4; row++) {
      final baseY = oceanTop + 16 + row * 18;
      final path = Path();
      path.moveTo(0, baseY);
      for (var x = 0.0; x <= w; x += 4) {
        final y = baseY +
            sin((x / 30) + _time * 1.5 + row * 1.2) * 4 +
            sin((x / 50) + _time * 1.0 + row * 0.8) * 2;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, wavePaint..color = _kOceanFoam.withValues(alpha: 0.25 - row * 0.05));
    }
  }

  void _drawCloud(Canvas canvas, _Cloud cloud) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: cloud.alpha)
      ..style = PaintingStyle.fill;

    for (final blob in cloud.blobs) {
      canvas.drawCircle(
        Offset(cloud.x + blob.dx, cloud.y + blob.dy),
        blob.radius,
        paint,
      );
    }
  }
}

// ── Nuage ────────────────────────────────────────────────────────────────────

class _Cloud {
  _Cloud({
    required this.x,
    required this.y,
    required this.speed,
    required this.alpha,
    required this.width,
    required this.blobs,
  });

  double x;
  final double y;
  final double speed;
  final double alpha;
  final double width;
  final List<({double dx, double dy, double radius})> blobs;

  factory _Cloud._random(Random rng) {
    final cx = rng.nextDouble();
    final cy = rng.nextDouble() * 0.5;
    final count = 3 + rng.nextInt(2);
    final blobRadius = 12 + rng.nextDouble() * 16;

    final blobs = <({double dx, double dy, double radius})>[
      for (var i = 0; i < count; i++)
        (
          dx: (i - (count - 1) / 2) * blobRadius * 0.9,
          dy: rng.nextDouble() * blobRadius * 0.3,
          radius: blobRadius * (0.7 + rng.nextDouble() * 0.4),
        ),
    ];

    return _Cloud(
      x: cx,
      y: cy,
      speed: 3 + rng.nextDouble() * 5,
      alpha: 0.5 + rng.nextDouble() * 0.3,
      width: count * blobRadius * 1.2,
      blobs: blobs,
    );
  }
}
