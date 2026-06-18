/// Modèle de données d'une tuile hexagonale — Story 1.3.
///
/// Une tuile a 6 côtés, chacun avec un [BiomeType].
/// Contrainte : max 3 [BiomeType] différents par tuile.
/// Les biomes sont répartis en arcs contigus (pas de répartition "confetti").
library;

import 'hex_cell.dart';

/// Une tuile hexagonale posable sur le plateau.
///
/// [sides] : liste de 6 biomes, indexés sens horaire depuis le nord (index 0 =
/// côté nord, index 1 = nord-est, ..., index 5 = nord-ouest).
///
/// Pour pointy-top en vue isométrique :
///   0 = haut-droit (NE), 1 = droite (E), 2 = bas-droit (SE),
///   3 = bas-gauche (SW), 4 = gauche (W), 5 = haut-gauche (NW)
class HexTile {
  const HexTile({required this.sides}) : assert(sides.length == 6);

  final List<BiomeType> sides;

  /// Retourne une copie de la tuile tournée de [steps] * 60° dans le sens
  /// horaire.
  HexTile rotated(int steps) {
    final n = ((steps % 6) + 6) % 6;
    final rotated = List<BiomeType>.generate(6, (i) => sides[(i - n + 6) % 6]);
    return HexTile(sides: rotated);
  }

  /// Nombre de [BiomeType] uniques sur cette tuile (toujours ≤ 3).
  int get biomeCount => sides.toSet().length;
}

// ── Pool de tuiles MVP ────────────────────────────────────────────────────────

/// Pool fixe de 12 configurations de tuiles pour le MVP.
///
/// Chaque tuile respecte la règle des arcs contigus : les biomes identiques
/// sont groupés en blocs consécutifs (ex : [F,F,F,W,W,W] et non [F,W,F,W,F,W]).
/// Aucune tuile ne dépasse 3 BiomeType différents.
const List<HexTile> kTilePool = [
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

  // ── 2 biomes (moitié-moitié) ─────────────────────────────────────────────

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

  // ── 3 biomes ─────────────────────────────────────────────────────────────

  /// Forêt 2 / Eau 2 / Plaine 2
  HexTile(sides: [
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.water,
    BiomeType.water,
    BiomeType.plain,
    BiomeType.plain,
  ]),

  /// Montagne 2 / Forêt 3 / Plaine 1
  HexTile(sides: [
    BiomeType.mountain,
    BiomeType.mountain,
    BiomeType.forest,
    BiomeType.forest,
    BiomeType.forest,
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

  /// Eau 3 / Montagne 2 / Forêt 1
  HexTile(sides: [
    BiomeType.water,
    BiomeType.water,
    BiomeType.water,
    BiomeType.mountain,
    BiomeType.mountain,
    BiomeType.forest,
  ]),

  /// Forêt 1 / Village 2 / Plaine 3
  HexTile(sides: [
    BiomeType.forest,
    BiomeType.village,
    BiomeType.village,
    BiomeType.plain,
    BiomeType.plain,
    BiomeType.plain,
  ]),
];
