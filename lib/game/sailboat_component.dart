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
///  1. Apparition à distance du plateau réellement posé, dans la direction
///     opposée au cap d'approche fixe ([_kHeadingAngle], imposé par
///     l'orientation du sprite) — la bounding box des tuiles de
///     [HexGridComponent.placedTiles] est calculée à l'apparition (voir
///     [_boardWorldBoundsOffset]) ; on y tire un point au hasard, puis on
///     recule le long de ce cap jusqu'à sortir de la boîte (légèrement
///     agrandie d'une marge, [_kBoardApproachMargin]) pour obtenir le point
///     de pause, et encore un peu plus loin pour le point de départ (voir
///     [_distanceToBoxExit]) — le trajet croise donc toujours le plateau
///     par construction, quels que soient sa taille et sa position à
///     l'écran (contrairement à un point de départ choisi indépendamment,
///     par ex. dans le quart haut-gauche de l'écran, qui pouvait manquer
///     un petit plateau excentré). Glissade en ligne oblique suivant
///     [_kHeadingAngle] vers le bas-droite, ralentissant (courbe easeOut) à
///     l'approche du point de pause.
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

import 'dart:math' show Point, Random, atan2, tan;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curves;

import '../core/constants.dart' show kHexSize;
import 'hex_coords.dart' show HexLayout;
import 'hex_grid_component.dart' show HexGridComponent;
import 'tile_component.dart' show kIsoScaleY, kTileDepthPriorityBase;

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

/// Marge (px, à l'échelle du zoom de spawn) ajoutée autour de la bounding
/// box réelle des tuiles posées pour déterminer le point de pause — le
/// voilier s'arrête juste à l'extérieur du plateau plutôt que pile sur son
/// bord (ou, pire, dessus).
const double _kBoardApproachMargin = kHexSize * 1.5;

/// Distance de repli (fraction de la largeur d'écran) utilisée uniquement
/// si aucune tuile n'est posée (ne devrait pas arriver en usage normal,
/// voir `HexBoardGame.kSailboatTriggerTileCount`) — dans ce cas la bounding
/// box du plateau n'existe pas et on retombe sur un point de départ dans le
/// quart haut-gauche de l'écran (comportement d'origine, avant la prise en
/// compte des tuiles réellement posées).
const double _kFallbackApproachDxFraction = 0.62;

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

    // Direction unitaire du trajet d'approche (bas-droite) — fixe, imposée
    // par l'orientation du sprite (voir [_kHeadingAngle]).
    final headingDir = Vector2(1.0, tan(_kHeadingAngle))..normalize();

    final boardBox = _boardWorldBoundsOffset();
    if (boardBox != null) {
      // Point visé tiré au sort À L'INTÉRIEUR de la bounding box réelle du
      // plateau (donc sur/near une tuile) — donne un peu de variété d'une
      // apparition à l'autre sans jamais pouvoir rater le plateau, au
      // contraire de l'ancienne version qui tirait le point de départ au
      // hasard dans le quart haut-gauche de l'écran puis espérait que le
      // trajet (de pente fixe, ~17°) croise le plateau : sur un plateau
      // excentré ou petit par rapport à l'écran, le rayon manquait presque
      // toujours la boîte et retombait systématiquement sur l'ancien calcul
      // de repli (fraction fixe de la largeur d'écran) — c'est ce bug qui
      // faisait apparaître le voilier loin du plateau.
      final (boardMin, boardMax) = boardBox;
      final aimPoint = Vector2(
        boardMin.x + rand.nextDouble() * (boardMax.x - boardMin.x),
        boardMin.y + rand.nextDouble() * (boardMax.y - boardMin.y),
      );

      // Point de pause = point où le trajet d'approche entre dans la boîte
      // (légèrement agrandie d'une marge, [_kBoardApproachMargin]) : on
      // part du point visé (garanti à l'intérieur) et on recule le long de
      // la direction opposée jusqu'à sortir de la boîte agrandie — ce qui,
      // par construction, correspond exactement au point d'entrée d'un
      // trajet arrivant dans le sens inverse (voir [_distanceToBoxExit]).
      final margin = _kBoardApproachMargin * _spawnZoom;
      final entryDistance = _distanceToBoxExit(
        origin: aimPoint,
        direction: headingDir * -1.0,
        boxMin: boardMin - Vector2.all(margin),
        boxMax: boardMax + Vector2.all(margin),
      );
      _pauseOffset = aimPoint - headingDir * entryDistance;

      // Distance de vol avant la pause, tirée au sort pour un rendu
      // organique — à l'échelle de la diagonale écran plutôt qu'en dur,
      // pour rester cohérente quelle que soit la taille d'écran.
      final travelDistance =
          screenSize.length * (0.35 + rand.nextDouble() * 0.35);
      _startOffset = _pauseOffset - headingDir * travelDistance;
    } else {
      // Repli si jamais aucune tuile n'est posée (ne devrait pas arriver en
      // usage normal, voir `HexBoardGame.kSailboatTriggerTileCount`) :
      // ancien comportement, point de départ dans le quart haut-gauche de
      // l'écran.
      final startPosition = Vector2(
        screenSize.x * (-0.08 + rand.nextDouble() * 0.30),
        screenSize.y * (-0.08 + rand.nextDouble() * 0.30),
      );
      _startOffset = startPosition - screenSize / 2;
      final approachDx = screenSize.x * _kFallbackApproachDxFraction;
      _pauseOffset =
          _startOffset + Vector2(approachDx, approachDx * tan(_kHeadingAngle));
    }

    final approachDistance = (_pauseOffset - _startOffset).length;
    _approachDuration = (approachDistance / _kSailSpeed)
        .clamp(_kMinLegDuration, _kMaxLegDuration);

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

  /// Bounding box (min, max) des tuiles réellement posées
  /// ([HexGridComponent.placedTiles]) au moment de l'apparition, dans les
  /// mêmes coordonnées "monde" que [_startOffset]/[_pauseOffset] — un
  /// offset pixel pur par rapport à l'origine du plateau (0, 0), à
  /// l'échelle du zoom de spawn, indépendant du pan (voir doc de fichier :
  /// [_applyFrame] ajoute le pan et l'ancrage écran courants par-dessus
  /// chaque frame, exactement comme le fait [HexGridComponent.layout] pour
  /// une tuile). Calculée avec un [HexLayout] d'origine (0, 0) — même
  /// technique que [HexGridComponent.clampCameraOffset] — plutôt qu'avec
  /// [HexGridComponent.layout] (qui inclut le pan courant, ce qui
  /// désynchroniserait cette bounding box de [_startOffset]). Renvoie
  /// `null` si le voilier n'a pas de grille parente ou si aucune tuile
  /// n'est posée (ne devrait pas arriver en usage normal, voir
  /// `HexBoardGame.kSailboatTriggerTileCount`).
  (Vector2, Vector2)? _boardWorldBoundsOffset() {
    final grid = _grid;
    if (grid == null || grid.placedTiles.isEmpty) return null;

    final worldLayout = HexLayout(
      hexSize: kHexSize * _spawnZoom,
      origin: const Point(0, 0),
    );
    Vector2? min;
    Vector2? max;
    for (final coords in grid.placedTiles.keys) {
      final p = worldLayout.hexToPixel(coords, isoScaleY: kIsoScaleY);
      final offset = Vector2(p.x, p.y);
      if (min == null || max == null) {
        min = offset.clone();
        max = offset.clone();
      } else {
        if (offset.x < min.x) min.x = offset.x;
        if (offset.x > max.x) max.x = offset.x;
        if (offset.y < min.y) min.y = offset.y;
        if (offset.y > max.y) max.y = offset.y;
      }
    }
    return (min!, max!);
  }
}

/// Distance de sortie (> 0) depuis [origin] (supposé à l'intérieur de la
/// boîte [boxMin]–[boxMax]) en avançant le long de [direction] (unitaire)
/// — c'est-à-dire la distance jusqu'à ce que le rayon sorte de la boîte.
///
/// Utilisé pour retrouver, à partir d'un point visé à l'intérieur du
/// plateau, le point d'entrée du trajet d'approche : appelé avec
/// `-headingDir` depuis un point du plateau, cette distance correspond
/// exactement (par symétrie) à la distance qu'un trajet arrivant dans le
/// sens `+headingDir` depuis l'extérieur parcourrait avant d'entrer dans la
/// boîte — pas besoin de tester une intersection rayon/boîte classique
/// (qui peut échouer à trouver un point si l'origine testée n'est pas déjà
/// sur la bonne trajectoire), l'appelant garantit ici l'intersection par
/// construction en partant toujours d'un point interne à la boîte.
double _distanceToBoxExit({
  required Vector2 origin,
  required Vector2 direction,
  required Vector2 boxMin,
  required Vector2 boxMax,
}) {
  var tExit = double.infinity;
  for (var axis = 0; axis < 2; axis++) {
    final o = axis == 0 ? origin.x : origin.y;
    final d = axis == 0 ? direction.x : direction.y;
    final bMin = axis == 0 ? boxMin.x : boxMin.y;
    final bMax = axis == 0 ? boxMax.x : boxMax.y;

    if (d.abs() < 1e-9) continue; // axe non contraignant (direction // bord)
    final t = d > 0 ? (bMax - o) / d : (bMin - o) / d;
    if (t < tExit) tExit = t;
  }
  // `direction` a toujours une composante non nulle sur les deux axes ici
  // (angle de cap fixe ~17°, jamais horizontal ni vertical pur) : au moins
  // un axe contraint toujours tExit, qui reste donc fini en pratique.
  return tExit.isFinite ? tExit : 0.0;
}
