/// État de session : pièces et tuiles bonus accumulées — Story 1.6b / 1.7a.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'reward_model.dart';

part 'session_provider.g.dart';

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

@Riverpod(keepAlive: true)
class Session extends _$Session {
  @override
  SessionState build() => const SessionState();

  /// Ajoute la récompense [reward] au cumul de la session.
  /// Les pièces = côtés connectés + tuiles bonus (1 côté=1 pièce,
  /// 2 côtés=2, 3 côtés=3+1=4, 4 côtés=4+2=6, etc.)
  void addReward(PlacementReward reward) {
    state = SessionState(
      coins: state.coins + reward.connectedSides.length + reward.bonusTiles,
      totalBonusTiles: state.totalBonusTiles + reward.bonusTiles,
      lastReward: reward,
    );
  }

  /// Efface la dernière récompense affichée (après l'animation de confirmation).
  void clearLastReward() {
    state = state.copyWith(lastReward: null);
  }

  /// Retire [coins] et [bonusTiles] du cumul de la session (utilisé par le
  /// bouton Annuler pour inverser les récompenses — story 1.6b / 1.7c).
  void removeReward(int coins, int bonusTiles) {
    state = SessionState(
      coins: (state.coins - coins).clamp(0, double.infinity).toInt(),
      totalBonusTiles:
          (state.totalBonusTiles - bonusTiles).clamp(0, double.infinity).toInt(),
      lastReward: null,
    );
  }

  /// Réinitialise l'état de session à zéro (utilisé pour nouvelle partie).
  void reset() {
    state = const SessionState();
  }

  /// Remplace l'état de session (restauration de partie).
  void restore(SessionState restored) {
    state = restored;
  }
}

/// Compteur de pièces de la session en cours — Story 2.2a.
///
/// Simple projection de [sessionProvider] : expose uniquement le total de
/// pièces, mis à jour en temps réel à chaque [Session.addReward] /
/// [Session.removeReward] / [Session.reset] / [Session.restore]. L'affichage
/// UI dédié et la persistance de fin de partie sont traités en story 2.2b.
final sessionCoinsProvider = Provider<int>((ref) {
  return ref.watch(sessionProvider.select((s) => s.coins));
});
