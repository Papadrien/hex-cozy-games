/// Rendu procédural des textures de tuiles hexagonales — DA Story refonte.
///
/// Voronoï seedé → biome dominant au centre, biomes minoritaires en périphérie.
/// Cache : chaque combinaison de biomes est rasterisée une seule fois.
library;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'hex_cell.dart';

// ── Résolution de rasterisation ───────────────────────────────────────────

const int kTextureSize = 96;

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

// ── Cache global ──────────────────────────────────────────────────────────

final Map<String, ui.Picture> _textureCache = {};

void clearTextureCache() => _textureCache.clear();

// ── Point d'entrée public ─────────────────────────────────────────────────

void paintBiomeTexture({
  required ui.Canvas canvas,
  required ui.Path hexPath,
  required List<BiomeType> sides,
  required double hexSize,
  required int seed,
  double alpha = 1.0,
}) {
  final cacheKey = _cacheKey(sides, hexSize);
  final picture = _textureCache.putIfAbsent(
    cacheKey,
    () => _buildPicture(sides),
  );

  final tileW = sqrt(3) * hexSize;
  final tileH = 2 * hexSize;
  final scale = max(tileW, tileH) / kTextureSize;

  canvas.save();
  canvas.clipPath(hexPath);
  canvas.scale(scale);
  canvas.translate(-tileW / (2 * scale), -tileH / (2 * scale));
  canvas.drawPicture(picture);
  canvas.restore();

  // Détails de surface (non cachés, seedés par position).
  canvas.save();
  canvas.clipPath(hexPath);
  _paintSurfaceDetails(canvas, sides, hexSize, seed, alpha);
  canvas.restore();
}

// ── Clé de cache ──────────────────────────────────────────────────────────

String _cacheKey(List<BiomeType> sides, double hexSize) =>
    '${sides.map((b) => b.index).join('_')}_${hexSize.round()}';

// ── Construction du Picture Voronoï (batch rectangles RLE) ───────────────

ui.Picture _buildPicture(List<BiomeType> sides) {
  final rng = Random(_sidesHash(sides));
  final seeds = _generateSeeds(sides, rng);
  final hash = _sidesHash(sides);

  final recorder = ui.PictureRecorder();
  final c = ui.Canvas(recorder,
      ui.Rect.fromLTWH(0, 0, kTextureSize.toDouble(), kTextureSize.toDouble()));

  final half = kTextureSize / 2.0;

  for (var py = 0; py < kTextureSize; py++) {
    // RLE horizontal : on regroupe les pixels consécutifs de même biome+bruit.
    var runStart = 0;
    var runBiome = _nearest(0, py, half, seeds, sides[0]);
    var runNoise = _noise(0, py, hash);

    for (var px = 1; px <= kTextureSize; px++) {
      final biome = px < kTextureSize ? _nearest(px, py, half, seeds, sides[0]) : null;
      final noise = px < kTextureSize ? _noise(px, py, hash) : 0.0;

      if (biome != runBiome || (noise - runNoise).abs() > 0.15 || px == kTextureSize) {
        c.drawRect(
          ui.Rect.fromLTWH(runStart.toDouble(), py.toDouble(), (px - runStart).toDouble(), 1),
          ui.Paint()..color = _lerpColor(runBiome, runNoise),
        );
        runStart = px;
        if (px < kTextureSize) { runBiome = biome!; runNoise = noise; }
      }
    }
  }

  return recorder.endRecording();
}

// ── Graines Voronoï ───────────────────────────────────────────────────────

class _Seed {
  const _Seed(this.x, this.y, this.biome);
  final double x, y; // [-1, 1]
  final BiomeType biome;
}

List<_Seed> _generateSeeds(List<BiomeType> sides, Random rng) {
  final freq = <BiomeType, int>{};
  for (final b in sides) freq[b] = (freq[b] ?? 0) + 1;
  final maxFreq = freq.values.reduce(max);

  final seeds = <_Seed>[];
  freq.forEach((biome, count) {
    final dominant = count == maxFreq;
    final n = dominant ? max(5, count * 2) : count + 1;
    for (var i = 0; i < n; i++) {
      if (dominant) {
        seeds.add(_Seed(
          (rng.nextDouble() - 0.5) * 0.8,
          (rng.nextDouble() - 0.5) * 0.8,
          biome,
        ));
      } else {
        final arc = _arcAngle(biome, sides);
        final r = 0.5 + rng.nextDouble() * 0.4;
        seeds.add(_Seed(
          cos(arc) * r + (rng.nextDouble() - 0.5) * 0.25,
          sin(arc) * r + (rng.nextDouble() - 0.5) * 0.25,
          biome,
        ));
      }
    }
  });
  return seeds;
}

double _arcAngle(BiomeType biome, List<BiomeType> sides) {
  double sinSum = 0, cosSum = 0;
  int count = 0;
  for (var i = 0; i < 6; i++) {
    if (sides[i] == biome) {
      final a = (60.0 * i - 90.0) * pi / 180.0;
      sinSum += sin(a); cosSum += cos(a); count++;
    }
  }
  return count == 0 ? 0 : atan2(sinSum / count, cosSum / count);
}

BiomeType _nearest(int px, int py, double half, List<_Seed> seeds, BiomeType fallback) {
  final nx = (px - half) / half;
  final ny = (py - half) / half;
  var best = double.infinity;
  var biome = fallback;
  for (final s in seeds) {
    final d = (nx - s.x) * (nx - s.x) + (ny - s.y) * (ny - s.y);
    if (d < best) { best = d; biome = s.biome; }
  }
  return biome;
}

// ── Bruit + couleur ───────────────────────────────────────────────────────

double _noise(int px, int py, int seed) {
  var h = seed ^ (px * 374761393) ^ (py * 668265263);
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return ((h & 0x7FFFFFFF) % 1000) / 1000.0;
}

Color _lerpColor(BiomeType b, double t) =>
    Color.lerp(b._dark, b._light, 0.40 + t * 0.30)!;

int _sidesHash(List<BiomeType> sides) {
  var h = 0;
  for (var i = 0; i < sides.length; i++) h ^= (sides[i].index + 1) * (i * 1000003 + 1);
  return h.abs();
}

// ── Détails de surface par biome ─────────────────────────────────────────

void _paintSurfaceDetails(
  ui.Canvas canvas,
  List<BiomeType> sides,
  double hexSize,
  int seed,
  double alpha,
) {
  final rng = Random(seed);
  final present = sides.toSet();
  final w = sqrt(3) * hexSize;
  final h = 2 * hexSize;

  if (present.contains(BiomeType.water))    _water(canvas, w, h, rng, alpha);
  if (present.contains(BiomeType.forest))   _forest(canvas, hexSize, rng, alpha);
  if (present.contains(BiomeType.plain))    _plain(canvas, w, h, rng, alpha);
  if (present.contains(BiomeType.village))  _village(canvas, hexSize, rng, alpha);
  if (present.contains(BiomeType.mountain)) _mountain(canvas, hexSize, rng, alpha);
}

void _water(ui.Canvas c, double w, double h, Random rng, double alpha) {
  final p = ui.Paint()
    ..color = const Color(0xFF80DEEA).withValues(alpha: alpha * 0.38)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeCap = ui.StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    final baseY = -h * 0.15 + i * h * 0.18 + (rng.nextDouble() - 0.5) * 8;
    final amp   = 1.8 + rng.nextDouble() * 1.2;
    final freq  = 0.12 + rng.nextDouble() * 0.06;
    final phase = rng.nextDouble() * pi * 2;
    final path  = ui.Path();
    var first   = true;
    for (var px = -w / 2; px <= w / 2; px += 2) {
      final y = baseY + sin(px * freq + phase) * amp;
      if (first) { path.moveTo(px, y); first = false; } else path.lineTo(px, y);
    }
    c.drawPath(path, p);
  }
}

void _forest(ui.Canvas c, double r, Random rng, double alpha) {
  final p = ui.Paint()
    ..color = const Color(0xFF1B5E20).withValues(alpha: alpha * 0.55);
  for (var i = 0; i < 4 + rng.nextInt(3); i++) {
    final angle = rng.nextDouble() * pi * 2;
    final dist  = rng.nextDouble() * r * 0.55;
    c.drawCircle(
      ui.Offset(cos(angle) * dist, sin(angle) * dist),
      3.5 + rng.nextDouble() * 2.5,
      p,
    );
  }
}

void _plain(ui.Canvas c, double w, double h, Random rng, double alpha) {
  final p = ui.Paint()
    ..color = const Color(0xFF9CCC65).withValues(alpha: alpha * 0.30)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..strokeCap = ui.StrokeCap.round;
  for (var i = 0; i < 6 + rng.nextInt(5); i++) {
    final x = (rng.nextDouble() - 0.5) * w * 0.7;
    final y = (rng.nextDouble() - 0.5) * h * 0.5;
    final l = 3.0 + rng.nextDouble() * 3.0;
    c.drawLine(ui.Offset(x, y), ui.Offset(x + (rng.nextDouble() - 0.5) * 2, y - l), p);
  }
}

void _village(ui.Canvas c, double r, Random rng, double alpha) {
  for (var i = 0; i < 2 + rng.nextInt(2); i++) {
    final angle = rng.nextDouble() * pi * 2;
    final dist  = rng.nextDouble() * r * 0.40;
    final x = cos(angle) * dist;
    final y = sin(angle) * dist;
    c.drawRect(
      ui.Rect.fromCenter(center: ui.Offset(x, y), width: 5, height: 4),
      ui.Paint()..color = const Color(0xFFBF8C50).withValues(alpha: alpha * 0.70),
    );
    c.drawPath(
      ui.Path()
        ..moveTo(x - 3.5, y - 2)
        ..lineTo(x, y - 5.5)
        ..lineTo(x + 3.5, y - 2)
        ..close(),
      ui.Paint()..color = const Color(0xFF8D4E2A).withValues(alpha: alpha * 0.75),
    );
  }
}

void _mountain(ui.Canvas c, double r, Random rng, double alpha) {
  for (var i = 0; i < 1 + rng.nextInt(2); i++) {
    final angle = rng.nextDouble() * pi * 2;
    final dist  = rng.nextDouble() * r * 0.45;
    final bx = cos(angle) * dist;
    final by = sin(angle) * dist;
    final h  = 8.0 + rng.nextDouble() * 5.0;
    final w  = 7.0 + rng.nextDouble() * 4.0;
    final lean = (rng.nextDouble() - 0.5) * 3.0;
    c.drawPath(
      ui.Path()
        ..moveTo(bx - w / 2, by)
        ..lineTo(bx - w / 4 + lean, by - h)
        ..lineTo(bx + w / 4 + lean, by - h * 0.85)
        ..lineTo(bx + w / 2, by - h * 0.4)
        ..lineTo(bx + w / 2, by)
        ..close(),
      ui.Paint()..color = const Color(0xFF455A64).withValues(alpha: alpha * 0.65),
    );
    c.drawLine(
      ui.Offset(bx - w / 4 + lean - 1, by - h + 1),
      ui.Offset(bx + w / 4 + lean + 1, by - h * 0.80),
      ui.Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.55)
        ..strokeWidth = 1.2,
    );
  }
}
