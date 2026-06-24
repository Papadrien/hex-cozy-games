/// Modèle de données d'une tuile hexagonale — Story 1.3 / 1.10a.
///
/// Une tuile a 6 côtés, chacun avec un [BiomeType].
/// Contrainte : max 3 [BiomeType] différents par tuile.
/// Les biomes sont répartis en arcs contigus (pas de répartition "confetti").
///
/// Story 1.10a — Palmiers :
/// Les tuiles avec des sixièmes [BiomeType.forest] peuvent porter des palmiers
/// ([palms]), générés de manière aléatoire et seédée à la création du pool.
library;

import 'dart:math';

import 'hex_cell.dart';
import 'palm_placement.dart';

export 'palm_placement.dart';

/// Une tuile hexagonale posable sur le plateau.
///
/// [sides] : liste de 6 biomes, indexés sens horaire depuis le nord (index 0 =
/// côté nord, index 1 = nord-est, ..., index 5 = nord-ouest).
///
/// Pour pointy-top en vue isométrique :
///   0 = haut-droit (NE), 1 = droite (E), 2 = bas-droit (SE),
///   3 = bas-gauche (SW), 4 = gauche (W), 5 = haut-gauche (NW)
///
/// [palms] : placements aléatoires de palmiers, uniquement sur les sixièmes
/// dont le biome est [BiomeType.forest]. Vide si aucune forêt sur la tuile.
class HexTile {
  const HexTile({required this.sides, this.palms = const []})
      : assert(sides.length == 6);

  final List<BiomeType> sides;

  /// Palmiers placés sur cette tuile (peut être vide).
  final List<PalmPlacement> palms;

  /// Retourne une copie de la tuile tournée de [steps] * 60° dans le sens
  /// horaire.
  HexTile rotated(int steps) {
    final n = ((steps % 6) + 6) % 6;
    final rotatedSides =
        List<BiomeType>.generate(6, (i) => sides[(i - n + 6) % 6]);
    // Les palmiers suivent la rotation : le sideIndex pivote également.
    final rotatedPalms = palms
        .map((p) => PalmPlacement(
              sideIndex: (p.sideIndex - n + 6) % 6,
              offsetFrac: p.offsetFrac,
              angleFrac: p.angleFrac,
              scaleFrac: p.scaleFrac,
            ))
        .toList();
    return HexTile(sides: rotatedSides, palms: rotatedPalms);
  }

  /// Nombre de [BiomeType] uniques sur cette tuile (toujours ≤ 3).
  int get biomeCount => sides.toSet().length;

  /// Vrai si la tuile contient au moins un sixième forêt avec un palmier.
  bool get hasPalms => palms.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'sides': sides.map((b) => b.name).toList(),
        if (palms.isNotEmpty)
          'palms': palms.map((p) => p.toJson()).toList(),
      };

  factory HexTile.fromJson(Map<String, dynamic> json) => HexTile(
        sides: (json['sides'] as List)
            .map((s) => BiomeType.values.firstWhere((b) => b.name == s))
            .toList(),
        palms: json['palms'] != null
            ? (json['palms'] as List)
                .map((p) => PalmPlacement.fromJson(p as Map<String, dynamic>))
                .toList()
            : const [],
      );
}

// ── Générateur de pool aléatoire (Story 1.9a / 1.10a) ────────────────────────

/// Génère un pool de [count] tuiles aléatoires avec un [Random] seedé,
/// chaque tuile respectant :
///  - max 3 [BiomeType] différents par tuile (contrainte kMaxBiomeTypesPerTile)
///  - biomes en arcs contigus (pas de confetti)
///  - distribution équilibrée des biomes sur l'ensemble du pool
///  - palmiers distribués aléatoirement sur les sixièmes forêt (story 1.10a)
List<HexTile> generateTilePool(int count, Random rng) {
  final biomeUsage = {for (final b in BiomeType.values) b: 0};
  final pool = List.generate(count, (_) => _generateTile(biomeUsage, rng));
  return pool;
}

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

  // Générer les palmiers sur les sixièmes forêt.
  final palms = _generatePalms(sides, rng);

  return HexTile(sides: sides, palms: palms);
}

/// Génère 1 ou 2 palmiers par sixième [BiomeType.forest] de manière aléatoire.
///
/// Règles (story 1.10a) :
///  - 60 % chance d'avoir 1 palmier, 40 % chance d'en avoir 2 par sixième.
///  - Position dans le sixième : distance radiale 0.18–0.42 de hexSize.
///  - Légère variation angulaire (±25°) pour le naturel.
///  - Variation de taille (0.80–1.05).
List<PalmPlacement> _generatePalms(List<BiomeType> sides, Random rng) {
  final result = <PalmPlacement>[];
  for (var i = 0; i < 6; i++) {
    if (sides[i] != BiomeType.forest) continue;
    final count = rng.nextDouble() < 0.60 ? 1 : 2;
    for (var j = 0; j < count; j++) {
      // offsetFrac : position radiale dans le sixième (fraction de hexSize).
      // Pour 2 palmiers, on les sépare un peu pour éviter superposition.
      final baseOffset = 0.20 + rng.nextDouble() * 0.22;
      final jitter = count == 2 ? (j == 0 ? -0.08 : 0.08) : 0.0;

      result.add(PalmPlacement(
        sideIndex: i,
        offsetFrac: (baseOffset + jitter).clamp(0.12, 0.45),
        // angleFrac : variation angulaire ±0.14 tour (±25°) autour du centre du sixième.
        angleFrac: (rng.nextDouble() - 0.5) * 0.28,
        scaleFrac: 0.80 + rng.nextDouble() * 0.25,
        variantIndex: rng.nextInt(2),
      ));
    }
  }
  return result;
}

List<BiomeType> _pickWeightedBiomes(
  int count,
  Map<BiomeType, int> usage,
  Random rng,
) {
  final all = BiomeType.values;
  final minUsage = usage.values.reduce(min);
  final weights = all.map((b) => 1.0 / (1 + usage[b]! - minUsage)).toList();

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
