/// Mixin partagé entre [SailboatComponent] et [FishingBoatComponent] pour la
/// logique commune de rendu du sillage en V à l'arrière des bateaux.
///
/// Ce mixin centralise :
///  - Les constantes de configuration du sillage (angle d'écartement,
///    longueur, ondulation, etc.)
///  - Les méthodes de calcul des branches du sillage
///
/// Les composants utilisateurs doivent définir :
///  - `sternFrac` : position normalisée de la poupe (0..1)
///  - `bowFrac` : position normalisée de la proue (0..1)
///  - `wakeIntensity` : intensité courante (0..1)
///  - `wakeTime` : temps écoulé pour l'animation de l'ondulation
///  - `size` : taille courante du sprite (héritée de [SpriteComponent])
///  - `_baseWidthForStroke` : largeur de référence pour l'épaisseur du trait
library;

import 'dart:math' show pi, pow, sin, cos;
import 'dart:ui' show Color, Offset, Paint, PaintingStyle, Path, StrokeCap;

import 'package:flame/components.dart';

import 'tile_component.dart' show kEdgeWaveFrequency, kEdgeWaveSpeed;

/// Mixin de sillage pour les composants bateau.
mixin WakeMixin on SpriteComponent {
  /// Angle (radians) d'écartement de chaque branche du sillage par rapport
  /// à l'axe arrière, à son extrémité.
  static const double kWakeSpreadAngle = 8 * pi / 180;

  /// Exposant appliqué à `t` (progression 0..1 le long d'une branche) pour
  /// façonner l'écartement.
  static const double kWakeWidenExponent = 0.65;

  /// Longueur du sillage, en multiple de la distance poupe→proue.
  static const double kWakeLengthFraction = 1.2;

  /// Amplitude de l'ondulation du sillage, en fraction de la distance
  /// poupe→proue.
  static const double kWakeRippleFraction = 0.035;

  /// Nombre de segments de chaque branche du sillage.
  static const int kWakeSegments = 24;

  /// Position normalisée de la poupe (0..1). Doit être implémentée par le
  /// composant.
  Offset get sternFrac;

  /// Position normalisée de la proue (0..1). Doit être implémentée par le
  /// composant.
  Offset get bowFrac;

  /// Intensité du sillage (0..1). Doit être gérée par le composant.
  double get wakeIntensity;

  /// Temps écoulé pour l'animation de l'ondulation. Doit être gérée par
  /// le composant.
  double get wakeTime;

/// Construit les deux branches du sillage en V partant de la proue et
  /// enveloppant la coque vers l'arrière, et détermine laquelle passe
  /// derrière la coque (dessinée avant le sprite) et laquelle passe devant.
  ///
  /// Renvoie `null` si le sillage est invisible ou si poupe/proue coïncident.
  ({Path behind, Path front, Paint paint})? wakeRenderPlan() {
    if (wakeIntensity <= 0.001) return null;

    final sternPx = Offset(sternFrac.dx * size.x, sternFrac.dy * size.y);
    final bowPx = Offset(bowFrac.dx * size.x, bowFrac.dy * size.y);
    final bowToStern = sternPx - bowPx;
    final bowToSternLength = bowToStern.distance;
    if (bowToSternLength < 0.001) return null;
    final backward = bowToStern / bowToSternLength;

    // La longueur rétroécit légèrement en plus de l'estompage (alpha).
    final length = bowToSternLength *
        kWakeLengthFraction *
        (0.3 + 0.7 * wakeIntensity);
    final rippleAmplitude = bowToSternLength * kWakeRippleFraction;
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * wakeIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    // Origine à la proue (pas la poupe).
    Path pathForSide(double side) => wakeLinePath(
          origin: bowPx,
          backward: backward,
          length: length,
          spreadAngle: kWakeSpreadAngle * side,
          rippleAmplitude: rippleAmplitude,
          // Légèrement déphasées entre les deux branches.
          phase: side > 0 ? 0.0 : pi,
        );

    // Composante Y de la direction de chaque branche à mi-longueur.
    double dirYForSide(double side) {
      final angle = kWakeSpreadAngle *
          side *
          pow(0.5, kWakeWidenExponent).toDouble();
      return backward.dx * sin(angle) + backward.dy * cos(angle);
    }

    final pathPositiveSide = pathForSide(1.0);
    final pathNegativeSide = pathForSide(-1.0);
    // La branche avec la plus petite composante Y est la plus "haute" à
    // l'écran (Y croît vers le bas) à c'est elle qui passe derrière la
    // coque.
    final positiveSideIsBehind = dirYForSide(1.0) < dirYForSide(-1.0);

    return (
      behind: positiveSideIsBehind ? pathPositiveSide : pathNegativeSide,
      front: positiveSideIsBehind ? pathNegativeSide : pathPositiveSide,
      paint: paint,
    );
  }

  /// Construit une branche du sillage : part de [origin] (la proue) selon
  /// [backward] (unitaire), s'écarte progressivement jusqu'à
  /// [spreadAngle] à son extrémité, avec une ondulation perpendiculaire
  /// croissante animée par [wakeTime].
  Path wakeLinePath({
    required Offset origin,
    required Offset backward,
    required double length,
    required double spreadAngle,
    required double rippleAmplitude,
    required double phase,
  }) {
    final perp = Offset(-backward.dy, backward.dx);
    final path = Path()..moveTo(origin.dx, origin.dy);
    for (var s = 1; s <= kWakeSegments; s++) {
      final t = s / kWakeSegments;
      final angle = spreadAngle * pow(t, kWakeWidenExponent);
      final cosA = cos(angle);
      final sinA = sin(angle);
      final dirX = backward.dx * cosA - backward.dy * sinA;
      final dirY = backward.dx * sinA + backward.dy * cosA;
      final dist = length * t;
      final ripple = rippleAmplitude *
          t *
          sin(kEdgeWaveFrequency * 2 * pi * t +
              phase +
              wakeTime * kEdgeWaveSpeed);
      path.lineTo(
        origin.dx + dirX * dist + perp.dx * ripple,
        origin.dy + dirY * dist + perp.dy * ripple,
      );
    }
    return path;
  }
}
