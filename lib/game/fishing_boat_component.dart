/// Bateau de pêche décoratif traversant l'écran — easter egg purement
/// visuel, sans impact sur le jeu, déclenché après un certain nombre de
/// tuiles posées (voir [HexBoardGame.kFishingBoatTriggerTileCount]).
///
/// Reprend exactement le principe du voilier ([SailboatComponent] — voir sa
/// doc de fichier pour le détail du suivi de pan/zoom, du calcul du point
/// de pause par rapport à la bounding box réelle du plateau, etc.), mais du
/// côté opposé de l'écran, comme si toute son animation était le miroir
/// horizontal de celle du voilier :
///  - Voilier : apparaît en haut-gauche, glisse vers le bas-droite jusqu'au
///    plateau, pause, vire, repart vers le bas-gauche.
///  - Bateau de pêche : apparaît en haut-**droite**, glisse vers le
///    bas-**gauche** jusqu'au plateau, pause, vire, repart vers le
///    bas-**droite**.
///
/// Le sprite `fishing_boat.png` a, comme celui du voilier, son cap naturel
/// orienté vers le bas-droite dans l'image source (poupe/grue en
/// haut-gauche, proue en bas-droite) — voir [_kHeadingAngle], mesuré (à vue,
/// contrairement au voilier dont les coordonnées avaient été pointées avec
/// précision) sur l'image (1536×1024) entre la poupe (≈40, 330) et la
/// proue (≈1480, 790), soit environ 17.7° sous l'horizontale — très proche
/// de celui du voilier, cohérent avec un style d'asset similaire.
///
/// Comme ce cap naturel pointe vers le bas-**droite** alors que le premier
/// trajet (l'approche) doit aller vers le bas-**gauche**, le sprite est
/// symétrisé horizontalement (miroir, `scale.x` négatif) **avant même sa
/// première apparition** — c'est l'inversion demandée. Il retrouve son
/// orientation naturelle (miroir inverse, `scale.x` redevenu positif) au
/// même instant que le voilier vire (fin de la pause), pour repartir vers
/// le bas-droite avec le cap d'origine, non retourné.
///
/// Trajet en deux temps (identique au voilier, juste maintenant côté
/// droit) :
///  1. Apparition à distance du plateau réellement posé, dans la direction
///     opposée au cap d'approche (miroir de [_kHeadingAngle], voir
///     ci-dessus) — la bounding box des tuiles de
///     [HexGridComponent.placedTiles] est calculée à l'apparition (voir
///     [_boardWorldBoundsOffset]) ; on y tire un point au hasard, puis on
///     recule le long de ce cap jusqu'à sortir de la boîte (légèrement
///     agrandie d'une marge, [_kBoardApproachMargin]) pour obtenir le point
///     de pause, et encore un peu plus loin pour le point de départ (voir
///     [_distanceToBoxExit]) — le trajet croise donc toujours le plateau
///     par construction, quels que soient sa taille et sa position à
///     l'écran. Glissade en ligne droite, ralentissant (courbe easeOut) à
///     l'approche du point de pause.
///  2. Pause de [kPauseDuration] à cette position ; c'est seulement à la fin
///     de cette pause que le sprite retrouve son orientation naturelle
///     (miroir horizontal inverse de celui appliqué à l'apparition — fait
///     "virer" le bateau sans avoir besoin d'un second sprite), suivi de la
///     glissade vers le coin bas-droite selon le cap naturel (miroir du
///     trajet d'approche), jusqu'à sortir franchement de l'écran par la
///     droite (courbe easeIn — accélération), avant suppression du
///     composant.
///
/// Vitesse identique à celle du voilier ([_kBoatSpeed] = même valeur que
/// [_kSailSpeed] dans `sailboat_component.dart`).
///
/// Priorité de rendu volontairement inférieure à celle de n'importe quelle
/// [TileComponent] posée ([kTileDepthPriorityBase] - 1), comme le voilier :
/// le bateau passe sous le plateau, pas au-dessus (contrairement à l'avion
/// et à la montgolfière).
///
/// Suivi du pan/zoom du plateau : même technique que [SailboatComponent] —
/// voir sa doc de fichier pour le détail complet. Voir aussi
/// [_offScreenSafetyFactor] : la distance de départ et la marge de sortie
/// sont gonflées pour rester hors du cadre visible même après un dézoom du
/// plateau survenu après l'apparition.
///
/// Sillage en V à l'arrière du bateau (voir [_wakeRenderPlan]) — même
/// principe que [SailboatComponent] (voir sa doc de fichier, y compris le
/// partage des deux branches entre avant et arrière du sprite), dupliqué
/// ici avec les coordonnées de poupe/proue propres à `fishing_boat.png`.
///
/// Son d'ambiance dédié (`boat_ambient.mp3`, [AudioService.playBoatAmbient]/
/// [AudioService.stopBoatAmbient]) : démarré en fondu d'entrée à
/// [onLoad] (le bateau vient d'apparaître, encore hors champ), arrêté en
/// fondu de sortie à [onRemove] (juste après sa disparition définitive de
/// l'écran, en fin de trajet de départ) — voir [AudioService] pour le
/// détail des fondus. Nécessite le [ProviderContainer] de l'app (même
/// principe que [HexBoardGame._container]) pour accéder à
/// [audioServiceProvider] depuis ce composant Flame, qui n'a pas de
/// `WidgetRef` propre.
library;

import 'dart:async' show unawaited;
import 'dart:math' show Point, Random, atan2, cos, pi, pow, sin, tan;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, StrokeCap;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;

import '../core/constants.dart' show kHexSize;
import '../services/audio_service.dart' show audioServiceProvider;
import 'hex_coords.dart' show HexLayout;
import 'hex_grid_component.dart' show HexGridComponent;
import 'tile_component.dart'
    show kEdgeWaveFrequency, kEdgeWaveSpeed, kIsoScaleY, kTileDepthPriorityBase;
import 'wake_mixin.dart' show WakeMixin;

/// Angle (radians, sous l'horizontale) du cap naturel du bateau tel que
/// dessiné dans l'asset, mesuré sur l'image source — voir doc de fichier.
final double _kHeadingAngle = atan2(790 - 330, 1480 - 40); // ≈ 17.7°

/// Largeur cible du bateau à zoom 1.0 — légèrement supérieure à celle du
/// voilier ([_kBaseWidth] dans `sailboat_component.dart`), pour rester
/// lisible malgré la grue et les cannes à pêche qui dépassent de la coque.
const double _kBaseWidth = kHexSize * 2.3;

/// Ratio hauteur/largeur du sprite source (1536×1024) — même format que
/// l'asset original du voilier.
const double _kSpriteAspect = 1024 / 1536;

/// Durée de la pause à l'approche du plateau — identique à celle du
/// voilier ([kPauseDuration] dans `sailboat_component.dart`).
const double kPauseDuration = 5.0;

/// Durée du fondu du sillage à l'arrêt et au redémarrage — identique à
/// celle du voilier ([0.5] dans `sailboat_component.dart`).

/// Vitesse moyenne visée pour les deux trajets (px/s à zoom 1.0) —
/// identique à celle du voilier ([_kSailSpeed] dans
/// `sailboat_component.dart`), comme demandé.
const double _kBoatSpeed = 90.0;

const double _kMinLegDuration = 2.5;
const double _kMaxLegDuration = 7.0;

/// Largeur d'une tuile (hexWidth = sqrt(3) * kHexSize) — sert d'unité pour
/// [_kBoardApproachMargin], comme pour le voilier.
const double _kTileWidth = 1.7320508075688772 * kHexSize; // sqrt(3)

/// Marge (px, à l'échelle du zoom de spawn) ajoutée autour de la bounding
/// box réelle des tuiles posées pour déterminer le point de pause — le
/// bateau s'arrête à environ deux largeurs de tuile à l'extérieur du
/// plateau plutôt que pile sur son bord (ou, pire, dessus).
const double _kBoardApproachMargin = _kTileWidth * 4;

/// Distance de repli (fraction de la largeur d'écran) utilisée uniquement
/// si aucune tuile n'est posée (ne devrait pas arriver en usage normal,
/// voir `HexBoardGame.kFishingBoatTriggerTileCount`) — dans ce cas la
/// bounding box du plateau n'existe pas et on retombe sur un point de
/// départ dans le quart haut-droit de l'écran.
const double _kFallbackApproachDxFraction = 0.62;

/// Marge (px) garantie au-delà du bord droit de l'écran pour le point de
/// sortie, pour que le bateau ait bien quitté le cadre visible avant sa
/// suppression plutôt que de s'arrêter en plein milieu.
const double _kExitMargin = 90.0;

/// Facteur de sécurité appliqué aux distances hors-écran (départ, sortie)
/// pour qu'elles restent hors du cadre visible même si le plateau est
/// dézoomé au maximum après l'apparition — même principe que
/// [SailboatComponent] (voir sa doc de fichier pour le détail), dupliqué
/// ici pour garder les deux composants indépendants l'un de l'autre.
double _offScreenSafetyFactor(double spawnZoom) =>
    spawnZoom / HexGridComponent.minZoom;

// ── Sillage en V à l'arrière du bateau ──────────────────────────────────────

/// Position de la poupe (arrière de la coque, au niveau de la ligne de
/// flottaison — pas du pont) en coordonnées normalisées (fraction de la
/// largeur/hauteur du sprite, 0..1) — pointée par analyse des pixels
/// non-transparents de l'asset embarqué (1536×1024, point le plus bas du
/// contour de la coque côté poupe) : poupe ≈ (30, 478). La valeur
/// précédente, (30, 460), tombait ~18px plus haut, dans le flanc crème de
/// la coque au-dessus de la ligne de flottaison plutôt qu'au ras de l'eau.
const Offset _kSternFrac = Offset(30 / 1536, 478 / 1024);

/// Position de la proue (pointe avant de la coque, à l'endroit où l'eau
/// touche l'avant de la coque — la ligne de flottaison peinte en liseré sur
/// l'asset, pas le haut du plat-bord) — sert à la fois d'origine du sillage
/// (départ à l'avant, voir [_renderWake]) et, avec [_kSternFrac], à
/// déterminer la direction "vers l'arrière" (poupe → proue inversé) : proue
/// ≈ (1052, 997), quasiment le point le plus bas du contour de la coque
/// (le ventre de la coque touche la transparence vers y≈999 sur cette
/// plage de x) — pointée directement sur l'asset. Les valeurs précédentes,
/// (1463, 970) puis (1202, 991), s'écartaient encore trop de la ligne de
/// flottaison réelle (la première tombait même hors de la coque, dans la
/// zone transparente).
const Offset _kBowFrac = Offset(1052 / 1536, 997 / 1024);

/// Angle (radians) d'écartement de chaque branche du sillage par rapport à
/// l'axe arrière, à son extrémité — moitié de celui du voilier
/// ([SailboatComponent.WakeMixin.kWakeSpreadAngle] = 16°) : un sillage aussi ouvert
/// sur ce bateau plus long faisait déborder une branche par-dessus le pont.

/// Exposant appliqué à `t` pour façonner l'écartement — même valeur que
/// [SailboatComponent] (voir sa doc de fichier pour le détail).

/// Longueur du sillage, en multiple de la distance poupe→proue — voir la
/// doc de [SailboatComponent] pour le détail (échelle sur la coque réelle,
/// pas sur `size.x` qui inclut les marges transparentes de l'asset).

/// Amplitude de l'ondulation du sillage, en fraction de la distance
/// poupe→proue (même remarque que [WakeMixin.kWakeLengthFraction]) — croissante avec
/// la distance à la proue, même technique que l'ondulation du pied des
/// tuiles ([kEdgeWaveFrequency]/[kEdgeWaveSpeed]), réappliquée ici
/// perpendiculairement à chaque branche.

/// Nombre de segments de chaque branche du sillage — voir la doc de
/// [SailboatComponent] pour le détail : 24 segments (plutôt que 10) pour un
/// tracé lisse au lieu d'angles vifs façon "éclair".


enum _BoatPhase { approach, pause, departure, done }

class FishingBoatComponent extends SpriteComponent with WakeMixin {
  FishingBoatComponent({
    required this.screenSize,
    required ProviderContainer container,
    double zoom = 1.0,
  })  : _spawnZoom = zoom,
        _container = container,
        super(anchor: Anchor.center, priority: kTileDepthPriorityBase - 1);

  final Vector2 screenSize;

  /// Voir doc de fichier (son d'ambiance) — permet d'accéder à
  /// [audioServiceProvider] sans `WidgetRef` propre au composant.
  final ProviderContainer _container;

  @override
  Offset get sternFrac => _kSternFrac;

  @override
  Offset get bowFrac => _kBowFrac;

  @override
  double get wakeIntensity => _wakeIntensity;

  @override
  double get wakeTime => _wakeTime;

  /// Zoom du plateau au moment de l'apparition — sert de référence pour la
  /// mise à l'échelle de la trajectoire et du sprite en fonction du zoom
  /// courant (voir doc de fichier). Le zoom courant, lui, est relu en
  /// direct sur [_grid] à chaque frame.
  final double _spawnZoom;

  /// Grille parente, dont on lit [HexGridComponent.cameraOffset] et
  /// [HexGridComponent.zoom] à chaque frame — `null` seulement si le
  /// composant a été ajouté hors d'un [HexGridComponent] (ne devrait pas
  /// arriver en usage normal, le bateau étant toujours ajouté via
  /// `grid.add`).
  HexGridComponent? _grid;

  // Offsets par rapport au centre écran (screenSize / 2), exprimés à
  // l'échelle du zoom de spawn — voir doc de fichier.
  late final Vector2 _startOffset;
  late final Vector2 _pauseOffset;
  late final Vector2 _exitOffset;
  late final double _approachDuration;
  late final double _departureDuration;

  /// Distance totale du trajet d'approche — même principe que
  /// [SailboatComponent], voir sa doc de fichier pour le détail.
  late final double _approachDistance;

  _BoatPhase _phase = _BoatPhase.approach;
  double _elapsedInPhase = 0.0;
  double _wakeTime = 0.0;

  /// Intensité du sillage (0..1) — voir doc de
  /// [SailboatComponent.wakeIntensity] pour le détail du calcul
  /// (identique ici).
  double _wakeIntensity = 1.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final p = parent;
    _grid = p is HexGridComponent ? p : null;

    sprite = await Sprite.load('fishing_boat.png');

    // Démarre le son d'ambiance en fondu d'entrée dès l'apparition du
    // bateau (encore hors champ à ce stade) — voir doc de fichier.
    unawaited(_container.read(audioServiceProvider).playBoatAmbient());

    // Miroir horizontal appliqué dès l'apparition (voir doc de fichier) :
    // le cap naturel du sprite pointe vers le bas-droite, mais le premier
    // trajet (approche) va vers le bas-gauche.
    scale.x = -1.0;

    final rand = Random();

    // Direction unitaire du trajet d'approche (bas-gauche) — miroir en x
    // de celle du voilier, imposée par le sens de trajet demandé (arrivée
    // du coin haut-droit).
    final headingDir = Vector2(-1.0, tan(_kHeadingAngle))..normalize();

    final boardBox = _boardWorldBoundsOffset();
    if (boardBox != null) {
      // Point visé tiré au sort À L'INTÉRIEUR de la bounding box réelle du
      // plateau (donc sur/near une tuile) — donne un peu de variété d'une
      // apparition à l'autre sans jamais pouvoir rater le plateau (même
      // technique que le voilier, voir sa doc de fichier pour le détail du
      // bug que cette approche corrige par rapport à un point de départ
      // choisi indépendamment du plateau).
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
          (0.70 + rand.nextDouble() * 0.70) *
          _offScreenSafetyFactor(_spawnZoom);
      _startOffset = _pauseOffset - headingDir * travelDistance;
    } else {
      // Repli si jamais aucune tuile n'est posée (ne devrait pas arriver en
      // usage normal, voir `HexBoardGame.kFishingBoatTriggerTileCount`) :
      // point de départ dans le quart haut-droit de l'écran.
      final startPosition = Vector2(
        screenSize.x * (-0.16 + rand.nextDouble() * 0.60),
        screenSize.y * (-0.08 + rand.nextDouble() * 0.30),
      );
      _startOffset = startPosition - screenSize / 2;
      final approachDx = screenSize.x * _kFallbackApproachDxFraction;
      _pauseOffset = _startOffset +
          Vector2(-approachDx, approachDx * tan(_kHeadingAngle));
    }

    _approachDistance = (_pauseOffset - _startOffset).length;
    _approachDuration = (_approachDistance / _kBoatSpeed)
        .clamp(_kMinLegDuration, _kMaxLegDuration);

    // Trajet de sortie : cap miroir (bas-droite) de la même pente, prolongé
    // au besoin pour garantir une sortie franche par la droite de l'écran
    // ([_kExitMargin], gonflée par [_offScreenSafetyFactor]) plutôt que de
    // s'arrêter en plein cadre. Le terme `_pauseOffset.x` n'est volontairement
    // pas gonflé : il ne fait que compenser la position déjà atteinte par le
    // point de pause (annulé dans l'offset final `_exitOffset.x`), seule la
    // distance à parcourir au-delà du bord droit doit rester garantie
    // hors-écran quel que soit le zoom.
    final departureDx =
        (screenSize.x + _kExitMargin * 2) * _offScreenSafetyFactor(_spawnZoom) -
            _pauseOffset.x;
    final departureDy = departureDx * tan(_kHeadingAngle);
    _exitOffset = _pauseOffset + Vector2(departureDx, departureDy);
    _departureDuration = (departureDx / _kBoatSpeed)
        .clamp(_kMinLegDuration, _kMaxLegDuration);

    _applyFrame(_startOffset);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _wakeTime += dt;
    if (_phase == _BoatPhase.done) return;

    _elapsedInPhase += dt;

    switch (_phase) {
      case _BoatPhase.approach:
        final rawT = (_elapsedInPhase / _approachDuration).clamp(0.0, 1.0);
        final t = Curves.easeOut.transform(rawT);
        _applyFrame(_startOffset + (_pauseOffset - _startOffset) * t);
        // Sillage à pleine intensité tant que le bateau navigue — voir doc
        // de [SailboatComponent.wakeIntensity].
        _wakeIntensity = 1.0;
        if (rawT >= 1.0) {
          _phase = _BoatPhase.pause;
          _elapsedInPhase = 0.0;
        }
        break;

      case _BoatPhase.pause:
        // Immobile — reste à l'offset de pause (reconverti chaque frame
        // pour continuer à suivre le pan/zoom pendant l'arrêt).
        _applyFrame(_pauseOffset);
        // Fondu du sillage sur [0.5] pile au moment où le
        // bateau s'arrête — voir doc de [SailboatComponent.wakeIntensity].
        final fadeT =
            (_elapsedInPhase / 0.5).clamp(0.0, 1.0);
        _wakeIntensity = 1.0 - fadeT;
        if (_elapsedInPhase >= kPauseDuration) {
          // Symétrie selon un axe vertical, appliquée seulement maintenant
          // (fin de la pause) : fait "virer" le bateau en place (le point
          // de pause reste le pivot grâce à l'ancre centrée), retrouvant
          // son orientation naturelle (bas-droite) pour le trajet de
          // départ — miroir inverse de celui appliqué à l'apparition (voir
          // [onLoad]).
          scale.x = -scale.x;
          _phase = _BoatPhase.departure;
          _elapsedInPhase = 0.0;
        }
        break;

      case _BoatPhase.departure:
        final rawT = (_elapsedInPhase / _departureDuration).clamp(0.0, 1.0);
        final t = Curves.easeIn.transform(rawT);
        _applyFrame(_pauseOffset + (_exitOffset - _pauseOffset) * t);
        // Fondu du sillage sur [0.5] pile au moment où le
        // bateau redémarre — voir doc de [SailboatComponent.wakeIntensity].
        final fadeT =
            (_elapsedInPhase / 0.5).clamp(0.0, 1.0);
        _wakeIntensity = fadeT;
        if (rawT >= 1.0) {
          _phase = _BoatPhase.done;
          removeFromParent();
        }
        break;

      case _BoatPhase.done:
        break;
    }
  }

  /// Arrête le son d'ambiance en fondu de sortie une fois le composant
  /// définitivement retiré (fin de trajet de départ, voir [update],
  /// `_BoatPhase.departure`) — voir doc de fichier.
  @override
  void onRemove() {
    unawaited(_container.read(audioServiceProvider).stopBoatAmbient());
    super.onRemove();
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
    // Le sillage est scindé en deux branches (voir [_wakeRenderPlan]) —
    // même principe que [SailboatComponent] (voir sa doc de fichier pour le
    // détail) : la branche qui remonte le plus vers le haut de l'écran
    // passe derrière la coque (dessinée avant `super.render`), l'autre
    // passe devant (dessinée après). Coordonnées locales — le moteur a déjà
    // appliqué position/zoom et le miroir (apparition + virage) à `canvas`
    // avant cet appel, donc [_kSternFrac] etc. suivent automatiquement le
    // bateau.
    final plan = wakeRenderPlan();
    if (plan != null) canvas.drawPath(plan.behind, plan.paint);
    super.render(canvas);
    if (plan != null) canvas.drawPath(plan.front, plan.paint);
  }

  /// Construit les deux branches du sillage en V partant de la proue et
  /// enveloppant la coque vers l'arrière — même principe que
  /// [SailboatComponent] (voir sa doc de fichier pour le détail du choix de
  /// la proue comme origine et du classement devant/derrière) — et
  /// détermine laquelle passe derrière la coque (voir [render]) et laquelle
  /// passe devant. Intensité modulée par [wakeIntensity] (alpha et
  /// longueur), pour s'atténuer avec le ralentissement, disparaître pendant
  /// la pause et reprendre avec l'accélération du départ. Renvoie `null` si
  /// le sillage est invisible ou si poupe/proue coïncident.
  @override
  ({Path behind, Path front, Paint paint})? wakeRenderPlan() {
    if (_wakeIntensity <= 0.001) return null;

    final sternPx = Offset(sternFrac.dx * size.x, sternFrac.dy * size.y);
    final bowPx = Offset(bowFrac.dx * size.x, bowFrac.dy * size.y);
    final bowToStern = sternPx - bowPx;
    final bowToSternLength = bowToStern.distance;
    if (bowToSternLength < 0.001) return null;
    final backward = bowToStern / bowToSternLength;

    // La longueur rétrécit légèrement en plus de l'estompage (alpha) — un
    // sillage qui s'efface tout en se rétractant est plus naturel qu'un
    // simple fondu sur place. Échelle sur la distance poupe→proue, voir la
    // doc de [SailboatComponent.WakeMixin.kWakeLengthFraction].
    final length = bowToSternLength *
        WakeMixin.kWakeLengthFraction *
        (0.3 + 0.7 * _wakeIntensity);
    final rippleAmplitude = bowToSternLength * WakeMixin.kWakeRippleFraction;
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * _wakeIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4 * (size.x / _kBaseWidth)
      ..strokeCap = StrokeCap.round;

    // Origine à la proue (pas la poupe), voir doc de [_wakeRenderPlan].
    Path pathForSide(double side) => wakeLinePath(
          origin: bowPx,
          backward: backward,
          length: length,
          spreadAngle: WakeMixin.kWakeSpreadAngle * side,
          rippleAmplitude: rippleAmplitude,
          // Légèrement déphasées entre les deux branches pour éviter une
          // ondulation parfaitement symétrique (moins naturelle).
          phase: side > 0 ? 0.0 : pi,
        );

    // Composante Y (verticale écran) de la direction de chaque branche à
    // mi-longueur — sert uniquement à classer les branches, voir doc de
    // [SailboatComponent._wakeRenderPlan] pour le détail (notamment sur
    // l'insensibilité au miroir horizontal du virage/de l'apparition
    // inversée).
    double dirYForSide(double side) {
      final angle = WakeMixin.kWakeSpreadAngle *
          side *
          pow(0.5, WakeMixin.kWakeWidenExponent).toDouble();
      return backward.dx * sin(angle) + backward.dy * cos(angle);
    }

    final pathPositiveSide = pathForSide(1.0);
    final pathNegativeSide = pathForSide(-1.0);
    final positiveSideIsBehind = dirYForSide(1.0) < dirYForSide(-1.0);

    return (
      behind: positiveSideIsBehind ? pathPositiveSide : pathNegativeSide,
      front: positiveSideIsBehind ? pathNegativeSide : pathPositiveSide,
      paint: paint,
    );
  }

  /// Construit une branche du sillage : part de [origin] (la poupe) selon
  /// [backward] (unitaire), s'écarte progressivement jusqu'à [spreadAngle]
  /// à son extrémité (effet d'éventail), avec une ondulation perpendiculaire
  /// croissante ([rippleAmplitude]) animée par [wakeTime] — même
  /// principe que l'ondulation du pied des tuiles.
  @override
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
    for (var s = 1; s <= WakeMixin.kWakeSegments; s++) {
      final t = s / WakeMixin.kWakeSegments;
      final angle = spreadAngle * pow(t, WakeMixin.kWakeWidenExponent);
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
  /// ([HexGridComponent.placedTiles]) au moment de l'apparition — même
  /// technique que [SailboatComponent._boardWorldBoundsOffset], voir sa
  /// doc pour le détail. Renvoie `null` si le bateau n'a pas de grille
  /// parente ou si aucune tuile n'est posée.
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
/// — même fonction que celle utilisée par [SailboatComponent] (voir sa doc
/// pour le détail), dupliquée ici pour garder les deux composants
/// indépendants l'un de l'autre.
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
  return tExit.isFinite ? tExit : 0.0;
}
