/// Voilier décoratif traversant l'écran — easter egg purement visuel,
/// sans impact sur le jeu, déclenché après un certain nombre de tuiles
/// posées (voir [HexBoardGame.kSailboatTriggerTileCount]).
///
/// Le sprite `sailboat.png` a son cap naturellement orienté vers le
/// bas-droite dans l'image source (poupe/gouvernail en haut-gauche,
/// beaupré en bas-droite) — voir [_kHeadingAngle], mesuré directement sur
/// l'image (1536×1024) entre la poupe (≈314, 641) et la pointe du
/// beaupré (≈1247, 923), soit environ 16.8° sous l'horizontale.
///
/// Trajet en deux temps :
///  1. Apparition dans le quart haut-gauche de l'écran — position tirée au
///     sort à chaque déclenchement pour un rendu plus organique, pouvant
///     légèrement déborder de la zone visible actuelle (pas besoin d'être
///     collé au bord du canevas de fond, qui est virtuellement infini).
///     Glissade ensuite en ligne oblique suivant [_kHeadingAngle] vers le
///     bas-droite, ralentissant (courbe easeOut) à l'approche d'un point de
///     pause choisi à l'écart du centre de l'écran (là où se trouve
///     généralement le plateau) — best effort uniquement : aucune détection
///     des tuiles réellement posées n'est effectuée, voir la priorité de
///     rendu ci-dessous pour ce qui se passe si le plateau déborde dessus.
///  2. Pause de [kPauseDuration] à cette position, puis miroir horizontal
///     du sprite (symétrie selon un axe vertical passant par le point de
///     pause — fait "virer" le voilier sans avoir besoin d'un second
///     sprite) et glissade vers le coin bas-gauche selon le cap miroir du
///     premier trajet, jusqu'à sortir franchement de l'écran (courbe
///     easeIn — accélération, inverse du ralenti à l'approche), avant
///     suppression du composant.
///
/// Priorité de rendu volontairement inférieure à celle de n'importe quelle
/// [TileComponent] posée ([kTileDepthPriorityBase] - 1) : si le trajet
/// croise une tuile du plateau, celle-ci est dessinée par-dessus sans
/// qu'aucune stratégie d'évitement ne soit mise en place — le voilier passe
/// alors visuellement sous le plateau, comportement volontaire.
library;

import 'dart:math' show Random, atan2, tan;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;

import '../core/constants.dart' show kHexSize;
import 'tile_component.dart' show kTileDepthPriorityBase;

/// Angle (radians, sous l'horizontale) du cap naturel du voilier tel que
/// dessiné dans l'asset, mesuré sur l'image source — voir doc de fichier.
/// Utilisé pour le trajet d'approche ; miroir en x (même magnitude) pour le
/// trajet de départ.
final double _kHeadingAngle = atan2(923 - 641, 1247 - 314); // ≈ 16.8°

/// Largeur cible du voilier à zoom 1.0 — proche de la largeur d'une tuile
/// posée (hexWidth = sqrt(3) * kHexSize ≈ 83 px, voir `hex_coords.dart`),
/// légèrement supérieure pour rester bien lisible malgré le mât/la voile.
const double _kBaseWidth = kHexSize * 2.0;

/// Ratio hauteur/largeur du sprite source (1536×1024, redimensionné en
/// 768×512 dans l'asset embarqué — même ratio).
const double _kSpriteAspect = 512 / 768;

/// Durée de la pause à l'approche du plateau.
const double kPauseDuration = 5.0;

/// Vitesse moyenne visée pour les deux trajets (px/s à zoom 1.0) — la durée
/// de chaque trajet en découle (distance / vitesse), pour rester cohérente
/// quelle que soit la taille d'écran plutôt que fixée en dur.
const double _kSailSpeed = 90.0;

const double _kMinLegDuration = 2.5;
const double _kMaxLegDuration = 7.0;

/// Distance horizontale (fraction de la largeur d'écran) parcourue pendant
/// le trajet d'approche — détermine le point de pause avec [_kHeadingAngle].
const double _kApproachDxFraction = 0.62;

/// Marge (px) garantie au-delà du bord gauche de l'écran pour le point de
/// sortie, pour que le voilier ait bien quitté le cadre visible avant sa
/// suppression plutôt que de s'arrêter en plein milieu.
const double _kExitMargin = 90.0;

class SailboatComponent extends SpriteComponent {
  SailboatComponent({required this.screenSize, double zoom = 1.0})
      : _zoom = zoom,
        super(anchor: Anchor.center, priority: kTileDepthPriorityBase - 1);

  final Vector2 screenSize;
  final double _zoom;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('sailboat.png');
    size = Vector2(_kBaseWidth * _zoom, _kBaseWidth * _zoom * _kSpriteAspect);

    final rand = Random();
    // Point d'apparition organique dans le quart haut-gauche de l'écran —
    // peut légèrement déborder hors du cadre visible actuel (valeurs
    // négatives), sans coller au bord du canevas de fond.
    position = Vector2(
      screenSize.x * (-0.08 + rand.nextDouble() * 0.30),
      screenSize.y * (-0.08 + rand.nextDouble() * 0.30),
    );

    final approachDx = screenSize.x * _kApproachDxFraction;
    final approachDy = approachDx * tan(_kHeadingAngle);
    final pausePosition = position + Vector2(approachDx, approachDy);
    final approachDuration =
        (approachDx / _kSailSpeed).clamp(_kMinLegDuration, _kMaxLegDuration);

    // Trajet de sortie : cap miroir (bas-gauche) de la même pente, prolongé
    // au besoin pour garantir une sortie franche par la gauche de l'écran
    // ([_kExitMargin]) plutôt que de s'arrêter en plein cadre.
    final departureDx = pausePosition.x + _kExitMargin;
    final departureDy = departureDx * tan(_kHeadingAngle);
    final exitPosition = pausePosition + Vector2(-departureDx, departureDy);
    final departureDuration = (departureDx / _kSailSpeed)
        .clamp(_kMinLegDuration, _kMaxLegDuration);

    add(MoveEffect.to(
      pausePosition,
      EffectController(duration: approachDuration, curve: Curves.easeOut),
    )..onComplete = () {
        // Symétrie selon un axe vertical : fait "virer" le voilier en place
        // (le point de pause reste le pivot grâce à l'ancre centrée) sans
        // nécessiter de second sprite orienté vers la gauche.
        scale.x = -scale.x;
        add(MoveEffect.to(
          exitPosition,
          EffectController(
            duration: departureDuration,
            curve: Curves.easeIn,
            startDelay: kPauseDuration,
          ),
        )..onComplete = () => removeFromParent());
      });
  }
}
