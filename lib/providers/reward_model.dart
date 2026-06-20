/// Modèle partagé pour les récompenses de placement — Stories 1.6a / 1.6b.
library;

import '../core/constants.dart';

/// Récompense calculée pour un placement : nombre de côtés connectés et tuiles
/// bonus correspondantes (selon table de la story 1.6b, voir [kBonusScale]).
///
/// Table de bonus (tuiles bonus) : voir [kBonusScale] dans core/constants.dart.
/// Les pièces gagnées = côtés connectés + tuiles bonus.
class PlacementReward {
  const PlacementReward({
    required this.connectedSides,
    required this.bonusTiles,
  });

  final List<int> connectedSides;
  final int bonusTiles;
}
