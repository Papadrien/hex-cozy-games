/// Composant Flame pour le rendu d'une tuile hexagonale colorée — Story 1.3.
///
/// Rendu : chaque côté i est un trapèze allant du centre de l'hexagone vers
/// les deux sommets qui encadrent ce côté.
///
/// Projection isométrique : les coins sont calculés en espace "monde plat"
/// puis la coordonnée Y est multipliée par [kIsoScaleY] avant dessin.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/constants.dart';
import 'hex_cell.dart';
import 'hex_coords.dart';
import 'hex_tile.dart';

/// Facteur d'écrasement vertical isométrique.
const double kIsoScaleY = 0.57;

/// Durée de l'effet de glow sur les côtés connectés.
const double kGlowDurationSec = 0.6;

/// Opacité initiale du glow.
const double kGlowStartAlpha = 0.45;

/// Correspondance [BiomeType] → couleur d'affichage.
extension BiomeColor on BiomeType {
  Color get color {
    switch (this) {
      case BiomeType.forest:
        return const Color(0xFF43A047);
      case BiomeType.village:
        return const Color(0xFFE53935);
      case BiomeType.plain:
        return const Color(0xFFFFD600);
      case BiomeType.water:
        return const Color(0xFF1E88E5);
      case BiomeType.mountain:
        return const Color(0xFF8E24AA);
    }
  }
}

/// Épaisseur de base du "bloc" 3D des tuiles (à zoom 1.0).
const double kTileDepth = 10.0;

// ── Ondulation animée de la ligne basse du relief 3D ────────────────────────
// Donne l'impression que le pied de la tuile "trempe" légèrement dans l'eau.

/// Amplitude de l'ondulation (à zoom 1.0), en pixels.
const double kEdgeWaveAmplitude = 1.6;

/// Nombre d'oscillations le long de chaque arête.
const double kEdgeWaveFrequency = 1.5;

/// Vitesse d'animation de l'ondulation (rad/s).
const double kEdgeWaveSpeed = 1.3;

/// Nombre de segments utilisés pour dessiner la ligne ondulée.
const int kEdgeWaveSegments = 8;

const int kTileDepthPriorityBase = 100000;
const int kTileDepthPriorityPreview = kTileDepthPriorityBase + 1000000;

class TileComponent extends PositionComponent {
  TileComponent({
    required this.tile,
    required this._coords,
    double hexSize = kHexSize,
    this._alpha = 1.0,
    this.highlightedSides = const {},
    Vector2? position,
    double initialWaveIntensity = 1.0,
  })  : _hexSize = hexSize,
        _waveIntensity = initialWaveIntensity.clamp(0.0, 1.0),
        super(
          position: position ?? Vector2.zero(),
          anchor: Anchor.center,
          size: Vector2(sqrt(3) * hexSize, 2 * hexSize * kIsoScaleY),
          priority: 1,
        );

  HexTile tile;

  final HexCoords _coords;
  HexCoords get coords => _coords;

  /// Décalage de phase propre à cette tuile (basé sur ses coordonnées) pour
  /// que les tuiles n'ondulent pas toutes de façon parfaitement synchrone.
  late final double _wavePhaseOffset =
      (_coords.q * 0.73 + _coords.r * 1.31).abs() % (2 * pi);

  double _waveTime = 0.0;

  // ── Ondulation progressive ────────────────────────────────────────────────
  // L'intensité de l'ondulation (0 → 1) permet de la garder invisible en
  // prévisualisation et de la faire apparaître progressivement une fois la
  // tuile posée (voir [startWaveRampIn]).
  double _waveIntensity;
  bool _waveRampActive = false;
  double _waveRampSpeed = 0.0;

  /// Démarre la montée en puissance progressive de l'ondulation du bord bas,
  /// de 0 jusqu'à son intensité maximale, sur [duration] secondes.
  void startWaveRampIn({double duration = 0.5}) {
    _waveIntensity = 0.0;
    _waveRampActive = true;
    _waveRampSpeed = duration > 0 ? 1.0 / duration : double.infinity;
  }

  // ── Animation de rotation ────────────────────────────────────────────────
  // Décalage angulaire "monde plat" (avant projection iso) appliqué à
  // l'ensemble du rendu pour simuler une rotation fluide de la tuile lors
  // d'un changement de côté en prévisualisation (voir [animateRotationSwirl]).
  double _rotationVisualOffset = 0.0;
  double _rotationAnimFrom = 0.0;
  double _rotationAnimElapsed = 0.0;
  double _rotationAnimDuration = 0.22;
  bool _rotationAnimating = false;

  /// Déclenche une rotation visuelle fluide de [steps] crans de 60° (positif
  /// ou négatif) vers l'orientation actuelle de [tile]. À appeler juste après
  /// avoir mis à jour [tile] avec la nouvelle orientation : le rendu part
  /// visuellement de l'ancienne orientation puis pivote jusqu'à la nouvelle.
  void animateRotationSwirl(int steps, {double duration = 0.22}) {
    if (steps == 0) return;
    _rotationAnimFrom = steps * (pi / 3);
    _rotationVisualOffset = _rotationAnimFrom;
    _rotationAnimElapsed = 0.0;
    _rotationAnimDuration = duration;
    _rotationAnimating = true;
  }

  double _hexSize;
  double get hexSize => _hexSize;
  set hexSize(double value) {
    _hexSize = value;
    size = Vector2(sqrt(3) * value, 2 * value * kIsoScaleY);
  }

  void updateDepthPriority() {
    priority = kTileDepthPriorityBase + position.y.round();
  }

  /// Épaisseur du bloc 3D proportionnelle au zoom courant.
  double get _tileDepth => kTileDepth * (_hexSize / kHexSize);

  /// Amplitude de l'ondulation proportionnelle au zoom courant et à
  /// l'intensité progressive courante (0 en prévisualisation ou juste après
  /// la pose, jusqu'à sa valeur pleine une fois [startWaveRampIn] terminé).
  double get _waveAmplitude =>
      kEdgeWaveAmplitude * (_hexSize / kHexSize) * _waveIntensity;

  double _alpha;
  double get alpha => _alpha;
  set alpha(double value) {
    _alpha = value.clamp(0.0, 1.0);
  }

  Set<int> highlightedSides;

  // ── Glow ─────────────────────────────────────────────────────────────────
  Set<int>? _glowSides;
  double _glowAlpha = 0.0;

  void startGlow(List<int> sides) {
    _glowSides = sides.toSet();
    _glowAlpha = kGlowStartAlpha;
  }

  // ── Rendu Canvas (hexagone coloré + effet 3D) ─────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cyTop = size.y / 2 - _tileDepth / 2;
    var topCorners = _isoCorners(cx, cyTop);

    // Rotation visuelle : on "dé-écrase" temporairement l'axe Y (annule
    // kIsoScaleY) pour tourner chaque coin de la face du dessus dans cet
    // espace "monde plat" non déformé, puis on ré-applique l'écrasement iso.
    // On ne transforme QUE les coins du dessus (pas tout le canvas) : si on
    // transformait tout le rendu, l'extrusion verticale du bloc (ajoutée en
    // coordonnées locales après coup, voir _renderTile) se retrouverait elle
    // aussi tournée/désécrasée, ce qui fait pencher visuellement la tuile
    // sur le côté pendant l'animation. En ne tournant que la face du dessus,
    // l'extrusion reste purement verticale à l'écran et la tuile reste
    // horizontale pendant toute la rotation.
    final hasRotationOffset = _rotationVisualOffset.abs() > 0.0001;
    if (hasRotationOffset) {
      final pivot = Offset(cx, cyTop);
      topCorners = [
        for (final corner in topCorners)
          _rotateAroundPivot(corner, pivot, _rotationVisualOffset),
      ];
    }

    _renderTile(canvas, cx, cyTop, topCorners);
  }

  /// Fait pivoter [point] autour de [pivot] d'un angle [angle] (radians),
  /// dans l'espace "monde plat" (annule puis réapplique kIsoScaleY), pour
  /// simuler une rotation à plat correcte malgré la projection iso.
  Offset _rotateAroundPivot(Offset point, Offset pivot, double angle) {
    final dx = point.dx - pivot.dx;
    var dy = (point.dy - pivot.dy) / kIsoScaleY;
    final cosA = cos(angle);
    final sinA = sin(angle);
    final rx = dx * cosA - dy * sinA;
    final ry = dx * sinA + dy * cosA;
    dy = ry * kIsoScaleY;
    return Offset(pivot.dx + rx, pivot.dy + dy);
  }

  void _renderTile(Canvas canvas, double cx, double cyTop, List<Offset> topCorners) {

    // ── Faces latérales (effet bloc 3D) ──────────────────────────────────
    for (var i = 0; i < 6; i++) {
      final t0 = topCorners[i];
      final t1 = topCorners[(i + 1) % 6];
      final midY = (t0.dy + t1.dy) / 2;
      if (midY < cyTop - 0.01) continue;

      final b0 = Offset(t0.dx, t0.dy + _tileDepth);
      final b1 = Offset(t1.dx, t1.dy + _tileDepth);

      // Ligne basse ondulée (b1 → b0) : les extrémités restent fixes sur les
      // coins pour garder une silhouette fermée, l'ondulation est maximale
      // au milieu de l'arête (effet "trempé dans l'eau").
      final wavyBottom = _wavyEdge(b1, b0, _wavePhaseOffset + i * 0.9);

      final sidePath = Path()
        ..moveTo(t0.dx, t0.dy)
        ..lineTo(t1.dx, t1.dy);
      for (final p in wavyBottom) {
        sidePath.lineTo(p.dx, p.dy);
      }
      sidePath.close();

      final baseColor = tile.sides[i].color;
      final shaded = Color.from(
        alpha: baseColor.a,
        red: baseColor.r * 0.62,
        green: baseColor.g * 0.62,
        blue: baseColor.b * 0.62,
      );

      canvas.drawPath(
        sidePath,
        Paint()
          ..color = shaded.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );

      // Ligne blanche sur l'ondulation du bord bas — uniquement sur les
      // côtés bas-gauche (i == 3) et bas-droit (i == 2), pas sur les côtés
      // gauche/droit (i == 4 / i == 1).
      if (_waveIntensity > 0.01 && (i == 2 || i == 3)) {
        final wavePath = Path();
        for (var s = 0; s < wavyBottom.length; s++) {
          if (s == 0) {
            wavePath.moveTo(wavyBottom[s].dx, wavyBottom[s].dy);
          } else {
            wavePath.lineTo(wavyBottom[s].dx, wavyBottom[s].dy);
          }
        }
        canvas.drawPath(
          wavePath,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: _alpha * 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // ── Face du dessus ────────────────────────────────────────────────────
    for (var i = 0; i < 6; i++) {
      final c0 = topCorners[i];
      final c1 = topCorners[(i + 1) % 6];

      final path = Path()
        ..moveTo(cx, cyTop)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = tile.sides[i].color.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );

      // Glow.
      if (_glowSides != null && _glowSides!.contains(i) && _glowAlpha > 0.01) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: _glowAlpha)
            ..style = PaintingStyle.fill,
        );
      }

      // Surbrillance côtés connectés.
      if (highlightedSides.contains(i)) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.20)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // ── Polygone central du biome majoritaire ────────────────────────────
    final dominantColor = _dominantBiomeColor();
    if (dominantColor != null) {
      const double innerRatio = 0.32;
      final innerCx = cx;
      final innerCy = cyTop;
      final innerPath = Path();
      for (var i = 0; i < 6; i++) {
        final angleDeg = 60.0 * i - 90.0;
        final angleRad = angleDeg * pi / 180.0;
        final x = innerCx + _hexSize * innerRatio * cos(angleRad);
        final y = innerCy + _hexSize * innerRatio * sin(angleRad) * kIsoScaleY;
        if (i == 0) {
          innerPath.moveTo(x, y);
        } else {
          innerPath.lineTo(x, y);
        }
      }
      innerPath.close();
      canvas.drawPath(
        innerPath,
        Paint()
          ..color = dominantColor.withValues(alpha: _alpha)
          ..style = PaintingStyle.fill,
      );
    }

  }

  /// Retourne la couleur du biome majoritaire sur la tuile, ou null en cas
  /// d'égalité.
  Color? _dominantBiomeColor() {
    final counts = <BiomeType, int>{};
    for (final b in tile.sides) {
      counts[b] = (counts[b] ?? 0) + 1;
    }
    BiomeType? dominant;
    int maxCount = 0;
    bool tie = false;
    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominant = entry.key;
        tie = false;
      } else if (entry.value == maxCount) {
        tie = true;
      }
    }
    if (dominant == null || tie) return null;
    return dominant.color;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _waveTime += dt;

    if (_waveRampActive) {
      _waveIntensity += _waveRampSpeed * dt;
      if (_waveIntensity >= 1.0) {
        _waveIntensity = 1.0;
        _waveRampActive = false;
      }
    }

    if (_rotationAnimating) {
      _rotationAnimElapsed += dt;
      final t = (_rotationAnimElapsed / _rotationAnimDuration).clamp(0.0, 1.0);
      // Ease-out cubique : rotation rapide au départ puis ralentie, pour un
      // rendu "à la main" plutôt que linéaire/mécanique.
      final eased = 1 - pow(1 - t, 3).toDouble();
      _rotationVisualOffset = _rotationAnimFrom * (1 - eased);
      if (t >= 1.0) {
        _rotationVisualOffset = 0.0;
        _rotationAnimating = false;
      }
    }

    if (_glowSides != null && _glowAlpha > 0.01) {
      _glowAlpha -= (kGlowStartAlpha / kGlowDurationSec) * dt;
      if (_glowAlpha <= 0.01) {
        _glowAlpha = 0.0;
        _glowSides = null;
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Génère les points d'une arête ondulée entre [from] et [to].
  ///
  /// Les extrémités gardent un décalage nul (enveloppe en sinus) afin que
  /// l'arête reste parfaitement raccordée aux coins de l'hexagone — seul le
  /// milieu de l'arête ondule, comme une petite vague le long du pied de
  /// la tuile.
  List<Offset> _wavyEdge(Offset from, Offset to, double phase) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final points = <Offset>[];
    for (var s = 0; s <= kEdgeWaveSegments; s++) {
      final t = s / kEdgeWaveSegments;
      final baseX = from.dx + dx * t;
      final baseY = from.dy + dy * t;
      final envelope = sin(pi * t); // 0 aux extrémités, 1 au centre
      final wave = _waveAmplitude *
          envelope *
          sin(kEdgeWaveFrequency * 2 * pi * t + phase + _waveTime * kEdgeWaveSpeed);
      points.add(Offset(baseX, baseY + wave));
    }
    return points;
  }

  List<Offset> _isoCorners(double cx, double cy) {
    return List.generate(6, (i) {
      final angleDeg = 60.0 * i - 90.0;
      final angleRad = angleDeg * pi / 180.0;
      final x = cx + _hexSize * cos(angleRad);
      final y = cy + _hexSize * sin(angleRad) * kIsoScaleY;
      return Offset(x, y);
    });
  }
}
