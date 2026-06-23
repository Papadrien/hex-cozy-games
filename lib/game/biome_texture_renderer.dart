/// Rendu procédural des textures de tuiles hexagonales — v4.
///
/// Approche : secteurs vectoriels.
/// On trace 6 paths de secteur (60° chacun) en coordonnées locales
/// (centrées sur l'origine), chacun rempli de la couleur du biome de ce côté.
/// Pas de rasterisation pixel-par-pixel → pas d'artefacts sub-pixel au zoom.
///
/// Légère irrégularité de frontière : la frontière entre deux secteurs
/// de biome différent est décalée d'un jitter angulaire très faible (±3°),
/// calculé de façon déterministe depuis le hash des sides. Si les deux
/// secteurs ont le même biome, on les fusionne directement.
///
/// Clé de cache : on normalise les sides par rotation canonique (forme
/// cyclique minimale) → deux tuiles de composition identique mais en
/// orientations différentes partagent la même texture. La rotation
/// est appliquée via une transformation canvas (pas en changeant les sides),
/// ce qui élimine le flash lors de la rotation.
library;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'hex_cell.dart';

// ── Palettes biome ────────────────────────────────────────────────────────

extension BiomeBaseColor on BiomeType {
  Color get baseColor {
    switch (this) {
      case BiomeType.water:    return const Color(0xFF29B6C8);
      case BiomeType.plain:    return const Color(0xFF6DBF5A);
      case BiomeType.forest:   return const Color(0xFF2E7D32);
      case BiomeType.village:  return const Color(0xFFD4A96A);
      case BiomeType.mountain: return const Color(0xFF78909C);
    }
  }

  Color get _light {
    switch (this) {
      case BiomeType.water:    return const Color(0xFF4DD0E1);
      case BiomeType.plain:    return const Color(0xFF9CCC65);
      case BiomeType.forest:   return const Color(0xFF388E3C);
      case BiomeType.village:  return const Color(0xFFE8C99A);
      case BiomeType.mountain: return const Color(0xFF90A4AE);
    }
  }

  Color get _dark {
    switch (this) {
      case BiomeType.water:    return const Color(0xFF00838F);
      case BiomeType.plain:    return const Color(0xFF558B2F);
      case BiomeType.forest:   return const Color(0xFF1B5E20);
      case BiomeType.village:  return const Color(0xFFBF8C50);
      case BiomeType.mountain: return const Color(0xFF546E7A);
    }
  }
}

// ── Cache ─────────────────────────────────────────────────────────────────

final Map<String, ui.Picture> _pictureCache = {};

void clearTextureCache() => _pictureCache.clear();

void invalidateTileCache(List<BiomeType> sides, double hexSize) {
  final prefix = _canonicalKey(sides);
  _pictureCache.removeWhere((key, _) => key.startsWith(prefix));
}

// ── Point d'entrée public ─────────────────────────────────────────────────

/// Dessine la texture de la tuile sur [canvas].
///
/// [sides] : les 6 biomes dans l'ordre natif de la tuile.
/// [rotationSteps] : rotation en cours (0–5), appliquée via transformation
///   canvas — NE modifie PAS les sides, donc la clé de cache reste stable.
void paintBiomeTexture({
  required ui.Canvas canvas,
  required ui.Path hexPath,
  required List<BiomeType> sides,
  required double hexSize,
  required int seed,
  int rotationSteps = 0,
  List<BiomeType?> neighborBiomes = const [null, null, null, null, null, null],
  double alpha = 1.0,
}) {
  // La clé de cache utilise les sides dans leur ordre natif (rotation 0).
  // On re-utilisera le même Picture quelle que soit la rotation en cours.
  final cacheKey = '${_canonicalKey(sides)}_${hexSize.round()}';
  final picture = _pictureCache.putIfAbsent(
    cacheKey,
    () => _buildPicture(sides, hexSize),
  );

  // La rotation est appliquée ici en tournant le canvas.
  final rotAngle = rotationSteps * (pi / 3); // 60° par step

  canvas.save();
  canvas.clipPath(hexPath);

  if (alpha < 1.0) {
    canvas.saveLayer(
      null,
      ui.Paint()..color = ui.Color.fromARGB((alpha * 255).round(), 255, 255, 255),
    );
  }

  // On tourne autour du centre (0,0) car hexPath est déjà centré sur l'origine.
  if (rotationSteps != 0) canvas.rotate(rotAngle);

  canvas.drawPicture(picture);

  if (alpha < 1.0) canvas.restore();
  canvas.restore();
}

// ── Clé canonique ─────────────────────────────────────────────────────────

/// Représentation string des sides dans leur ordre natif.
/// On n'utilise PAS la rotation canonique : deux tuiles avec des sides
/// différents en position 0 peuvent avoir la même composition après rotation,
/// mais on accepte les doublons de cache (6 entrées max par composition)
/// plutôt que de complexifier la logique de rotation canvas.
String _canonicalKey(List<BiomeType> sides) =>
    sides.map((b) => b.index).join('_');

// ── Construction du Picture (vectoriel) ───────────────────────────────────

/// Construit un Picture de taille hexSize × hexSize centré sur (0, 0).
/// Les secteurs sont tracés comme des paths de triangles (centre → bord).
ui.Picture _buildPicture(List<BiomeType> sides, double hexSize) {
  final hash = _sidesHash(sides);

  // Jitter angulaire par frontière (entre secteur i et i+1), en radians.
  // Maximum ±3° = ±0.052 rad → frontière légèrement organique mais lisible.
  final jitter = List.generate(6, (i) {
    final h = (hash ^ (i * 2654435761)) & 0x7FFFFFFF;
    return ((h % 1000) / 1000.0 - 0.5) * 2 * (3.0 * pi / 180.0);
  });

  // Angles des 7 points de frontière (en radians, sens trigonométrique).
  // Secteur i va de borderAngle[i] à borderAngle[i+1].
  // Point de départ : -90° (sommet haut) = pointy-top.
  // Sans jitter, les frontières sont à -90°, -30°, 30°, 90°, 150°, 210°.
  final borders = List.generate(7, (i) {
    final base = (i * 60.0 - 90.0) * pi / 180.0;
    // Jitter sur la frontière i (sauf si les deux secteurs adjacents ont
    // le même biome → on ne jitte pas, la frontière est invisible).
    final sA = sides[i % 6];
    final sB = sides[(i + 1) % 6];
    final j = (sA == sB) ? 0.0 : jitter[i % 6];
    return base + j;
  });

  // Rayon de l'hexagone dans le repère du Picture.
  // Le Picture est rendu dans l'espace "hexSize" mais drawPicture est utilisé
  // directement (pas de scale) → on dimensionne pour couvrir la tuile iso.
  // En pratique, hexPath est déjà en coords locales centrées, donc on dessine
  // directement dans ces coords.
  final r = hexSize; // rayon circumscrit

  final recorder = ui.PictureRecorder();
  final c = ui.Canvas(recorder);

  // Regrouper les secteurs consécutifs de même biome en un seul path.
  // On itère sur les 6 secteurs et on fusionne les runs consécutifs.
  int i = 0;
  while (i < 6) {
    final biome = sides[i];
    // Chercher jusqu'où s'étend ce run.
    int j = i + 1;
    while (j < 6 && sides[j] == biome) j++;
    // Le secteur couvre de borders[i] à borders[j].
    _drawSector(c, biome, r, borders[i], borders[j], hash);
    i = j;
  }

  return recorder.endRecording();
}

/// Dessine un secteur "camembert" de [startAngle] à [endAngle]
/// rempli de la couleur du biome [b] + micro-variation de luminosité.
void _drawSector(
  ui.Canvas c,
  BiomeType b,
  double r,
  double startAngle,
  double endAngle,
  int hash,
) {
  // Micro-variation de luminosité : ±3% basée sur le hash + biome.
  final noiseT = ((hash ^ (b.index * 1000003)) & 0x7FFFFFFF) % 1000 / 1000.0;
  final color = Color.lerp(b._dark, b._light, 0.47 + noiseT * 0.06)!;

  // Path : centre → arc de rayon r.
  final path = ui.Path();
  path.moveTo(0, 0);

  // Arc approximé avec plusieurs lignes (précision suffisante).
  final steps = max(3, ((endAngle - startAngle) * r / 4).ceil());
  for (var s = 0; s <= steps; s++) {
    final angle = startAngle + (endAngle - startAngle) * s / steps;
    path.lineTo(r * cos(angle), r * sin(angle));
  }
  path.close();

  c.drawPath(path, ui.Paint()..color = color);
}

// ── Helpers ───────────────────────────────────────────────────────────────

int _sidesHash(List<BiomeType> sides) {
  var h = 0;
  for (var i = 0; i < sides.length; i++) {
    h ^= (sides[i].index + 1) * (i * 1000003 + 1);
  }
  return h.abs();
}
