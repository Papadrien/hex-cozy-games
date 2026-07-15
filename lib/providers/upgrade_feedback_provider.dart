/// Feedback de déclenchement des améliorations — Story B12a.
///
/// Permet à l'UI (encart des améliorations actives — Story B12c/B12d) de
/// savoir quel(s) type(s) d'effet viennent de se déclencher sur la pose la
/// plus récente, pour piloter une pulsation/contour visuel ciblé par icône.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_enums.dart';

/// État du feedback de déclenchement des améliorations.
///
/// [tick] est incrémenté à CHAQUE pose (même si [triggeredTypes] est vide,
/// ou identique à la pose précédente) afin que l'UI puisse détecter un
/// nouvel évènement via `ref.listen` même quand le même [UpgradeEffectType]
/// se redéclenche deux poses de suite (ex : Tuile bonus sur deux poses
/// sextuple consécutives) — sans ce compteur, un [Set] identique au
/// précédent ne déclencherait aucune nouvelle notification côté listener.
class UpgradeFeedbackState {
  const UpgradeFeedbackState({
    this.triggeredTypes = const {},
    this.tick = 0,
  });

  /// Les [UpgradeEffectType] ayant produit un bonus sur la pose qui vient
  /// d'avoir lieu. Vide si la pose n'a déclenché aucune amélioration.
  final Set<UpgradeEffectType> triggeredTypes;
  final int tick;
}

final upgradeFeedbackProvider =
    NotifierProvider<UpgradeFeedbackNotifier, UpgradeFeedbackState>(
        UpgradeFeedbackNotifier.new);

class UpgradeFeedbackNotifier extends Notifier<UpgradeFeedbackState> {
  @override
  UpgradeFeedbackState build() => const UpgradeFeedbackState();

  /// Signale les [types] d'effet déclenchés par la pose en cours (peut être
  /// vide). Incrémente [UpgradeFeedbackState.tick] à chaque appel.
  void reportTriggered(Set<UpgradeEffectType> types) {
    state = UpgradeFeedbackState(
      triggeredTypes: types,
      tick: state.tick + 1,
    );
  }

  /// Réinitialise l'état (nouvelle partie).
  void reset() {
    state = const UpgradeFeedbackState();
  }
}
