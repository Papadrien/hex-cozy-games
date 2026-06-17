/// Modèle de données d'une cellule hexagonale sur le plateau.
library;

/// Type de biome (utilisé pour la story 1.3 — null pour l'instant).
/// Défini ici pour que le modèle `HexCell` soit complet dès la story 1.2.
enum BiomeType {
  forest,   // vert
  village,  // rouge
  plain,    // jaune
  water,    // bleu
  mountain, // violet
}

/// Cellule hexagonale du plateau.
///
/// [q] et [r] sont les coordonnées axiales.
/// [biome] est null si la cellule est vide (aucune tuile posée).
class HexCell {
  const HexCell({required this.q, required this.r, this.biome});

  final int q;
  final int r;
  final BiomeType? biome;

  /// Retourne une copie avec le biome modifié.
  HexCell copyWith({BiomeType? biome}) => HexCell(
        q: q,
        r: r,
        biome: biome ?? this.biome,
      );

  @override
  bool operator ==(Object other) =>
      other is HexCell && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);
}
