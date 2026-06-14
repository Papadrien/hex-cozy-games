import 'dart:math';
import 'package:flutter/material.dart';

enum Biome {
  forest,
  grassland,
  water,
  village,
  desert,
  mountain,
}

extension BiomeExt on Biome {
  Color get topColor {
    switch (this) {
      case Biome.forest:
        return const Color(0xFF3A7D44);
      case Biome.grassland:
        return const Color(0xFF8CBF5A);
      case Biome.water:
        return const Color(0xFF5BA3C9);
      case Biome.village:
        return const Color(0xFFD4956A);
      case Biome.desert:
        return const Color(0xFFE8C87A);
      case Biome.mountain:
        return const Color(0xFF8E8E8E);
    }
  }

  Color get sideColorLeft {
    switch (this) {
      case Biome.forest:
        return const Color(0xFF2A5E32);
      case Biome.grassland:
        return const Color(0xFF6A9940);
      case Biome.water:
        return const Color(0xFF3A7FA8);
      case Biome.village:
        return const Color(0xFFAA6F45);
      case Biome.desert:
        return const Color(0xFFBE9E55);
      case Biome.mountain:
        return const Color(0xFF5E5E5E);
    }
  }

  Color get sideColorRight {
    switch (this) {
      case Biome.forest:
        return const Color(0xFF1E4425);
      case Biome.grassland:
        return const Color(0xFF507730);
      case Biome.water:
        return const Color(0xFF2A6088);
      case Biome.village:
        return const Color(0xFF8A5230);
      case Biome.desert:
        return const Color(0xFF9E7E3A);
      case Biome.mountain:
        return const Color(0xFF3E3E3E);
    }
  }

  String get emoji {
    switch (this) {
      case Biome.forest:
        return '🌲';
      case Biome.grassland:
        return '🌿';
      case Biome.water:
        return '💧';
      case Biome.village:
        return '🏠';
      case Biome.desert:
        return '🏜';
      case Biome.mountain:
        return '⛰';
    }
  }
}

// Axial hex coordinates
class HexCoord {
  final int q;
  final int r;
  const HexCoord(this.q, this.r);

  int get s => -q - r;

  @override
  bool operator ==(Object other) =>
      other is HexCoord && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);

  List<HexCoord> get neighbors => [
        HexCoord(q + 1, r),
        HexCoord(q + 1, r - 1),
        HexCoord(q, r - 1),
        HexCoord(q - 1, r),
        HexCoord(q - 1, r + 1),
        HexCoord(q, r + 1),
      ];

  Offset toPixel(double size) {
    final x = size * (3 / 2 * q);
    final y = size * (sqrt(3) / 2 * q + sqrt(3) * r);
    return Offset(x, y);
  }
}

class HexTile {
  final Biome biome;
  final List<Biome> edges; // 6 edges, one per neighbor direction

  HexTile({required this.biome, required this.edges});

  factory HexTile.uniform(Biome biome) {
    return HexTile(biome: biome, edges: List.filled(6, biome));
  }

  factory HexTile.random(Random rng) {
    final center = Biome.values[rng.nextInt(Biome.values.length)];
    return HexTile.uniform(center);
  }
}

// Decorative elements drawn on top of a biome
class TileDecoration {
  final String type; // 'tree', 'house', 'rock', 'wave', 'cactus', 'peak'
  final Offset localOffset; // fraction of tile size
  final double scale;

  const TileDecoration({
    required this.type,
    required this.localOffset,
    this.scale = 1.0,
  });
}

List<TileDecoration> decorationsFor(Biome biome, Random rng) {
  switch (biome) {
    case Biome.forest:
      return [
        TileDecoration(
            type: 'tree',
            localOffset: Offset(rng.nextDouble() * 0.3 - 0.15,
                rng.nextDouble() * 0.2 - 0.1)),
        TileDecoration(
            type: 'tree',
            localOffset: Offset(rng.nextDouble() * 0.3 + 0.1,
                rng.nextDouble() * 0.2 - 0.15),
            scale: 0.8),
      ];
    case Biome.village:
      return [
        TileDecoration(
            type: 'house',
            localOffset: Offset(rng.nextDouble() * 0.2 - 0.1, -0.05)),
      ];
    case Biome.mountain:
      return [
        TileDecoration(type: 'peak', localOffset: const Offset(0, -0.1)),
      ];
    case Biome.water:
      return [
        TileDecoration(type: 'wave', localOffset: const Offset(-0.1, 0.05)),
        TileDecoration(type: 'wave', localOffset: const Offset(0.1, -0.05),
            scale: 0.7),
      ];
    case Biome.desert:
      return [
        TileDecoration(type: 'cactus', localOffset: const Offset(0, -0.1)),
      ];
    case Biome.grassland:
      return [
        TileDecoration(
            type: 'bush',
            localOffset: Offset(rng.nextDouble() * 0.2 - 0.1,
                rng.nextDouble() * 0.1 - 0.05)),
      ];
  }
}
