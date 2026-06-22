/// Modèle de données d'une cellule hexagonale sur le plateau.
library;

/// Type de biome — thème île paradisiaque (refonte graphique).
enum BiomeType {
  plain,        // plaine : herbe claire tropicale
  flowerField,  // champ de fleurs : rose/mauve
  forest,       // mangrove : vert foncé
  mountain,     // montagne volcanique : roche noire + lave
  beach,        // plage : sable blanc
  water,        // mer : turquoise
  village,      // village sur pilotis : bois chaud
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

  static const _sentinel = Object();

  /// Retourne une copie avec le biome modifié.
  /// Passez `biome: null` pour effacer le biome.
  HexCell copyWith({Object? biome = _sentinel}) => HexCell(
        q: q,
        r: r,
        biome: biome == _sentinel ? this.biome : biome as BiomeType?,
      );

  @override
  bool operator ==(Object other) =>
      other is HexCell && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);
}
