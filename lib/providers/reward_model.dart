/// Modèle partagé pour les récompenses de placement — Stories 1.6a / 1.6b.
library;

/// Récompense calculée pour un placement : nombre de côtés connectés et tuiles
/// bonus correspondantes (selon table de la story 1.6b).
///
/// Table de bonus (tuiles et pièces — même table) :
///  - 3 côtés connectés → +1 tuile, +1 pièce
///  - 4 côtés connectés → +2 tuiles, +2 pièces
///  - 5 côtés connectés → +5 tuiles, +5 pièces
///  - 6 côtés connectés → +10 tuiles, +10 pièces
class PlacementReward {
  const PlacementReward({
    required this.connectedSides,
    required this.bonusTiles,
  });

  final List<int> connectedSides;
  final int bonusTiles;
}
