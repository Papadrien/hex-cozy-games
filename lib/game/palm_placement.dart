/// Modèle de données décrivant la position d'un palmier sur une tuile.
///
/// Chaque [PalmPlacement] définit :
///  - [sideIndex]    : quel sixième de l'hexagone (0–5) porte le palmier.
///  - [offsetFrac]   : distance radiale depuis le centre (fraction de hexSize).
///  - [angleFrac]    : variation angulaire (fraction de tour).
///  - [scaleFrac]    : variation de taille (0.8–1.1).
///  - [variantIndex] : quelle variante de sprite utiliser (0 = palm_tree_1, 1 = palm_tree_2).
library;

/// Placement d'un palmier dans un sixième de l'hexagone.
class PalmPlacement {
  const PalmPlacement({
    required this.sideIndex,
    required this.offsetFrac,
    required this.angleFrac,
    required this.scaleFrac,
    this.variantIndex = 0,
  });

  /// Sixième de l'hexagone (0–5) sur lequel est posé le palmier.
  final int sideIndex;

  /// Distance depuis le centre du sixième en fraction de hexSize (0.0–1.0).
  final double offsetFrac;

  /// Variation angulaire en fraction de tour complet (−0.5 à 0.5).
  final double angleFrac;

  /// Facteur d'échelle relatif (typiquement 0.8–1.1).
  final double scaleFrac;

  /// Index de la variante sprite : 0 = palm_tree_1.png, 1 = palm_tree_2.png.
  final int variantIndex;

  Map<String, dynamic> toJson() => {
        's': sideIndex,
        'o': offsetFrac,
        'a': angleFrac,
        'sc': scaleFrac,
        'v': variantIndex,
      };

  factory PalmPlacement.fromJson(Map<String, dynamic> json) => PalmPlacement(
        sideIndex: json['s'] as int,
        offsetFrac: (json['o'] as num).toDouble(),
        angleFrac: (json['a'] as num).toDouble(),
        scaleFrac: (json['sc'] as num).toDouble(),
        variantIndex: (json['v'] as int?) ?? 0,
      );
}
