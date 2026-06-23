/// Pool de tuiles prédéfinies pour les tests — ex-MVP kTilePool.
///
/// Déplacé ici car plus utilisé en production (generateTilePool() est utilisé
/// à la place, story 1.9a).
library;

import 'package:hex_haven/game/hex_cell.dart';
import 'package:hex_haven/game/hex_tile.dart';

final List<HexTile> kTilePool = [
  // ── 1 biome (monochrome) ─────────────────────────────────────────────────

  /// Tuile tout forêt
  HexTile(sides: [
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.forest,
  ]),

  /// Tuile tout eau
  HexTile(sides: [
    BiomeType.water,
    BiomeType.water,
    BiomeType.water,
    BiomeType.water,
    BiomeType.water,
    BiomeType.water,
  ]),

  // ── 2 biomes ─────────────────────────────────────────────────────────────

  /// Forêt 3 / Eau 3
  HexTile(sides: [
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.water,
    BiomeType.water,
    BiomeType.water,
  ]),

  /// Plaine 3 / Village 3
  HexTile(sides: [
    BiomeType.plain,
    BiomeType.plain,
    BiomeType.plain,
    BiomeType.village,
    BiomeType.village,
    BiomeType.village,
  ]),

  /// Montagne 4 / Eau 2
  HexTile(sides: [
    BiomeType.mountain,
    BiomeType.mountain,
    BiomeType.mountain,
    BiomeType.mountain,
    BiomeType.water,
    BiomeType.water,
  ]),

  /// Forêt 4 / Plaine 2
  HexTile(sides: [
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.plain,
    BiomeType.plain,
  ]),

  /// Village 2 / Plaine 4
  HexTile(sides: [
    BiomeType.village,
    BiomeType.village,
    BiomeType.plain,
    BiomeType.plain,
    BiomeType.plain,
    BiomeType.plain,
  ]),

  /// Forêt 3 / Montagne 3
  HexTile(sides: [
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.mountain,
    BiomeType.mountain,
    BiomeType.mountain,
  ]),

  /// Village 3 / Eau 3
  HexTile(sides: [
    BiomeType.village,
    BiomeType.village,
    BiomeType.village,
    BiomeType.water,
    BiomeType.water,
    BiomeType.water,
  ]),

  /// Plaine 3 / Montagne 3
  HexTile(sides: [
    BiomeType.plain,
    BiomeType.plain,
    BiomeType.plain,
    BiomeType.mountain,
    BiomeType.mountain,
    BiomeType.mountain,
  ]),

  // ── 3 biomes (probabilité réduite) ───────────────────────────────────────

  /// Forêt 2 / Eau 2 / Plaine 2
  HexTile(sides: [
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.water,
    BiomeType.water,
    BiomeType.plain,
    BiomeType.plain,
  ]),

  /// Village 1 / Plaine 3 / Eau 2
  HexTile(sides: [
    BiomeType.village,
    BiomeType.plain,
    BiomeType.plain,
    BiomeType.plain,
    BiomeType.water,
    BiomeType.water,
  ]),
];
