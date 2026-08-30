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
/// Priorité de rendu volontairement supérieure à celle de n'importe quelle
/// [TileComponent] posée — contrairement au voilier (qui passe sous le
/// plateau), l'avion survole le plateau : il reste visible même s'il croise
/// une tuile posée. Utilise [kTileDepthPriorityPreview] (priorité de la
/// tuile actuellement en main du joueur, la plus haute du jeu) + 1 pour
/// garantir qu'il passe au-dessus de tout, y compris cette tuile en main.
///
/// Suivi du pan/zoom du plateau : [HexGridComponent] lui-même ne porte
/// aucune transformation (position fixe à l'origine, échelle 1 — voir son
/// constructeur) ; le pan/zoom y est simulé "à la main" pour chaque tuile,
/// recalculée à chaque frame à partir de [HexGridComponent.cameraOffset] et
/// [HexGridComponent.zoom] (voir `HexGridComponent.layout`). Pour que
/// l'avion suive le plateau de la même façon plutôt que de rester figé en
/// coordonnées écran, sa trajectoire est calculée une fois pour toutes en
/// [onLoad] sous forme d'un simple offset (départ/arrivée) par rapport au
/// centre de l'écran, à l'échelle du zoom au moment de l'apparition — puis
/// [update] reconvertit cet offset en position écran réelle à chaque frame
/// en tenant compte du pan courant (translation de [cameraOffset]) et du
/// zoom courant (mise à l'échelle de l'offset et de la taille du sprite par
/// rapport au zoom de spawn), exactement comme le fait [HexGridComponent]
/// pour ses tuiles. L'animation n'utilise donc plus [MoveEffect] (qui écrit
/// directement dans `position`, incompatible avec cette reconversion par
/// frame) mais un minutage manuel dans [update]. Voir aussi
/// [_offScreenSafetyFactor] : les distances de départ/arrivée sont
/// gonflées pour rester hors du cadre visible même après un dézoom du
/// plateau survenu après l'apparition.
///
/// Son d'ambiance dédié (`plane_ambient.mp3`,
/// [AudioService.playPlaneAmbient]/[AudioService.stopPlaneAmbient]) :
/// démarré en fondu d'entrée à [onLoad] (l'avion vient d'apparaître, encore
/// hors champ), arrêté en fondu de sortie à [onRemove] (juste après sa
/// disparition définitive de l'écran, en fin de trajet) — même principe
/// exactement que [FishingBoatComponent]/[SailboatComponent] (voir leur
/// doc de fichier), sur un lecteur dédié distinct. Nécessite le
/// [ProviderContainer] de l'app (même principe que
/// [HexBoardGame._container]) pour accéder à [audioServiceProvider] depuis
/// ce composant Flame, qui n'a pas de `WidgetRef` propre.
library;

import 'dart:async' show unawaited;
import 'dart:math' show Random, atan2, cos, pi, sin;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;

import '../core/constants.dart' show kHexSize;
import '../services/audio_service.dart' show audioServiceProvider;
import 'hex_grid_component.dart' show HexGridComponent;
import 'tile_component.dart' show kTileDepthPriorityPreview;

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

const double _kMinFlightDuration = 7.0;
const double _kMaxFlightDuration = 18.0;

/// Distance (fraction de la largeur d'écran) parcourue de part et d'autre du
/// centre de l'écran — détermine, avec [_kHeadingAngle], les points de
/// départ et d'arrivée symétriques par rapport au centre.
const double _kReachFraction = 0.62;

/// Marge (px) garantie au-delà des bords de l'écran pour les points de
/// départ/arrivée, ajoutée symétriquement des deux côtés (ne modifie donc
/// pas la position du milieu du trajet, qui reste le centre de l'écran).
const double _kEdgeMargin = 100.0;

/// Multiplicateur appliqué à la distance de départ/arrivée pour que ces
/// points restent bien plus loin du plateau (l'avion apparaît/disparaît
/// nettement hors champ plutôt qu'à la limite visible de l'écran) — un peu
/// comme le voilier et le bateau de pêche, dont les points de départ/sortie
/// sont eux aussi largement au-delà du cadre visible. [_kMinFlightDuration]
/// et [_kMaxFlightDuration] sont doublées en conséquence, pour conserver la
/// vitesse moyenne visée ([_kFlightSpeed]) malgré la distance accrue.
const double _kSpawnDistanceMultiplier = 2.0;

/// Facteur de sécurité appliqué à la distance de départ/arrivée pour rester
/// hors du cadre visible même si le plateau est dézoomé au maximum après
/// l'apparition — voir doc de fichier ("Suivi du pan/zoom") : les offsets
/// sont calculés en pixels à l'échelle du zoom de spawn, puis mis à
/// l'échelle du zoom courant à chaque frame ; un zoom arrière après
/// l'apparition réduit donc leur distance apparente à l'écran d'autant.
/// Sans ce facteur, un avion apparu à peine hors-écran à
/// [HexGridComponent.maxZoom] pourrait se retrouver visible en plein écran
/// si le joueur dézoome ensuite jusqu'à [HexGridComponent.minZoom] (jusqu'à
/// 5× plus de plateau visible). En multipliant la distance de départ par
/// (zoom de spawn / zoom minimal), elle reste garantie hors-écran même dans
/// ce pire des cas, quel que soit le zoom au moment de l'apparition.
double _offScreenSafetyFactor(double spawnZoom) =>
    spawnZoom / HexGridComponent.minZoom;

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
  PlaneComponent({
    required this.screenSize,
    required this._container,
    double zoom = 1.0,
  })  : _spawnZoom = zoom,
        super(anchor: Anchor.center, priority: kTileDepthPriorityPreview + 1);

  final Vector2 screenSize;

  /// Voir doc de fichier (son d'ambiance) — permet d'accéder à
  /// [audioServiceProvider] sans `WidgetRef` propre au composant.
  final ProviderContainer _container;

  /// Zoom du plateau au moment de l'apparition — sert de référence pour la
  /// mise à l'échelle de la trajectoire et du sprite en fonction du zoom
  /// courant (voir doc de fichier). Le zoom courant, lui, est relu en
  /// direct sur [_grid] à chaque frame.
  final double _spawnZoom;

  /// Grille parente, dont on lit [HexGridComponent.cameraOffset] et
  /// [HexGridComponent.zoom] à chaque frame — `null` seulement si le
  /// composant a été ajouté hors d'un [HexGridComponent] (ne devrait pas
  /// arriver en usage normal, l'avion étant toujours ajouté via `grid.add`).
  HexGridComponent? _grid;

  /// Offsets de départ/arrivée par rapport au centre écran, exprimés à
  /// l'échelle du zoom de spawn — voir doc de fichier.
  late final Vector2 _startOffset;
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

    sprite = await Sprite.load('plane.png');

    // Démarre le son d'ambiance en fondu d'entrée dès l'apparition de
    // l'avion (encore hors champ à ce stade) — voir doc de fichier.
    debugPrint('[PlaneAmbient] PlaneComponent.onLoad → appel playPlaneAmbient()');
    unawaited(_container.read(audioServiceProvider).playPlaneAmbient());

    final rand = Random();

    // Longueur (px) parcourue de part et d'autre du centre, avec une légère
    // variation aléatoire (appliquée identiquement aux deux moitiés pour
    // conserver la symétrie, donc le passage exact par le centre à t=0.5).
    final reachFraction =
        _kReachFraction * (0.9 + rand.nextDouble() * 0.2); // ±10%
    final halfLength =
        ((screenSize.x * reachFraction) / cos(_kHeadingAngle) + _kEdgeMargin) *
            _offScreenSafetyFactor(_spawnZoom) *
            _kSpawnDistanceMultiplier;

    _startOffset = _kDirection * (-halfLength);
    _endOffset = _kDirection * halfLength;

    final totalDistance = halfLength * 2;
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

  /// Arrête le son d'ambiance en fondu de sortie une fois le composant
  /// définitivement retiré (fin de trajet, voir [update]) — voir doc de
  /// fichier.
  @override
  void onRemove() {
    unawaited(_container.read(audioServiceProvider).stopPlaneAmbient());
    super.onRemove();
  }

  /// Calcule la position/taille écran réelles pour la progression [rawT]
  /// (0..1, avant application de la courbe de vitesse), à partir du pan et
  /// du zoom courants du plateau — voir doc de fichier.
  void _applyFrame(double rawT) {
    final t = _curve.transform(rawT);
    final baseOffset = _startOffset + (_endOffset - _startOffset) * t;

    final grid = _grid;
    final currentZoom = grid?.zoom ?? _spawnZoom;
    final cameraOffset = grid?.cameraOffset ?? Vector2.zero();
    final zoomRatio = currentZoom / _spawnZoom;

    size = Vector2(
        _kBaseWidth * currentZoom, _kBaseWidth * currentZoom * _kSpriteAspect);
    position = cameraOffset + screenSize / 2 + baseOffset * zoomRatio;
  }
}
