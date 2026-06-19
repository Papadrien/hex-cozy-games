/// État de session : pièces et tuiles bonus accumulées — Story 1.6b.
///
/// [coins] et [totalBonusTiles] sont cumulés au fil des placements.
/// [lastReward] garde la dernière récompense pour l'affichage de confirmation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reward_model.dart';

/// État cumulé de la session en cours.
class SessionState {
  const SessionState({
    this.coins = 0,
    this.totalBonusTiles = 0,
    this.lastReward,
  });

  final int coins;
  final int totalBonusTiles;
  final PlacementReward? lastReward;

  SessionState copyWith({
    int? coins,
    int? totalBonusTiles,
    PlacementReward? lastReward,
  }) {
    return SessionState(
      coins: coins ?? this.coins,
      totalBonusTiles: totalBonusTiles ?? this.totalBonusTiles,
      lastReward: lastReward ?? this.lastReward,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  /// Ajoute la récompense [reward] au cumul de la session.
  void addReward(PlacementReward reward) {
    state = SessionState(
      coins: state.coins + reward.bonusTiles,
      totalBonusTiles: state.totalBonusTiles + reward.bonusTiles,
      lastReward: reward,
    );
  }

  /// Efface la dernière récompense affichée (après l'animation de confirmation).
  void clearLastReward() {
    state = state.copyWith(lastReward: null);
  }

  /// Retire [bonusTiles] du cumul de la session (utilisé par le bouton
  /// Annuler pour inverser les récompenses — story 1.6b).
  void removeReward(int bonusTiles) {
    state = SessionState(
      coins: (state.coins - bonusTiles).clamp(0, double.infinity).toInt(),
      totalBonusTiles:
          (state.totalBonusTiles - bonusTiles).clamp(0, double.infinity).toInt(),
      lastReward: null,
    );
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
