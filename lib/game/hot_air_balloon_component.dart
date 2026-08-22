/// Montgolfière décorative traversant l'écran de bas en haut — easter egg
/// purement visuel, sans impact sur le jeu, déclenché après un certain
/// nombre de tuiles posées (voir [HexBoardGame.kHotAirBalloonTriggerTileCount]).
///
/// Contrairement à l'avion ([PlaneComponent], trajet rectiligne) ou au
/// voilier ([SailboatComponent], deux trajets avec pause), la montgolfière
/// effectue un unique trajet en légère courbe (Bézier quadratique, voir
/// [_bezierOffset]) du milieu bas de l'écran vers le milieu haut :
///  - Point de départ : bas de l'écran, décalé aléatoirement vers la droite
///    par rapport au centre horizontal ([_kStartRightFraction]).
///  - Point d'arrivée : haut de l'écran, décalé aléatoirement vers la
///    gauche par rapport au centre horizontal ([_kEndLeftFraction]).
///  - Point de contrôle : au milieu du segment départ→arrivée, décalé
///    perpendiculairement d'une petite fraction de la distance
///    ([_kCurveFraction], signe tiré au sort) pour une légère courbe plutôt
///    qu'une ligne droite.
///
/// Le sprite `hot_air_balloon.png` est dessiné à la verticale (montgolfière
/// vue de face/trois-quarts) et n'a pas de "cap" directionnel comme l'avion
/// ou le voilier : il n'est donc jamais tourné ni retourné, quelle que soit
/// la direction instantanée du trajet.
///
/// La vitesse suit la même courbe en "creux" que l'avion
/// ([_MidFlightSlowdownCurve], dupliquée ici car privée à
/// `plane_component.dart`) : rapide au décollage et à la sortie d'écran,
/// ralentissant progressivement jusqu'au milieu du trajet sans jamais
/// descendre sous 50% de la vitesse maximale, puis réaccélérant
/// symétriquement — cette courbe reparamètre directement `t` le long de la
/// courbe de Bézier (comme l'avion le fait sur son segment), donc le point
/// le plus lent coïncide avec le milieu du trajet, à peu près à la hauteur
/// du plateau puisque celui-ci est également centré à l'écran.
///
/// Priorité de rendu volontairement supérieure à celle de n'importe quelle
/// [TileComponent] posée — comme l'avion (et contrairement au voilier), la
/// montgolfière survole le plateau : elle reste visible même si son trajet
/// croise une tuile posée. Utilise [kTileDepthPriorityPreview] (priorité de
/// la tuile actuellement en main du joueur, la plus haute du jeu) + 1 pour
/// garantir qu'elle passe au-dessus de tout, y compris cette tuile en main.
///
/// Suivi du pan/zoom du plateau : même technique que [PlaneComponent] et
/// [SailboatComponent] — voir la doc de fichier de `plane_component.dart`
/// pour le détail complet. En résumé : la trajectoire (départ / contrôle /
/// arrivée) est calculée une fois pour toutes en [onLoad] sous forme
/// d'offsets par rapport au centre de l'écran, à l'échelle du zoom au
/// moment de l'apparition ; [update] reconvertit chaque frame l'offset
/// courant (interpolé le long de la courbe de Bézier) en position écran
/// réelle, en tenant compte du pan et du zoom courants du plateau
/// ([HexGridComponent.cameraOffset], [HexGridComponent.zoom]) — un
/// minutage manuel, sans [MoveEffect].
library;

import 'dart:math' show Random, pi, sin;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curve;

import '../core/constants.dart' show kHexSize;
import 'hex_grid_component.dart' show HexGridComponent;
import 'tile_component.dart' show kTileDepthPriorityPreview;

/// Largeur cible de la montgolfière à zoom 1.0.
const double _kBaseWidth = kHexSize * 2.6;

/// Ratio hauteur/largeur du sprite source (1024×1536).
const double _kSpriteAspect = 1536 / 1024;

/// Vitesse moyenne visée pour le trajet (px/s à zoom 1.0, mesurée en ligne
/// droite départ→arrivée — la courbe étant légère, la longueur réelle du
/// trajet ne s'en écarte que très peu).
const double _kFlightSpeed = 85.0;

const double _kMinFlightDuration = 6.0;
const double _kMaxFlightDuration = 13.0;

/// Décalage horizontal (fraction de la largeur d'écran, tiré au sort dans
/// cette plage) du point de départ vers la droite par rapport au centre.
const double _kStartRightFraction = 0.10;
const double _kStartRightFractionRange = 0.18; // ±, appliqué autour de la valeur ci-dessus

/// Décalage horizontal (fraction de la largeur d'écran) du point d'arrivée
/// vers la gauche par rapport au centre — même plage que le départ.
const double _kEndLeftFraction = 0.10;
const double _kEndLeftFractionRange = 0.18;

/// Marge (px) garantie au-delà des bords haut/bas de l'écran pour les
/// points de départ/arrivée, pour que la montgolfière parte et disparaisse
/// bien hors du cadre visible plutôt que de s'arrêter en plein écran.
const double _kEdgeMargin = 120.0;

/// Amplitude de la légère courbe : fraction de la distance départ→arrivée
/// dont le point de contrôle de la courbe de Bézier est décalé
/// perpendiculairement au segment direct (signe tiré au sort à chaque
/// apparition, pour courber tantôt à gauche, tantôt à droite).
const double _kCurveFraction = 0.16;

/// Courbe de vitesse en creux, identique à celle de [PlaneComponent] —
/// dupliquée ici car la classe d'origine est privée à `plane_component.dart`.
/// progress(t) = t + sin(2πt) / (6π), de dérivée 1 + (1/3)·cos(2πt), qui
/// varie entre 4/3 (aux extrémités) et 2/3 (au milieu) : ralentissement
/// exact à 50% de la vitesse maximale au milieu du trajet, jamais en
/// dessous.
class _MidFlightSlowdownCurve extends Curve {
  const _MidFlightSlowdownCurve();

  @override
  double transformInternal(double t) {
    return t + sin(2 * pi * t) / (6 * pi);
  }
}

class HotAirBalloonComponent extends SpriteComponent {
  HotAirBalloonComponent({required this.screenSize, double zoom = 1.0})
      : _spawnZoom = zoom,
        super(anchor: Anchor.center, priority: kTileDepthPriorityPreview + 1);

  final Vector2 screenSize;

  /// Zoom du plateau au moment de l'apparition — sert de référence pour la
  /// mise à l'échelle de la trajectoire et du sprite en fonction du zoom
  /// courant (voir doc de fichier). Le zoom courant, lui, est relu en
  /// direct sur [_grid] à chaque frame.
  final double _spawnZoom;

  /// Grille parente, dont on lit [HexGridComponent.cameraOffset] et
  /// [HexGridComponent.zoom] à chaque frame — `null` seulement si le
  /// composant a été ajouté hors d'un [HexGridComponent] (ne devrait pas
  /// arriver en usage normal, la montgolfière étant toujours ajoutée via
  /// `grid.add`).
  HexGridComponent? _grid;

  /// Points de la courbe de Bézier quadratique (départ / contrôle /
  /// arrivée), par rapport au centre écran, à l'échelle du zoom de spawn —
  /// voir doc de fichier.
  late final Vector2 _startOffset;
  late final Vector2 _controlOffset;
  late final Vector2 _endOffset;
  late final double _duration;

  double _elapsed = 0.0;
  bool _done = false;

  static const _curve = _MidFlightSlowdownCurve();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final p = parent;
    _grid = p is HexGridComponent ? p : null;

    sprite = await Sprite.load('hot_air_balloon.png');

    final rand = Random();

    final startRightFraction = _kStartRightFraction +
        (rand.nextDouble() * 2 - 1) * _kStartRightFractionRange;
    final endLeftFraction = _kEndLeftFraction +
        (rand.nextDouble() * 2 - 1) * _kEndLeftFractionRange;

    _startOffset = Vector2(
      screenSize.x * startRightFraction,
      screenSize.y / 2 + _kEdgeMargin,
    );
    _endOffset = Vector2(
      -screenSize.x * endLeftFraction,
      -(screenSize.y / 2 + _kEdgeMargin),
    );

    // Point de contrôle : milieu du segment direct, décalé
    // perpendiculairement pour une légère courbe (signe aléatoire).
    final mid = (_startOffset + _endOffset) * 0.5;
    final segment = _endOffset - _startOffset;
    final perp = Vector2(-segment.y, segment.x); // rotation 90°
    final curveSign = rand.nextBool() ? 1.0 : -1.0;
    _controlOffset = mid + perp * (_kCurveFraction * curveSign);

    final totalDistance = segment.length;
    _duration = (totalDistance / (_kFlightSpeed * _spawnZoom))
        .clamp(_kMinFlightDuration, _kMaxFlightDuration);

    _applyFrame(0.0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_done) return;

    _elapsed += dt;
    final rawT = (_elapsed / _duration).clamp(0.0, 1.0);
    _applyFrame(rawT);

    if (rawT >= 1.0) {
      _done = true;
      removeFromParent();
    }
  }

  /// Interpole la courbe de Bézier quadratique (départ / contrôle /
  /// arrivée) au paramètre [t].
  Vector2 _bezierOffset(double t) {
    final oneMinusT = 1.0 - t;
    return _startOffset * (oneMinusT * oneMinusT) +
        _controlOffset * (2 * oneMinusT * t) +
        _endOffset * (t * t);
  }

  /// Calcule la position/taille écran réelles pour la progression [rawT]
  /// (0..1, avant application de la courbe de vitesse), à partir du pan et
  /// du zoom courants du plateau — voir doc de fichier.
  void _applyFrame(double rawT) {
    final t = _curve.transform(rawT);
    final baseOffset = _bezierOffset(t);

    final grid = _grid;
    final currentZoom = grid?.zoom ?? _spawnZoom;
    final cameraOffset = grid?.cameraOffset ?? Vector2.zero();
    final zoomRatio = currentZoom / _spawnZoom;

    size = Vector2(
        _kBaseWidth * currentZoom, _kBaseWidth * currentZoom * _kSpriteAspect);
    position = cameraOffset + screenSize / 2 + baseOffset * zoomRatio;
  }
}
