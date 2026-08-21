/// Avion décoratif traversant l'écran — easter egg purement visuel, sans
/// impact sur le jeu, déclenché après un certain nombre de tuiles posées
/// (voir [HexBoardGame.kPlaneTriggerTileCount]).
///
/// Contrairement au voilier ([SailboatComponent], deux trajets avec pause et
/// demi-tour), l'avion effectue un unique trajet rectiligne du quart
/// haut-droit de l'écran vers le bas-gauche, en ligne droite.
///
/// Le sprite `plane.png` a son cap naturellement orienté vers le bas-gauche
/// dans l'image source (nez/hélice en bas-gauche, queue/dérive en
/// haut-droite) — voir [_kHeadingAngle], mesuré directement sur l'image
/// (1536×1024) entre le centre du capot moteur (≈441, 651) et la roulette de
/// queue (≈1116, 355), soit environ 23.7° sous l'horizontale. Ce cap
/// correspond déjà exactement au sens du trajet (haut-droit → bas-gauche) :
/// aucune rotation ni symétrie n'est nécessaire, contrairement au voilier.
///
/// La trajectoire est construite comme un segment centré exactement sur le
/// centre de l'écran : le point de départ et le point d'arrivée sont
/// symétriques par rapport à ce centre le long de la droite de cap
/// [_kHeadingAngle], garantissant que le milieu du trajet (t=0.5) coïncide
/// avec le milieu de l'écran — c'est à cet instant que le ralentissement
/// (voir [_MidFlightSlowdownCurve]) est le plus prononcé.
///
/// La vitesse suit une courbe personnalisée en forme de "creux" : rapide au
/// décollage et à la sortie d'écran, ralentissant progressivement jusqu'au
/// milieu du trajet sans jamais descendre sous 50% de la vitesse maximale,
/// puis réaccélérant symétriquement jusqu'à la sortie. Contrairement à une
/// courbe `easeInOut` classique (qui accélère vers le milieu), c'est ici
/// l'inverse : le milieu est le point le plus lent.
///
/// Priorité de rendu volontairement inférieure à celle de n'importe quelle
/// [TileComponent] posée (même logique que le voilier) : si le trajet croise
/// une tuile du plateau, celle-ci est dessinée par-dessus.
library;

import 'dart:math' show Random, atan2, cos, pi, sin;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curve;

import '../core/constants.dart' show kHexSize;
import 'tile_component.dart' show kTileDepthPriorityBase;

/// Angle (radians, sous l'horizontale) du cap naturel de l'avion tel que
/// dessiné dans l'asset, mesuré sur l'image source — voir doc de fichier.
final double _kHeadingAngle = atan2(651 - 355, 1116 - 441); // ≈ 23.7°

/// Vecteur unitaire de déplacement à l'écran (bas-gauche), directement issu
/// du cap naturel du sprite : x négatif (vers la gauche), y positif (vers le
/// bas, convention écran).
final Vector2 _kDirection =
    Vector2(-cos(_kHeadingAngle), sin(_kHeadingAngle));

/// Largeur cible de l'avion à zoom 1.0.
const double _kBaseWidth = kHexSize * 2.4;

/// Ratio hauteur/largeur du sprite source (1536×1024, redimensionné en
/// 768×512 dans l'asset embarqué — même ratio).
const double _kSpriteAspect = 512 / 768;

/// Vitesse moyenne visée pour le trajet (px/s à zoom 1.0).
const double _kFlightSpeed = 130.0;

const double _kMinFlightDuration = 3.5;
const double _kMaxFlightDuration = 9.0;

/// Distance (fraction de la largeur d'écran) parcourue de part et d'autre du
/// centre de l'écran — détermine, avec [_kHeadingAngle], les points de
/// départ et d'arrivée symétriques par rapport au centre.
const double _kReachFraction = 0.62;

/// Marge (px) garantie au-delà des bords de l'écran pour les points de
/// départ/arrivée, ajoutée symétriquement des deux côtés (ne modifie donc
/// pas la position du milieu du trajet, qui reste le centre de l'écran).
const double _kEdgeMargin = 100.0;

/// Courbe de vitesse en creux : progress(t) = t + sin(2πt) / (6π).
///
/// Sa dérivée (la vitesse instantanée) vaut 1 + (1/3)·cos(2πt), qui varie
/// entre 4/3 (aux extrémités t=0 et t=1) et 2/3 (au milieu, t=0.5) — soit un
/// ralentissement exact à 50% de la vitesse maximale au milieu du trajet,
/// jamais en dessous. L'intégrale de la vitesse sur [0,1] vaut exactement 1,
/// donc progress(0)=0 et progress(1)=1 comme toute courbe d'easing valide.
class _MidFlightSlowdownCurve extends Curve {
  const _MidFlightSlowdownCurve();

  @override
  double transformInternal(double t) {
    return t + sin(2 * pi * t) / (6 * pi);
  }
}

class PlaneComponent extends SpriteComponent {
  PlaneComponent({required this.screenSize, double zoom = 1.0})
      : _zoom = zoom,
        super(anchor: Anchor.center, priority: kTileDepthPriorityBase - 1);

  final Vector2 screenSize;
  final double _zoom;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('plane.png');
    size = Vector2(_kBaseWidth * _zoom, _kBaseWidth * _zoom * _kSpriteAspect);

    final rand = Random();
    final center = screenSize / 2;

    // Longueur (px) parcourue de part et d'autre du centre, avec une légère
    // variation aléatoire (appliquée identiquement aux deux moitiés pour
    // conserver la symétrie, donc le passage exact par le centre à t=0.5).
    final reachFraction =
        _kReachFraction * (0.9 + rand.nextDouble() * 0.2); // ±10%
    final halfLength =
        (screenSize.x * reachFraction) / cos(_kHeadingAngle) + _kEdgeMargin;

    final startPosition = center - _kDirection * halfLength;
    final endPosition = center + _kDirection * halfLength;

    final totalDistance = halfLength * 2;
    final duration = (totalDistance / (_kFlightSpeed * _zoom))
        .clamp(_kMinFlightDuration, _kMaxFlightDuration);

    position = startPosition;

    add(MoveEffect.to(
      endPosition,
      EffectController(
        duration: duration,
        curve: const _MidFlightSlowdownCurve(),
      ),
    )..onComplete = () => removeFromParent());
  }
}
