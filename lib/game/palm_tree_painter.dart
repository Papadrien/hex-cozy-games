/// Dessin Canvas d'un palmier stylisé — Story 1.10a.
///
/// Inspiré du modèle 3D "Palm Tree.glb" présent dans les assets.
/// Rendu purement 2D / canvas pour rester cohérent avec l'esthétique
/// du jeu (aucun moteur 3D requis, pas de dépendance externe).
///
/// Usage :
///   PalmTreePainter.draw(canvas, center, scale);
///
/// [center] : position du pied du palmier en coordonnées locales du canvas.
/// [scale]  : facteur de taille — 1.0 correspond à un palmier adapté pour un
///            hexSize de 48 px (kHexSize par défaut).
library;

import 'dart:math';
import 'dart:ui';

/// Dessine un palmier stylisé isométrique centré en [center].
///
/// [scale] est typiquement `hexSize / kHexSize` pour s'adapter au zoom.
/// [alpha] permet d'atténuer l'opacité (prévisualisation, HUD).
void drawPalmTree(
  Canvas canvas,
  Offset center, {
  double scale = 1.0,
  double alpha = 1.0,
}) {
  // ── Tronc ─────────────────────────────────────────────────────────────────
  //
  // Le tronc est un trapèze légèrement incliné vers le haut (fût courbé),
  // allant du pied (bas, plus large) à la couronne (haut, plus étroit).
  // En vue isométrique le tronc penche légèrement pour donner l'illusion 3D.
  final trunkH = 18.0 * scale;   // hauteur totale du tronc
  final trunkWBot = 2.8 * scale; // demi-largeur en bas
  final trunkWTop = 1.6 * scale; // demi-largeur en haut

  // Léger tilt pour l'effet iso (le haut du tronc part un peu à droite).
  final tiltX = 2.0 * scale;

  final trunkPath = Path()
    ..moveTo(center.dx - trunkWBot, center.dy)
    ..lineTo(center.dx + trunkWBot, center.dy)
    ..lineTo(center.dx + trunkWTop + tiltX, center.dy - trunkH)
    ..lineTo(center.dx - trunkWTop + tiltX, center.dy - trunkH)
    ..close();

  // Ombré : côté gauche plus sombre pour l'effet 3D.
  canvas.drawPath(
    trunkPath,
    Paint()
      ..color = const Color(0xFF8D6E63).withValues(alpha: alpha)
      ..style = PaintingStyle.fill,
  );

  // Reflet droit du tronc (bande plus claire).
  final trunkHighlight = Path()
    ..moveTo(center.dx + trunkWTop * 0.1 + tiltX, center.dy - trunkH)
    ..lineTo(center.dx + trunkWTop + tiltX, center.dy - trunkH)
    ..lineTo(center.dx + trunkWBot, center.dy)
    ..lineTo(center.dx + trunkWBot * 0.5, center.dy)
    ..close();
  canvas.drawPath(
    trunkHighlight,
    Paint()
      ..color = const Color(0xFFA1887F).withValues(alpha: alpha * 0.6)
      ..style = PaintingStyle.fill,
  );

  // ── Couronne de feuilles ──────────────────────────────────────────────────
  //
  // 5 feuilles rayonnantes dessinées avec des courbes de Bézier.
  // Chaque feuille part de la couronne et se recourbe vers le bas.
  // La disposition est asymétrique pour plus de naturel.

  final crownCenter = Offset(
    center.dx + tiltX,
    center.dy - trunkH - 2.0 * scale,
  );

  // (angle en degrés, longueur relative)
  const leaves = [
    (-80.0, 1.10), // gauche haute
    (-30.0, 1.00), // droite haute
    (10.0,  1.05), // droite
    (150.0, 0.95), // gauche basse
    (220.0, 0.90), // gauche
  ];

  for (final (angle, lenMult) in leaves) {
    _drawLeaf(
      canvas,
      crownCenter,
      angle: angle,
      length: 14.0 * scale * lenMult,
      width: 4.5 * scale,
      alpha: alpha,
    );
  }

  // Petite boule centrale (base des feuilles / régime de noix).
  canvas.drawCircle(
    crownCenter,
    3.2 * scale,
    Paint()
      ..color = const Color(0xFF4E342E).withValues(alpha: alpha)
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    Offset(crownCenter.dx + 0.8 * scale, crownCenter.dy - 0.8 * scale),
    1.4 * scale,
    Paint()
      ..color = const Color(0xFF6D4C41).withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.fill,
  );
}

/// Dessine une feuille de palmier depuis [origin] dans la direction [angle].
///
/// La feuille est une courbe de Bézier quadratique qui se recourbe vers le bas.
void _drawLeaf(
  Canvas canvas,
  Offset origin, {
  required double angle,
  required double length,
  required double width,
  required double alpha,
}) {
  final rad = angle * pi / 180.0;

  // Point d'extrémité de la feuille.
  final tip = Offset(
    origin.dx + cos(rad) * length,
    origin.dy + sin(rad) * length * 0.55, // compression iso
  );

  // Point de contrôle de Bézier : la feuille s'incurve vers le bas.
  final ctrl = Offset(
    origin.dx + cos(rad) * length * 0.55,
    origin.dy + sin(rad) * length * 0.28 + length * 0.18,
  );

  // Vecteur perpendiculaire pour l'épaisseur de la feuille.
  final perpRad = rad + pi / 2;
  final hw = width / 2;
  final perpX = cos(perpRad) * hw;
  final perpY = sin(perpRad) * hw * 0.55;

  // Côté A : bord gauche de la feuille.
  final aPath = Path()
    ..moveTo(origin.dx, origin.dy)
    ..quadraticBezierTo(
      ctrl.dx - perpX * 0.7,
      ctrl.dy - perpY * 0.7,
      tip.dx,
      tip.dy,
    )
    ..quadraticBezierTo(
      ctrl.dx + perpX * 0.5,
      ctrl.dy + perpY * 0.5,
      origin.dx,
      origin.dy,
    );

  // Couleur verte avec légère variation de luminosité selon l'angle.
  // Les feuilles qui pointent vers le "haut" de l'écran (angle ~-90°) sont
  // plus sombres (ombres) ; celles vers le bas sont plus claires (lumière).
  final lightness = (sin(rad) * 0.15).clamp(-0.15, 0.15);
  final green = Color.fromARGB(
    255,
    (0x2E + (lightness * 30).round()).clamp(0, 255),
    (0x7D + (lightness * 50).round()).clamp(0, 255),
    (0x32 + (lightness * 20).round()).clamp(0, 255),
  );

  canvas.drawPath(
    aPath,
    Paint()
      ..color = green.withValues(alpha: alpha)
      ..style = PaintingStyle.fill,
  );

  // Nervure centrale (trait fin plus clair).
  final rib = Path()
    ..moveTo(origin.dx, origin.dy)
    ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);

  canvas.drawPath(
    rib,
    Paint()
      ..color = const Color(0xFF66BB6A).withValues(alpha: alpha * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round,
  );
}
