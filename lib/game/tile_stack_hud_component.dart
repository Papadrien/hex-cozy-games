/// Pile de tuiles rendue directement dans Flame — DA Story refonte.
///
/// Affiche les [kVisibleStackSize] prochaines tuiles en HUD haut-droite,
/// avec la texture Voronoï de [BiomeTextureRenderer].
/// Ancré au viewport (coordonnées caméra fixes) via [HudMarginComponent].
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/constants.dart';
import 'biome_texture_renderer.dart';
import 'hex_tile.dart';
import 'tile_component.dart' show kIsoScaleY;

// ── Constantes visuelles ──────────────────────────────────────────────────

/// Rayon de la tuile active dans le HUD.
const double kStackActiveRadius = 36.0;

/// Facteurs de taille pour les tuiles derrière (effet profondeur, pas de transparence).
const List<double> _kScales  = [1.0,  0.82, 0.68];
const List<double> _kAlphas  = [1.0,  1.0,  1.0];

/// Décalage vertical entre tuiles (espace entre elles).
const double _kStackStepY = kStackActiveRadius * 0.80;

/// Marges HUD depuis le bord haut-droit de l'écran.
const double kStackMarginTop   = 100.0;
const double kStackMarginRight = 16.0;

// ── Seed fixe par tuile (pas par coords, car tuile pas encore posée) ─────

int _tileSeed(HexTile tile) {
  var h = 0;
  for (var i = 0; i < tile.sides.length; i++) {
    h ^= (tile.sides[i].index + 1) * (i * 1000003 + 7);
  }
  return h.abs();
}

// ── Composant ─────────────────────────────────────────────────────────────

/// Composant HUD affiché dans le viewport (position fixe écran).
/// À ajouter via [camera.viewport.add()] dans [HexBoardGame.onLoad].
class TileStackHudComponent extends PositionComponent {
  TileStackHudComponent({
    required Vector2 screenSize,
  }) : super(priority: 200) {
    _updatePosition(screenSize);
  }

  /// Liste des tuiles visibles — à mettre à jour depuis [HexBoardGame].
  List<HexTile> visibleTiles = const [];

  /// Taille totale du HUD (pour centrer correctement).
  void onScreenResize(Vector2 screenSize) => _updatePosition(screenSize);

  void _updatePosition(Vector2 screenSize) {
    // On se positionne en haut-droite ; l'ancrage est Anchor.topRight.
    position = Vector2(
      screenSize.x - kStackMarginRight,
      kStackMarginTop,
    );
    anchor = Anchor.topRight;
  }

  @override
  void render(Canvas canvas) {
    if (visibleTiles.isEmpty) return;

    final count = min(visibleTiles.length, _kScales.length);
    var offsetY = 0.0;

    for (var i = 0; i < count; i++) {
      final tile   = visibleTiles[i];
      final radius = kStackActiveRadius * _kScales[i];
      final alpha  = _kAlphas[i];

      // Ombre sous les tuiles derrière.
      if (i > 0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-radius * 0.5, offsetY + radius * kIsoScaleY + 3),
            width: radius * sqrt(3) * 0.8,
            height: radius * kIsoScaleY * 0.4,
          ),
          Paint()..color = const Color(0x33000000),
        );
      }

      _drawHudTile(canvas, tile, radius, offsetY, alpha, isActive: i == 0);

      offsetY += _kStackStepY * _kScales[i];
    }
  }

  void _drawHudTile(
    Canvas canvas,
    HexTile tile,
    double radius,
    double offsetY,
    double alpha, {
    required bool isActive,
  }) {
    final cx = -radius * sqrt(3) / 2; // aligné à droite
    final cy = offsetY + radius * kIsoScaleY;
    final corners = _hexCorners(cx, cy, radius);

    // Path hexagonal.
    final hexPath = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (var i = 1; i < 6; i++) { hexPath.lineTo(corners[i].dx, corners[i].dy); }
    hexPath.close();

    // Texture Voronoï (même renderer que les tuiles posées).
    canvas.save();
    canvas.translate(cx, cy);

    final centeredPath = Path();
    for (var i = 0; i < 6; i++) {
      final p = Offset(corners[i].dx - cx, corners[i].dy - cy);
      if (i == 0) { centeredPath.moveTo(p.dx, p.dy); }
      else { centeredPath.lineTo(p.dx, p.dy); }
    }
    centeredPath.close();

    paintBiomeTexture(
      canvas: canvas,
      hexPath: centeredPath,
      sides: tile.sides,
      hexSize: radius,
      seed: _tileSeed(tile),
      alpha: alpha,
    );
    canvas.restore();

    // Contour.
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = (isActive
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF000000))
            .withValues(alpha: isActive ? 0.80 : 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 1.8 : 1.0,
    );

    // Halo lumineux sur la tuile active.
    if (isActive) {
      canvas.drawPath(
        hexPath,
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  /// Coins d'un hexagone pointy-top avec écrasement iso, centré sur (cx, cy).
  List<Offset> _hexCorners(double cx, double cy, double radius) {
    return List.generate(6, (i) {
      final angle = (60.0 * i - 90.0) * pi / 180.0;
      return Offset(
        cx + radius * cos(angle),
        cy + radius * sin(angle) * kIsoScaleY,
      );
    });
  }
}
