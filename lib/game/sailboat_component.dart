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
/// par frame) mais un minutage manuel dans [update]. Voir aussi
/// [_offScreenSafetyFactor] : la distance de départ et la marge de sortie
/// sont gonflées pour rester hors du cadre visible même après un dézoom du
/// plateau survenu après l'apparition.
///
/// Sillage en V à l'arrière du bateau (voir [_renderWake]) : dessiné en
/// coordonnées locales du sprite (donc automatiquement suivi par le
/// pan/zoom et le miroir de virage, puisqu'appliqués par le moteur avant
/// l'appel à [render]), sur le même principe que l'ondulation animée du
/// pied des tuiles ([kEdgeWaveFrequency]/[kEdgeWaveSpeed] dans
/// `tile_component.dart`, réutilisées ici) — deux branches ondulées
/// partant de la poupe et s'écartant progressivement vers l'arrière,
/// inspirées de la forme du sillage sur l'image de référence fournie.
library;

import 'dart:math' show Point, Random, atan2, cos, pi, sin, sqrt, tan;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, StrokeCap;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curves;

import '../core/constants.dart' show kHexSize;
import 'hex_coords.dart' show HexLayout;
import 'hex_grid_component.dart' show HexGridComponent;
import 'tile_component.dart'
    show kEdgeWaveFrequency, kEdgeWaveSpeed, kIsoScaleY, kTileDepthPriorityBase;

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

/// Largeur d'une tuile (hexWidth = sqrt(3) * kHexSize) — sert d'unité pour
/// [_kBoardApproachMargin].
const double _kTileWidth = 1.7320508075688772 * kHexSize; // sqrt(3)

/// Marge (px, à l'échelle du zoom de spawn) ajoutée autour de la bounding
/// box réelle des tuiles posées pour déterminer le point de pause — le
/// voilier s'arrête à environ deux largeurs de tuile à l'extérieur du
/// plateau plutôt que pile sur son bord (ou, pire, dessus).
const double _kBoardApproachMargin = _kTileWidth * 2;

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

/// Facteur de sécurité appliqué aux distances hors-écran (départ, sortie)
/// pour qu'elles restent hors du cadre visible même si le plateau est
/// dézoomé au maximum après l'apparition — voir la doc de fichier de
/// `plane_component.dart` (même principe, dupliqué ici car privé) : les
/// offsets sont calculés en pixels à l'échelle du zoom de spawn, puis mis à
/// l'échelle du zoom courant à chaque frame ; un zoom arrière après
/// l'apparition réduit donc leur distance apparente à l'écran d'autant.
double _offScreenSafetyFactor(double spawnZoom) =>
    spawnZoom / HexGridComponent.minZoom;

// ── Sillage en V à l'arrière du bateau ──────────────────────────────────────

/// Position de la poupe (arrière de la coque, au niveau de la ligne de
/// flottaison — pas du pont) en coordonnées normalisées (fraction de la
/// largeur/hauteur du sprite, 0..1) — pointée directement sur l'asset
/// embarqué (768×512, quadrillage à l'appui) : poupe ≈ (190, 415).
/// Volontairement au ras de la coque plutôt qu'au niveau du pont/gouvernail
/// : un point plus haut faisait passer le sillage à travers le bateau au
/// lieu de longer sa coque.
const Offset _kSternFrac = Offset(190 / 768, 415 / 512);

/// Position de la proue (pointe avant de la coque, hors beaupré, au niveau
/// de la ligne de flottaison) — sert à la fois d'origine du sillage (départ
/// à l'avant, voir [_renderWake]) et, avec [_kSternFrac], à déterminer la
/// direction "vers l'arrière" (poupe → proue inversé) : proue ≈ (600, 440).
const Offset _kBowFrac = Offset(600 / 768, 440 / 512);

/// Angle (radians) d'écartement de chaque branche du sillage par rapport à
/// l'axe arrière, à son extrémité — forme en "V" évasé, inspirée de l'image
/// de référence fournie. Volontairement modeste : un angle trop large (avec
/// [_kWakeLengthFraction]) faisait sortir une branche du sillage par-dessus
/// le pont/la voile au lieu de longer la coque.
const double _kWakeSpreadAngle = 8 * pi / 180;

/// Longueur du sillage, en multiple de la distance poupe→proue (et non plus
/// de la largeur du sprite) — pour rester à l'échelle du bateau lui-même
/// quels que soient le cadrage et les marges transparentes de l'asset, qui
/// n'ont rien à voir avec la taille réelle de la coque.
const double _kWakeLengthFraction = 0.85;

/// Amplitude de l'ondulation du sillage, en fraction de la distance
/// poupe→proue (même remarque que [_kWakeLengthFraction]) — croissante avec
/// la distance à la proue, même technique que l'ondulation du pied des
/// tuiles ([kEdgeWaveFrequency]/[kEdgeWaveSpeed]), réappliquée ici
/// perpendiculairement à chaque branche.
const double _kWakeRippleFraction = 0.02;

/// Nombre de segments de chaque branche du sillage — volontairement plus
/// élevé que pour l'ondulation du pied des tuiles ([kEdgeWaveSegments] = 8) :
/// avec seulement 10 segments pour ~1,5 oscillation, la ligne (tracée en
/// segments droits, sans lissage de courbe) rendait des angles vifs façon
/// "éclair"/branchages plutôt qu'une ondulation lisse. 24 segments donne un
/// tracé visuellement lisse à l'échelle d'affichage d'un sillage.

const int _kWakeSegments = 24;

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
  double _wakeTime = 0.0;

  /// Intensité du sillage (0..1) — pleine pendant l'essentiel de l'approche,
  /// s'atténue en même temps que le ralentissement (courbe `easeOut`) juste
  /// avant la pause, nulle pendant la pause, puis remonte progressivement
  /// en même temps que l'accélération du départ (courbe `easeIn`). Suit la
  /// même progression `rawT` que le déplacement plutôt qu'une temporisation
  /// séparée, pour rester synchronisée avec la vitesse réelle du bateau.
  double _wakeIntensity = 1.0;

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
      // pour rester cohérente quelle que soit la taille d'écran. Gonflée
      // par [_offScreenSafetyFactor] pour rester hors-écran même après un
      // dézoom survenu depuis l'apparition.
      final travelDistance = screenSize.length *
          (0.35 + rand.nextDouble() * 0.35) *
          _offScreenSafetyFactor(_spawnZoom);
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
    // ([_kExitMargin], gonflée par [_offScreenSafetyFactor]) plutôt que de
    // s'arrêter en plein cadre. Le terme `_pauseOffset.x` n'est volontairement
    // pas gonflé : il ne fait que compenser la position déjà atteinte par le
    // point de pause (annulé dans l'offset final `_exitOffset.x`), seule la
    // distance à parcourir au-delà du bord gauche doit rester garantie
    // hors-écran quel que soit le zoom.
    final departureDx = _pauseOffset.x +
        (screenSize.x / 2 + _kExitMargin) * _offScreenSafetyFactor(_spawnZoom);
    final departureDy = departureDx * tan(_kHeadingAngle);
    _exitOffset = _pauseOffset + Vector2(-departureDx, departureDy);
    _departureDuration = (departureDx / _kSailSpeed)
        .clamp(_kMinLegDuration, _kMaxLegDuration);

    _applyFrame(_startOffset);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _wakeTime += dt;
    if (_phase == _SailPhase.done) return;

    _elapsedInPhase += dt;

    switch (_phase) {
      case _SailPhase.approach:
        final rawT = (_elapsedInPhase / _approachDuration).clamp(0.0, 1.0);
        final t = Curves.easeOut.transform(rawT);
        _applyFrame(_startOffset + (_pauseOffset - _startOffset) * t);
        // Le sillage s'atténue avec le ralentissement (rawT → 1 = vitesse
        // → 0 en fin d'approche, voir la courbe `easeOut` ci-dessus).
        _wakeIntensity = 1.0 - rawT;
        if (rawT >= 1.0) {
          _phase = _SailPhase.pause;
          _elapsedInPhase = 0.0;
        }
        break;

      case _SailPhase.pause:
        // Immobile — reste à l'offset de pause (reconverti chaque frame
        // pour continuer à suivre le pan/zoom pendant l'arrêt).
        _applyFrame(_pauseOffset);
        _wakeIntensity = 0.0;
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
        // Le sillage reprend avec l'accélération du départ (rawT → 1 =
        // vitesse maximale en fin de départ, voir la courbe `easeIn`
        // ci-dessus) — en racine carrée plutôt que linéaire pour remonter
        // plus vite au début (ex. déjà 70% d'intensité à 50% du trajet de
        // départ, contre 50% en linéaire), le fondu linéaire restant trop
        // discret pour bien se voir.
        _wakeIntensity = sqrt(rawT);
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

  @override
  void render(Canvas canvas) {
    // Dessiné avant le sprite (donc visuellement en dessous), en
    // coordonnées locales — le moteur a déjà appliqué position/zoom et le
    // miroir de virage à `canvas` avant cet appel, donc [_kSternFrac] etc.
    // (exprimées en fraction de la boîte locale [0, size]) suivent
    // automatiquement le bateau sans logique supplémentaire.
    _renderWake(canvas);
    super.render(canvas);
  }

  /// Sillage en V partant de la proue et enveloppant la coque vers
  /// l'arrière (et non de la poupe vers l'extérieur, qui donnait un rendu
  /// en fourche détachée du bateau) — voir doc de fichier. Intensité
  /// modulée par [_wakeIntensity] (alpha et longueur), pour s'atténuer avec
  /// le ralentissement, disparaître pendant la pause et reprendre avec
  /// l'accélération du départ.
  void _renderWake(Canvas canvas) {
    if (_wakeIntensity <= 0.001) return;

    final sternPx = Offset(_kSternFrac.dx * size.x, _kSternFrac.dy * size.y);
    final bowPx = Offset(_kBowFrac.dx * size.x, _kBowFrac.dy * size.y);
    final bowToStern = sternPx - bowPx;
    final bowToSternLength = bowToStern.distance;
    if (bowToSternLength < 0.001) return;
    final backward = bowToStern / bowToSternLength;

    // La longueur rétrécit légèrement en plus de l'estompage (alpha) — un
    // sillage qui s'efface tout en se rétractant est plus naturel qu'un
    // simple fondu sur place. Échelle sur la distance poupe→proue (la
    // taille réelle de la coque), pas sur `size.x` (largeur de tout le
    // sprite, qui inclut la voile et les marges transparentes de l'asset et
    // n'a donc aucun rapport avec la longueur du bateau) — voir doc de
    // [_kWakeLengthFraction].
    final length = bowToSternLength *
        _kWakeLengthFraction *
        (0.3 + 0.7 * _wakeIntensity);
    final rippleAmplitude = bowToSternLength * _kWakeRippleFraction;
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * _wakeIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * (size.x / _kBaseWidth)
      ..strokeCap = StrokeCap.round;

    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        _wakeLinePath(
          // Origine à la proue (pas la poupe) : chaque branche part donc
          // de l'avant, longe la coque sur le côté en s'écartant
          // progressivement (voir [_kWakeSpreadAngle] et le `t * t` dans
          // [_wakeLinePath]), et ne dépasse la largeur du bateau qu'après
          // avoir atteint/dépassé la poupe — le sillage englobe ainsi la
          // coque au lieu de se réduire à une fourche isolée en arrière.
          origin: bowPx,
          backward: backward,
          length: length,
          spreadAngle: _kWakeSpreadAngle * side,
          rippleAmplitude: rippleAmplitude,
          // Légèrement déphasées entre les deux branches pour éviter une
          // ondulation parfaitement symétrique (moins naturelle).
          phase: side > 0 ? 0.0 : pi,
        ),
        paint,
      );
    }
  }

  /// Construit une branche du sillage : part de [origin] (la poupe) selon
  /// [backward] (unitaire), s'écarte progressivement jusqu'à [spreadAngle]
  /// à son extrémité (effet d'éventail), avec une ondulation perpendiculaire
  /// croissante ([rippleAmplitude]) animée par [_wakeTime] — même
  /// principe que l'ondulation du pied des tuiles.
  Path _wakeLinePath({
    required Offset origin,
    required Offset backward,
    required double length,
    required double spreadAngle,
    required double rippleAmplitude,
    required double phase,
  }) {
    final perp = Offset(-backward.dy, backward.dx);
    final path = Path()..moveTo(origin.dx, origin.dy);
    for (var s = 1; s <= _kWakeSegments; s++) {
      final t = s / _kWakeSegments;
      final angle = spreadAngle * t * t;
      final cosA = cos(angle);
      final sinA = sin(angle);
      final dirX = backward.dx * cosA - backward.dy * sinA;
      final dirY = backward.dx * sinA + backward.dy * cosA;
      final dist = length * t;
      final ripple = rippleAmplitude *
          t *
          sin(kEdgeWaveFrequency * 2 * pi * t +
              phase +
              _wakeTime * kEdgeWaveSpeed);
      path.lineTo(
        origin.dx + dirX * dist + perp.dx * ripple,
        origin.dy + dirY * dist + perp.dy * ripple,
      );
    }
    return path;
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
