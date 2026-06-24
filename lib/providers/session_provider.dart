/// État de session : pièces et tuiles bonus accumulées — Story 1.6b / 1.7a.
library;

import 'dart:math';

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
    this.connections3 = 0,
    this.connections4 = 0,
    this.connections5 = 0,
    this.connections6 = 0,
  });

  final int coins;
  final int totalBonusTiles;
  final PlacementReward? lastReward;
  final int connections3;
  final int connections4;
  final int connections5;
  final int connections6;

  /// Sentinel utilisé par [copyWith] pour distinguer "non fourni" de "null".
  static const _sentinel = Object();

  /// Remplace les champs non-null fournis.
  /// Permet de remettre un champ nullable à null :
  /// `copyWith(lastReward: null)` fonctionne correctement.
  SessionState copyWith({
    Object? coins = _sentinel,
    Object? totalBonusTiles = _sentinel,
    Object? lastReward = _sentinel,
    Object? connections3 = _sentinel,
    Object? connections4 = _sentinel,
    Object? connections5 = _sentinel,
    Object? connections6 = _sentinel,
  }) {
    return SessionState(
      coins: coins == _sentinel ? this.coins : coins as int,
      totalBonusTiles: totalBonusTiles == _sentinel
          ? this.totalBonusTiles
          : totalBonusTiles as int,
      lastReward: lastReward == _sentinel
          ? this.lastReward
          : lastReward as PlacementReward?,
      connections3:
          connections3 == _sentinel ? this.connections3 : connections3 as int,
      connections4:
          connections4 == _sentinel ? this.connections4 : connections4 as int,
      connections5:
          connections5 == _sentinel ? this.connections5 : connections5 as int,
      connections6:
          connections6 == _sentinel ? this.connections6 : connections6 as int,
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
  ///
  /// Si [forcedCoins] est fourni (Story 2.8b), il remplace le calcul par
  /// défaut pour appliquer les bonus d'améliorations (multiplicateur, %).
  void addReward(PlacementReward reward, {int? forcedCoins}) {
    final c = reward.connectedSides.length;
    state = SessionState(
      coins: state.coins + (forcedCoins ?? c + reward.bonusTiles),
      totalBonusTiles: state.totalBonusTiles + reward.bonusTiles,
      lastReward: reward,
      connections3: state.connections3 + (c == 3 ? 1 : 0),
      connections4: state.connections4 + (c == 4 ? 1 : 0),
      connections5: state.connections5 + (c == 5 ? 1 : 0),
      connections6: state.connections6 + (c == 6 ? 1 : 0),
    );
  }

  /// Efface la dernière récompense affichée (après l'animation de confirmation).
  void clearLastReward() {
    state = state.copyWith(lastReward: null);
  }

  /// Retire [coins] et [bonusTiles] du cumul de la session (utilisé par le
  /// bouton Annuler pour inverser les récompenses — story 1.6b / 1.7c).
  /// [connectedCount] est le nombre de côtés connectés du placement annulé.
  void removeReward(int coins, int bonusTiles, {int connectedCount = 0}) {
    state = SessionState(
      coins: max(0, state.coins - coins),
      totalBonusTiles: max(0, state.totalBonusTiles - bonusTiles),
      lastReward: null,
      connections3: state.connections3 - (connectedCount == 3 ? 1 : 0),
      connections4: state.connections4 - (connectedCount == 4 ? 1 : 0),
      connections5: state.connections5 - (connectedCount == 5 ? 1 : 0),
      connections6: state.connections6 - (connectedCount == 6 ? 1 : 0),
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
