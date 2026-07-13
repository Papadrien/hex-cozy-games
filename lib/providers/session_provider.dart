/// État de session : pièces et tuiles bonus accumulées — Story 1.6b / 1.7a.
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'build_provider.dart';
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
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.currentDoubleStreak = 0,
    this.holdSlotRemainingUses = 0,
    this.secondChanceRemainingUses = 0,
  });

  final int coins;
  final int totalBonusTiles;
  final PlacementReward? lastReward;
  final int connections3;
  final int connections4;
  final int connections5;
  final int connections6;

  /// Série actuelle de connexions consécutives (≥1 côté connecté). Remise
  /// à 0 après une pose sans connexion — Story B2.
  final int currentStreak;

  /// Meilleure série atteinte dans cette session — Story B2.
  final int bestStreak;

  /// Série actuelle de doubles connexions consécutives (exactement 2 côtés
  /// connectés). Remise à 0 dès qu'une pose ne connecte pas exactement 2
  /// côtés — utilisée par Combo+ (Story B3), qui se déclenche tous les N
  /// crans de cette série (N = 15/13/10 selon le niveau de l'amélioration).
  final int currentDoubleStreak;

  /// Utilisations restantes d'Emplacement Joker pour cette partie (Story B9).
  final int holdSlotRemainingUses;

  /// Utilisations restantes de Deuxième chance pour cette partie (Story B9).
  final int secondChanceRemainingUses;

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
    Object? currentStreak = _sentinel,
    Object? bestStreak = _sentinel,
    Object? currentDoubleStreak = _sentinel,
    Object? holdSlotRemainingUses = _sentinel,
    Object? secondChanceRemainingUses = _sentinel,
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
      currentStreak:
          currentStreak == _sentinel ? this.currentStreak : currentStreak as int,
      bestStreak:
          bestStreak == _sentinel ? this.bestStreak : bestStreak as int,
      currentDoubleStreak: currentDoubleStreak == _sentinel
          ? this.currentDoubleStreak
          : currentDoubleStreak as int,
      holdSlotRemainingUses: holdSlotRemainingUses == _sentinel
          ? this.holdSlotRemainingUses
          : holdSlotRemainingUses as int,
      secondChanceRemainingUses: secondChanceRemainingUses == _sentinel
          ? this.secondChanceRemainingUses
          : secondChanceRemainingUses as int,
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
  ///
  /// Met à jour la série de connexions consécutives (Story B2) :
  /// incrémentée si ≥1 côté connecté, remise à 0 sinon.
  void addReward(PlacementReward reward, {int? forcedCoins}) {
    final c = reward.connectedSides.length;
    final nextStreak = c >= 1 ? state.currentStreak + 1 : 0;
    final nextDoubleStreak = c == 2 ? state.currentDoubleStreak + 1 : 0;
    // copyWith (et non un SessionState(...) nu) : sinon les champs non
    // listés ici (holdSlotRemainingUses, secondChanceRemainingUses)
    // retombent silencieusement à leur valeur par défaut (0) à chaque pose,
    // cassant l'Emplacement Joker et Deuxième chance dès la 2e tuile.
    state = state.copyWith(
      coins: state.coins + (forcedCoins ?? c + reward.bonusTiles),
      totalBonusTiles: state.totalBonusTiles + reward.bonusTiles,
      lastReward: reward,
      connections3: state.connections3 + (c == 3 ? 1 : 0),
      connections4: state.connections4 + (c == 4 ? 1 : 0),
      connections5: state.connections5 + (c == 5 ? 1 : 0),
      connections6: state.connections6 + (c == 6 ? 1 : 0),
      currentStreak: nextStreak,
      bestStreak: nextStreak > state.bestStreak ? nextStreak : state.bestStreak,
      currentDoubleStreak: nextDoubleStreak,
    );
  }

  /// Ajoute au compteur cumulé de tuiles bonus de la session des tuiles qui
  /// ne proviennent pas directement de la connexion de la tuile posée
  /// (Combo+, Bonus de clôture — Story B3/B7). Séparé d'[addReward] car ces
  /// bonus sont calculés après coup (ils dépendent de l'état de la session
  /// mis à jour par [addReward], ex: le streak courant). Garde
  /// [SessionState.totalBonusTiles] cohérent avec ce que [removeReward]
  /// retire lors d'un Annuler (voir [totalBonusTilesAdded] côté
  /// `placement_commit.dart`).
  ///
  /// Met aussi à jour [lastReward] (en additionnant ces tuiles à son
  /// bonusTiles) : sans ça, ces bonus sont ajoutés à la pile en silence,
  /// sans jamais apparaître dans le tag de récompense affiché à l'écran
  /// (voir [_RewardTag] dans game_screen.dart), donnant l'impression que
  /// Combo+/Bonus de clôture ne fonctionnent pas.
  void addExtraBonusTiles(int amount) {
    if (amount <= 0) return;
    final current = state.lastReward;
    state = state.copyWith(
      totalBonusTiles: state.totalBonusTiles + amount,
      lastReward: current == null
          ? current
          : PlacementReward(
              connectedSides: current.connectedSides,
              bonusTiles: current.bonusTiles + amount,
              bonusCoins: current.bonusCoins,
            ),
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
    // copyWith : même raison que dans addReward — sinon currentStreak,
    // bestStreak, holdSlotRemainingUses et secondChanceRemainingUses
    // retombent à 0 à chaque Annuler.
    state = state.copyWith(
      coins: max(0, state.coins - coins),
      totalBonusTiles: max(0, state.totalBonusTiles - bonusTiles),
      lastReward: null,
      connections3: state.connections3 - (connectedCount == 3 ? 1 : 0),
      connections4: state.connections4 - (connectedCount == 4 ? 1 : 0),
      connections5: state.connections5 - (connectedCount == 5 ? 1 : 0),
      connections6: state.connections6 - (connectedCount == 6 ? 1 : 0),
    );
  }

  /// Initialise les compteurs d'utilisations par partie depuis les
  /// améliorations actives (Story B9 — Hold + Deuxième chance).
  void initPerGameUses(ActiveUpgradeEffects effects) {
    state = state.copyWith(
      holdSlotRemainingUses: effects.holdSlotUses,
      secondChanceRemainingUses: effects.secondChanceUses,
    );
  }

  /// Consomme une utilisation d'Emplacement Joker (Story B10).
  void consumeHoldSlot() {
    if (state.holdSlotRemainingUses <= 0) return;
    state = state.copyWith(
      holdSlotRemainingUses: state.holdSlotRemainingUses - 1,
    );
  }

  /// Consomme une utilisation de Deuxième chance (Story B11).
  void consumeSecondChance() {
    if (state.secondChanceRemainingUses <= 0) return;
    state = state.copyWith(
      secondChanceRemainingUses: state.secondChanceRemainingUses - 1,
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
