/// Modèle de données d'une tuile hexagonale — Story 1.3.
///
/// Une tuile a 6 côtés, chacun avec un [BiomeType].
/// Contrainte : max 3 [BiomeType] différents par tuile.
/// Les biomes sont répartis en arcs contigus (pas de répartition "confetti").
library;

import 'dart:math';

import '../core/constants.dart';
import 'hex_cell.dart';

/// Une tuile hexagonale posable sur le plateau.
class HexTile {
  const HexTile({required this.sides, this.isBonus = false})
      : assert(sides.length == 6);

  final List<BiomeType> sides;

  /// Vrai si cette tuile provient d'une récompense (tuile bonus gagnée en
  /// jeu, ex. Combo+) plutôt que du tirage normal de la pile — sert
  /// uniquement à déclencher un retour haptique dédié lorsqu'elle devient
  /// visible dans la pile (voir [TileStackHud]), sans affecter le gameplay.
  final bool isBonus;

  HexTile rotated(int steps) {
    final n = ((steps % 6) + 6) % 6;
    final rotatedSides =
        List<BiomeType>.generate(6, (i) => sides[(i - n + 6) % 6]);
    return HexTile(sides: rotatedSides, isBonus: isBonus);
  }

  HexTile copyWith({bool? isBonus}) =>
      HexTile(sides: sides, isBonus: isBonus ?? this.isBonus);

  int get biomeCount => sides.toSet().length;

  Map<String, dynamic> toJson() => {
        'sides': sides.map((b) => b.name).toList(),
        'isBonus': isBonus,
      };

  factory HexTile.fromJson(Map<String, dynamic> json) => HexTile(
        sides: (json['sides'] as List).map((s) {
          return BiomeType.values.firstWhere(
            (b) => b.name == s,
            orElse: () => BiomeType.forest,
          );
        }).toList(),
        isBonus: json['isBonus'] as bool? ?? false,
      );
}

// ── Générateur de pool aléatoire ──────────────────────────────────────────────

List<HexTile> generateTilePool(
  int count,
  Random rng, {
  BiomeType? excludeBiome,
  int excludeDuration = 0,
  int startPosition = 1,
}) {
  final biomeUsage = {for (final b in BiomeType.values) b: 0};
  return List.generate(count, (i) {
    final useExclusion = excludeBiome != null && i < excludeDuration;
    final allowedBiomes = unlockedBiomesAt(startPosition + i);
    return _generateTile(
      biomeUsage,
      rng,
      exclude: useExclusion ? excludeBiome : null,
      allowedBiomes: allowedBiomes,
    );
  });
}

HexTile _generateTile(
  Map<BiomeType, int> biomeUsage,
  Random rng, {
  BiomeType? exclude,
  required List<BiomeType> allowedBiomes,
}) {
  final roll = rng.nextDouble();
  final biomeCount =
      min(roll < 0.20 ? 1 : (roll < 0.80 ? 2 : 3), allowedBiomes.length);
  final biomes = _pickWeightedBiomes(
    biomeCount,
    biomeUsage,
    rng,
    exclude: exclude,
    allowedBiomes: allowedBiomes,
  );

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
  Random rng, {
  BiomeType? exclude,
  required List<BiomeType> allowedBiomes,
}) {
  final all = allowedBiomes;
  // La normalisation par minUsage ne doit porter que sur les biomes
  // actuellement débloqués : sinon les couleurs bonus pas encore
  // débloquées (usage toujours à 0) fausseraient la pondération relative
  // des biomes déjà en jeu.
  final minUsage = all.map((b) => usage[b]!).reduce(min);
  final weights = all.map((b) {
    if (b == exclude) return 0.0;
    return 1.0 / (1 + usage[b]! - minUsage);
  }).toList();

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

List<int> _distribute3(Random rng) {
  while (true) {
    final cut1 = 1 + rng.nextInt(4);
    final cut2 = 1 + rng.nextInt(4);
    if (cut1 == cut2) continue;
    final a = min(cut1, cut2);
    final b = (cut1 - cut2).abs();
    final c = 6 - a - b;
    if (a >= 1 && b >= 1 && c >= 1) return [a, b, c]..shuffle(rng);
  }
}
