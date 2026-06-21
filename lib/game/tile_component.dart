/// Composant Flame pour le rendu d'une tuile hexagonale colorée — Story 1.3.
///
/// Rendu : chaque côté i est un trapèze (ou triangle) allant du centre de
/// l'hexagone vers les deux sommets qui encadrent ce côté.
///
/// Projection isométrique : les coins sont calculés en espace "monde plat"
/// puis la coordonnée Y est multipliée par [kIsoScaleY] avant dessin —
/// c'est la SEULE transformation iso appliquée, ce qui garantit que le rendu
/// interne de chaque tuile est cohérent avec sa position sur le plateau.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/constants.dart';
import 'hex_cell.dart';
import 'hex_coords.dart';
import 'hex_tile.dart';

/// Facteur d'écrasement vertical isométrique (identique à hex_grid_component).
const double kIsoScaleY = 0.57; // ~tan(30°) → vue à ~30° du plan

/// Durée de l'effet de glow sur les côtés connectés (story 1.6b).
const double kGlowDurationSec = 0.6;

/// Opacité initiale du glow.
const double kGlowStartAlpha = 0.45;

/// Correspondance [BiomeType] → couleurs d'affichage île paradisiaque.
///
/// Chaque biome expose une [color] principale (face du dessus) et une [darkColor]
/// pour les faces latérales extrudées (3D).
extension BiomeColor on BiomeType {
  Color get color {
    switch (this) {
      case BiomeType.plain:
        return const Color(0xFF8BC34A); // vert prairie tropicale
      case BiomeType.flowerField:
        return const Color(0xFFEC407A); // rose champ de fleurs
      case BiomeType.forest:
        return const Color(0xFF2E7D32); // vert mangrove foncé
      case BiomeType.mountain:
        return const Color(0xFF424242); // gris basalte
      case BiomeType.beach:
        return const Color(0xFFFDD835); // sable doré
      case BiomeType.water:
        return const Color(0xFF26C6DA); // turquoise
      case BiomeType.village:
        return const Color(0xFF8D6E63); // bois brun chaud
    }
  }

  /// Teinte dégradée plus claire (pour le centre de la face).
  Color get lightColor {
    final c = color;
    return Color.from(
      alpha: c.a,
      red: (c.r + 0.3).clamp(0.0, 1.0),
      green: (c.g + 0.3).clamp(0.0, 1.0),
      blue: (c.b + 0.3).clamp(0.0, 1.0),
    );
  }
}

/// Épaisseur de base du "bloc" 3D des tuiles, en px logiques.
/// La hauteur réelle varie selon le biome dominant (relief).
const double kTileDepthBase = 8.0;

/// Facteur de relief par biome. Montagne > village > plage.
const Map<BiomeType, double> kReliefFactors = {
  BiomeType.mountain: 2.2,
  BiomeType.village: 1.6,
  BiomeType.forest: 1.3,
  BiomeType.plain: 1.0,
  BiomeType.flowerField: 0.8,
  BiomeType.beach: 0.6,
  BiomeType.water: 0.4,
};

/// Amplitude maximale des offsets aléatoires des sommets (px) pour l'aspect
/// "terrain naturel".
const double kMaxVertexJitter = 2.5;

/// Offset de base pour la priorité de rendu calculée depuis la profondeur
/// iso (voir [TileComponent.updateDepthPriority]). Suffisamment grand pour
/// rester toujours au-dessus des priorités HUD fixes du plateau (preview,
/// pièces, bonus : 2 à 12) même avec un `position.y` négatif important.
const int kTileDepthPriorityBase = 100000;

/// Priorité de rendu de la tuile en prévisualisation (celle qui flotte
/// au-dessus du plateau avant validation du placement, cf. [kPreviewLiftPx]
/// dans hex_grid_component.dart).
///
/// Elle doit toujours être dessinée AU-DESSUS de toutes les tuiles posées,
/// quelle que soit leur profondeur — d'où une marge large par rapport à
/// [kTileDepthPriorityBase] + le plus grand `position.y` raisonnable.
const int kTileDepthPriorityPreview = kTileDepthPriorityBase + 1000000;

/// Composant Flame représentant une tuile hexagonale colorée.
///
/// La projection isométrique est appliquée DANS le rendu (Y *= kIsoScaleY) :
/// le [PositionComponent] est positionné en coordonnées écran "plat", et les
/// coins de l'hexagone sont écrasés au moment du dessin.
class TileComponent extends PositionComponent {
  TileComponent({
    required this.tile,
    required this._coords,
    double hexSize = kHexSize,
    this._alpha = 1.0,
    this.highlightedSides = const {},
    Vector2? position,
  })  : _hexSize = hexSize,
        super(
          position: position ?? Vector2.zero(),
          anchor: Anchor.center,
          size: Vector2(sqrt(3) * hexSize, 2 * hexSize * kIsoScaleY),
          priority: 1,
        );

  HexTile tile;
  final HexCoords _coords;
  HexCoords get coords => _coords;

  double _hexSize;
  double get hexSize => _hexSize;
  set hexSize(double value) {
    _hexSize = value;
    size = Vector2(sqrt(3) * value, 2 * value * kIsoScaleY);
  }

  /// Recalcule la priorité de rendu Flame en fonction de la profondeur iso.
  ///
  /// En vue isométrique, une tuile plus basse à l'écran (Y plus grand) est
  /// visuellement plus proche de la caméra et doit donc être dessinée
  /// PAR-DESSUS les tuiles plus hautes (Y plus petit) — sinon les faces
  /// latérales du bloc 3D d'une tuile du fond peuvent apparaître devant une
  /// tuile du premier plan (cf. retour utilisateur, story 1.8b).
  ///
  /// On utilise `position.y` (centre écran de la tuile, déjà en coordonnées
  /// projetées iso) comme clé de tri, par tranche de 1px → 1 rang de priorité.
  /// Un offset de [kTileDepthPriorityBase] garde toujours ce rang largement
  /// au-dessus des priorités HUD fixes utilisées ailleurs sur le plateau
  /// (preview = 2, pièces/bonus = 10-12), même si position.y est négatif
  /// (tuile au-dessus de l'origine caméra) — sans quoi une tuile pourrait
  /// accidentellement passer devant des éléments de HUD de prévisualisation.
  void updateDepthPriority() {
    priority = kTileDepthPriorityBase + position.y.round();
  }

  double _alpha;
  double get alpha => _alpha;
  set alpha(double value) => _alpha = value.clamp(0.0, 1.0);

  /// Hauteur d'extrusion 3D basée sur le biome dominant de la tuile.
  double get _reliefDepth {
    final dominant = _dominantBiome();
    final factor = kReliefFactors[dominant] ?? 1.0;
    return kTileDepthBase * factor;
  }

  BiomeType _dominantBiome() {
    final counts = <BiomeType, int>{};
    for (final side in tile.sides) {
      counts[side] = (counts[side] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Côtés à surligner en permanence (prévisualisation des connexions).
  Set<int> highlightedSides;

  // ── Glow (story 1.6b) ──────────────────────────────────────────────────────

  Set<int>? _glowSides;
  double _glowAlpha = 0.0;

  /// Déclenche un effet de glow sur les [sides] (liste d'indices 0-5).
  /// Le glow s'estompe sur [kGlowDurationSec] secondes.
  void startGlow(List<int> sides) {
    _glowSides = sides.toSet();
    _glowAlpha = kGlowStartAlpha;
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final depth = _reliefDepth;
    // Petit hash déterministe pour les offsets des sommets.
    final seed = _coords.q * 31 + _coords.r * 17;
    final rng = Random(seed);

    final cx = size.x / 2;
    final cyTop = size.y / 2 - depth / 2;
    final flatCorners = _isoCorners(cx, cyTop);
    final jittered = flatCorners.map((c) {
      final dx = (rng.nextDouble() - 0.5) * kMaxVertexJitter;
      final dy = (rng.nextDouble() - 0.5) * kMaxVertexJitter * kIsoScaleY;
      return Offset(c.dx + dx, c.dy + dy);
    }).toList();

    // ── Ombre portée au sol ───────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.15 * _alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.y / 2 + depth * 0.6),
        width: _hexSize * 1.6,
        height: _hexSize * kIsoScaleY * 0.6,
      ),
      shadowPaint,
    );

    // ── Faces latérales (côtés "bas" du bloc) ────────────────────────────
    for (var i = 0; i < 6; i++) {
      final t0 = jittered[i];
      final t1 = jittered[(i + 1) % 6];
      final midY = (t0.dy + t1.dy) / 2;
      if (midY < cyTop - 0.01) continue;

      final b0 = Offset(t0.dx, t0.dy + depth);
      final b1 = Offset(t1.dx, t1.dy + depth);

      final sidePath = Path()
        ..moveTo(t0.dx, t0.dy)
        ..lineTo(t1.dx, t1.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b0.dx, b0.dy)
        ..close();

      final baseColor = tile.sides[i].color;
      final shaded = Color.from(
        alpha: baseColor.a,
        red: baseColor.r * 0.55,
        green: baseColor.g * 0.55,
        blue: baseColor.b * 0.55,
      );
      // Dégradé vertical sur la face latérale (plus clair en haut).
      canvas.drawPath(
        sidePath,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, t0.dy),
            Offset(0, b0.dy),
            [shaded.withValues(alpha: _alpha), shaded.withValues(alpha: _alpha * 0.7)],
          )
          ..style = PaintingStyle.fill,
      );
    }

    // ── Face du dessus avec dégradé lumineux ────────────────────────────
    for (var i = 0; i < 6; i++) {
      final c0 = jittered[i];
      final c1 = jittered[(i + 1) % 6];

      final path = Path()
        ..moveTo(cx, cyTop)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = Gradient.radial(
            Offset(cx, cyTop),
            _hexSize * kIsoScaleY,
            [
              tile.sides[i].lightColor.withValues(alpha: _alpha),
              tile.sides[i].color.withValues(alpha: _alpha),
            ],
            [0.0, 0.7],
          )
          ..style = PaintingStyle.fill,
      );

      // Liseré de transition entre biomes différents
      final nextColor = tile.sides[(i + 1) % 6].color;
      if (tile.sides[i].color != nextColor) {
        canvas.drawLine(
          Offset(c0.dx, c0.dy),
          Offset(cx, cyTop),
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
            ..strokeWidth = 1.5,
        );
      }

      // Glow sur les côtés connectés (story 1.6b).
      if (_glowSides != null && _glowSides!.contains(i) && _glowAlpha > 0.01) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: _glowAlpha)
            ..style = PaintingStyle.fill,
        );
      }

      // Surbrillance persistante des côtés bien connectés (story 1.7a).
      if (highlightedSides.contains(i)) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.20)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_glowSides != null && _glowAlpha > 0.01) {
      _glowAlpha -= (kGlowStartAlpha / kGlowDurationSec) * dt;
      if (_glowAlpha <= 0.01) {
        _glowAlpha = 0.0;
        _glowSides = null;
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Calcule les 6 sommets de l'hexagone pointy-top avec projection iso,
  /// décalés de (cx, cy) pour compenser l'offset d'ancrage centre.
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
