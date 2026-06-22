/// Modèle de données d'une tuile hexagonale — Story 1.3.
///
/// Une tuile a 6 côtés, chacun avec un [BiomeType].
/// Contrainte : max 3 [BiomeType] différents par tuile.
/// Les biomes sont répartis en arcs contigus (pas de répartition "confetti").
library;

import 'dart:math';

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

  Map<String, dynamic> toJson() => {
        'sides': sides.map((b) => b.name).toList(),
      };

  factory HexTile.fromJson(Map<String, dynamic> json) => HexTile(
        sides: (json['sides'] as List)
            .map((s) => BiomeType.values.firstWhere((b) => b.name == s))
            .toList(),
      );
}

// ── Générateur de pool aléatoire (Story 1.9a) ────────────────────────────────

/// Génère un pool de [count] tuiles aléatoires avec un [Random] seedé,
/// chaque tuile respectant :
///  - max 3 [BiomeType] différents par tuile (contrainte kMaxBiomeTypesPerTile)
///  - biomes en arcs contigus (pas de confetti)
///  - distribution équilibrée des biomes sur l'ensemble du pool
///
/// Poids par biome (île paradisiaque) :
///  - plaine 25 %, mer 20 %, plage 15 %, champ fleurs 15 %,
///    mangrove 12 %, montagne 8 %, village 5 %
List<HexTile> generateTilePool(int count, Random rng) {
  final biomeUsage = {for (final b in BiomeType.values) b: 0};
  final pool = List.generate(count, (_) => _generateTile(biomeUsage, rng));
  return pool;
}

Map<BiomeType, double> get _kBiomeWeights => const {
      BiomeType.plain: 25.0,
      BiomeType.water: 20.0,
      BiomeType.beach: 15.0,
      BiomeType.flowerField: 15.0,
      BiomeType.forest: 12.0,
      BiomeType.mountain: 8.0,
      BiomeType.village: 5.0,
    };

/// Distribution des types de tuiles : 20 % 1-biome, 60 % 2-biomes, 20 % 3-biomes
/// (favorise les amas organiques — Story 1.9b).
HexTile _generateTile(Map<BiomeType, int> biomeUsage, Random rng) {
  final roll = rng.nextDouble();
  final biomeCount = roll < 0.20 ? 1 : (roll < 0.80 ? 2 : 3);

  final biomes = _pickWeightedBiomes(biomeCount, biomeUsage, rng);

  final List<BiomeType> sides;
  if (biomeCount == 1) {
    sides = List.filled(6, biomes[0]);
  } else if (biomeCount == 2) {
    final split = 1 + rng.nextInt(5);
    sides = [
      ...List.filled(split, biomes[0]),
      ...List.filled(6 - split, biomes[1]),
    ];
  } else {
    final counts = _distribute3(rng);
    sides = [
      ...List.filled(counts[0], biomes[0]),
      ...List.filled(counts[1], biomes[1]),
      ...List.filled(counts[2], biomes[2]),
    ];
  }

  for (final b in biomes) {
    biomeUsage[b] = biomeUsage[b]! + 1;
  }

  return HexTile(sides: sides);
}

List<BiomeType> _pickWeightedBiomes(
  int count,
  Map<BiomeType, int> usage,
  Random rng,
) {
  final all = BiomeType.values;
  // Poids fixes inspirés de la répartition naturelle d'une île.
  final baseWeights = all.map((b) => _kBiomeWeights[b]!).toList();

  // Booster léger pour les biomes sous-utilisés (évite la famine).
  final minUsage = usage.values.reduce(min);
  final boost = all.map((b) => 1.0 / (1 + usage[b]! - minUsage)).toList();

  final weights = List<double>.generate(
    all.length,
    (i) => baseWeights[i] * boost[i],
  );

  final selected = <BiomeType>[];
  for (var i = 0; i < count; i++) {
    final candidates = <int>[];
    final candidateWeights = <double>[];
    for (var j = 0; j < all.length; j++) {
      if (!selected.contains(all[j])) {
        candidates.add(j);
        candidateWeights.add(weights[j]);
      }
    }
    final total = candidateWeights.fold(0.0, (a, b) => a + b);
    var r = rng.nextDouble() * total;
    for (var k = 0; k < candidates.length; k++) {
      r -= candidateWeights[k];
      if (r <= 0) {
        selected.add(all[candidates[k]]);
        break;
      }
    }
  }
  return selected;
}

/// Distribue 6 en 3 entiers positifs (pour 3 biomes contigus).
List<int> _distribute3(Random rng) {
  final cut1 = 1 + rng.nextInt(4);
  var cut2 = 1 + rng.nextInt(4);
  while (cut2 == cut1) {
    cut2 = 1 + rng.nextInt(4);
  }
  final a = cut1 < cut2 ? cut1 : cut2;
  final b = cut1 < cut2 ? cut2 - cut1 : cut1 - cut2;
  final c = 6 - a - b;
  return [a, b, c]..shuffle(rng);
}
