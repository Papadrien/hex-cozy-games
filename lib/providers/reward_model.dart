/// Modèle partagé pour les récompenses de placement — Stories 1.6a / 1.6b.
library;

/// Récompense calculée pour un placement : nombre de côtés connectés et tuiles
/// bonus correspondantes (selon table de la story 1.6b).
///
/// Table de bonus (tuiles bonus) :
///  - 3 côtés connectés → +1 tuile bonus
///  - 4 côtés connectés → +2 tuiles bonus
///  - 5 côtés connectés → +5 tuiles bonus
///  - 6 côtés connectés → +10 tuiles bonus
/// Les pièces gagnées = côtés connectés + tuiles bonus.
class PlacementReward {
  const PlacementReward({
    required this.connectedSides,
    required this.bonusTiles,
  });

  final List<int> connectedSides;
  final int bonusTiles;
}
