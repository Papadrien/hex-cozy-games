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
///  2. Pause de [kPauseDuration] à cette position ; c'est seulement à la fin
///     de cette pause que le sprite subit un miroir horizontal (symétrie
///     selon un axe vertical passant par le point de pause — fait "virer"
///     le voilier sans avoir besoin d'un second sprite), immédiatement
///     suivi de la glissade vers le coin bas-gauche selon le cap miroir du
///     premier trajet, jusqu'à sortir franchement de l'écran (courbe
///     easeIn — accélération, inverse du ralenti à l'approche), avant
///     suppression du composant.
///
/// Priorité de rendu volontairement inférieure à celle de n'importe quelle
/// [TileComponent] posée ([kTileDepthPriorityBase] - 1) : si le trajet
/// croise une tuile du plateau, celle-ci est dessinée par-dessus sans
/// qu'aucune stratégie d'évitement ne soit mise en place — le voilier passe
/// alors visuellement sous le plateau, comportement volontaire.
///
/// Suivi du pan/zoom du plateau : [HexGridComponent] lui-même ne porte
/// aucune transformation (position fixe à l'origine, échelle 1) ; le
/// pan/zoom y est simulé "à la main" pour chaque tuile, recalculée à chaque
/// frame à partir de [HexGridComponent.cameraOffset] et
/// [HexGridComponent.zoom]. Pour que le voilier suive le plateau de la même
/// façon plutôt que de rester figé en coordonnées écran, les trois étapes
/// du trajet (approche / pause / départ) sont calculées une fois pour
/// toutes en [onLoad] sous forme d'offsets par rapport au centre de
/// l'écran, à l'échelle du zoom au moment de l'apparition — puis [update]
/// reconvertit l'offset courant en position écran réelle à chaque frame en
/// tenant compte du pan courant (translation de [cameraOffset]) et du zoom
/// courant (mise à l'échelle de l'offset et de la taille du sprite par
/// rapport au zoom de spawn), exactement comme le fait [HexGridComponent]
/// pour ses tuiles. L'animation n'utilise donc plus [MoveEffect] (qui
/// écrit directement dans `position`, incompatible avec cette reconversion
/// par frame) mais un minutage manuel dans [update].
library;

import 'dart:math' show Random, atan2, tan;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curves;

import '../core/constants.dart' show kHexSize;
import 'hex_grid_component.dart' show HexGridComponent;
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

enum _SailPhase { approach, pause, departure, done }

class SailboatComponent extends SpriteComponent {
  SailboatComponent({required this.screenSize, double zoom = 1.0})
      : _spawnZoom = zoom,
        super(anchor: Anchor.center, priority: kTileDepthPriorityBase - 1);

  final Vector2 screenSize;

  /// Zoom du plateau au moment de l'apparition — sert de référence pour la
  /// mise à l'échelle de la trajectoire et du sprite en fonction du zoom
  /// courant (voir doc de fichier). Le zoom courant, lui, est relu en
  /// direct sur [_grid] à chaque frame.
  final double _spawnZoom;

  /// Grille parente, dont on lit [HexGridComponent.cameraOffset] et
  /// [HexGridComponent.zoom] à chaque frame — `null` seulement si le
  /// composant a été ajouté hors d'un [HexGridComponent] (ne devrait pas
  /// arriver en usage normal, le voilier étant toujours ajouté via
  /// `grid.add`).
  HexGridComponent? _grid;

  // Offsets par rapport au centre écran (screenSize / 2), exprimés à
  // l'échelle du zoom de spawn — voir doc de fichier.
  late final Vector2 _startOffset;
  late final Vector2 _pauseOffset;
  late final Vector2 _exitOffset;
  late final double _approachDuration;
  late final double _departureDuration;

  _SailPhase _phase = _SailPhase.approach;
  double _elapsedInPhase = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final p = parent;
    _grid = p is HexGridComponent ? p : null;

    sprite = await Sprite.load('sailboat.png');

    final rand = Random();
    // Point d'apparition organique dans le quart haut-gauche de l'écran —
    // peut légèrement déborder hors du cadre visible actuel (valeurs
    // négatives), sans coller au bord du canevas de fond. Exprimé
    // directement comme un offset par rapport au centre écran.
    final startPosition = Vector2(
      screenSize.x * (-0.08 + rand.nextDouble() * 0.30),
      screenSize.y * (-0.08 + rand.nextDouble() * 0.30),
    );
    _startOffset = startPosition - screenSize / 2;

    final approachDx = screenSize.x * _kApproachDxFraction;
    final approachDy = approachDx * tan(_kHeadingAngle);
    _pauseOffset = _startOffset + Vector2(approachDx, approachDy);
    _approachDuration =
        (approachDx / _kSailSpeed).clamp(_kMinLegDuration, _kMaxLegDuration);

    // Trajet de sortie : cap miroir (bas-gauche) de la même pente, prolongé
    // au besoin pour garantir une sortie franche par la gauche de l'écran
    // ([_kExitMargin]) plutôt que de s'arrêter en plein cadre.
    final departureDx = _pauseOffset.x + screenSize.x / 2 + _kExitMargin;
    final departureDy = departureDx * tan(_kHeadingAngle);
    _exitOffset = _pauseOffset + Vector2(-departureDx, departureDy);
    _departureDuration = (departureDx / _kSailSpeed)
        .clamp(_kMinLegDuration, _kMaxLegDuration);

    _applyFrame(_startOffset);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_phase == _SailPhase.done) return;

    _elapsedInPhase += dt;

    switch (_phase) {
      case _SailPhase.approach:
        final rawT = (_elapsedInPhase / _approachDuration).clamp(0.0, 1.0);
        final t = Curves.easeOut.transform(rawT);
        _applyFrame(_startOffset + (_pauseOffset - _startOffset) * t);
        if (rawT >= 1.0) {
          _phase = _SailPhase.pause;
          _elapsedInPhase = 0.0;
        }
        break;

      case _SailPhase.pause:
        // Immobile — reste à l'offset de pause (reconverti chaque frame
        // pour continuer à suivre le pan/zoom pendant l'arrêt).
        _applyFrame(_pauseOffset);
        if (_elapsedInPhase >= kPauseDuration) {
          // Symétrie selon un axe vertical, appliquée seulement maintenant
          // (fin de la pause) : fait "virer" le voilier en place (le
          // point de pause reste le pivot grâce à l'ancre centrée) sans
          // nécessiter de second sprite orienté vers la gauche, juste
          // avant de déclencher le trajet de départ.
          scale.x = -scale.x;
          _phase = _SailPhase.departure;
          _elapsedInPhase = 0.0;
        }
        break;

      case _SailPhase.departure:
        final rawT = (_elapsedInPhase / _departureDuration).clamp(0.0, 1.0);
        final t = Curves.easeIn.transform(rawT);
        _applyFrame(_pauseOffset + (_exitOffset - _pauseOffset) * t);
        if (rawT >= 1.0) {
          _phase = _SailPhase.done;
          removeFromParent();
        }
        break;

      case _SailPhase.done:
        break;
    }
  }

  /// Convertit un offset (par rapport au centre écran, à l'échelle du zoom
  /// de spawn) en position/taille écran réelles, à partir du pan et du
  /// zoom courants du plateau — voir doc de fichier.
  void _applyFrame(Vector2 offset) {
    final grid = _grid;
    final currentZoom = grid?.zoom ?? _spawnZoom;
    final cameraOffset = grid?.cameraOffset ?? Vector2.zero();
    final zoomRatio = currentZoom / _spawnZoom;

    size = Vector2(
        _kBaseWidth * currentZoom, _kBaseWidth * currentZoom * _kSpriteAspect);
    position = cameraOffset + screenSize / 2 + offset * zoomRatio;
  }
}
