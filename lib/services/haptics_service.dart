/// Service centralisé pour les retours haptiques (vibrations).
///
/// Activable/désactivable via le paramètre « Vibrations » des options (voir
/// [optionsProvider]/[OptionsState.vibrationEnabled]) — chaque méthode
/// vérifie ce réglage avant de déclencher quoi que ce soit, donc les appelants
/// n'ont pas besoin de tester le réglage eux-mêmes.
///
/// Deux familles de retours :
///  - Boutons/UI : [buttonTapFeedback], utilisable depuis n'importe quel
///    widget (Consumer ou non) via son [BuildContext] — pas besoin d'accès à
///    `ref`. Combine le clic haptique et le clic sonore généré
///    procéduralement (voir [AudioService.playButtonClick]) pour tout
///    bouton qui ne possède pas déjà son propre bruitage dédié.
///  - Jeu (via [HapticsService], accessible par [hapticsServiceProvider]) :
///     - [HapticsService.tileRotated]   : un clic par cran de rotation.
///     - [HapticsService.tilePreviewed] : un clic léger à la sélection d'un
///       emplacement pour la prévisualisation.
///     - [HapticsService.playReward]    : motif de vibrations pour les gains
///       d'un placement (pièces / pièces bonus / tuiles bonus), voir sa doc.
library;

import 'dart:async';

import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/options_provider.dart';
import 'audio_service.dart';

/// Nombre maximal de pulsations jouées pour une même catégorie de récompense
/// en un seul placement. Les améliorations peuvent multiplier fortement les
/// gains (ex. tuiles bonus) : sans ce plafond, un gros multiplicateur
/// déclencherait une rafale de vibrations de plusieurs secondes. Le plafond
/// garde une sensation de progression sans rendre le retour interminable.
const int _kMaxHapticPulsesPerCategory = 6;

/// Délai entre deux pulsations d'une même catégorie, pour qu'elles restent
/// perceptibles comme des impulsions distinctes plutôt qu'une seule
/// vibration continue.
const Duration _kPulseGap = Duration(milliseconds: 90);

class HapticsService {
  HapticsService(this._ref);

  final Ref _ref;

  bool get _enabled => _ref.read(optionsProvider).vibrationEnabled;

  /// Un clic sec et bref — utilisé à chaque cran de 60° de rotation d'une
  /// tuile en prévisualisation.
  void tileRotated() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  /// Un clic léger — utilisé lors de la sélection d'un emplacement pour la
  /// prévisualisation (premier tap sur une case disponible).
  void tilePreviewed() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Joue le motif de vibrations correspondant aux gains d'un placement :
  ///  - une vibration LÉGÈRE par pièce gagnée (gain "de base", lié aux côtés
  ///    connectés) ;
  ///  - une vibration MOYENNE par pièce gagnée en bonus ;
  ///  - une vibration FORTE par tuile gagnée en bonus.
  ///
  /// Ordre de priorité : toutes les vibrations légères d'abord, puis les
  /// moyennes, puis les fortes — pour que l'intensité perçue monte crescendo
  /// plutôt que d'alterner de façon désordonnée.
  Future<void> playReward({
    required int coins,
    required int bonusCoins,
    required int bonusTiles,
  }) async {
    if (!_enabled) return;
    await _pulseN(HapticFeedback.lightImpact, coins);
    await _pulseN(HapticFeedback.mediumImpact, bonusCoins);
    await _pulseN(HapticFeedback.heavyImpact, bonusTiles);
  }

  Future<void> _pulseN(
    Future<void> Function() feedback,
    int count,
  ) async {
    final n = count.clamp(0, _kMaxHapticPulsesPerCategory);
    for (var i = 0; i < n; i++) {
      await feedback();
      if (i < n - 1) {
        await Future<void>.delayed(_kPulseGap);
      }
    }
  }

  /// Retour spécifique lors d'une connexion réussie, avec une intensité qui
  /// grandit avec le nombre de côtés connectés pour souligner que le bonus
  /// associé est de plus en plus important :
  ///  - 3 côtés : un clic léger.
  ///  - 4 côtés : un clic moyen.
  ///  - 5 côtés : un clic fort.
  ///  - 6 côtés : double clic fort ("jackpot"), nettement plus marqué.
  ///
  /// Aucun effet en dehors de 3-6 (pas de bonus associé à moins de 3 côtés).
  Future<void> connectionSucceeded(int connectedSides) async {
    if (!_enabled) return;
    switch (connectedSides) {
      case 3:
        await HapticFeedback.lightImpact();
      case 4:
        await HapticFeedback.mediumImpact();
      case 5:
        await HapticFeedback.heavyImpact();
      case 6:
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.heavyImpact();
    }
  }
  /// Retour haptique de célébration joué lorsqu'une récompense de quête est
  /// réclamée manuellement (tap sur une quête terminée). Un impact moyen
  /// suivi d'un impact fort après un court délai, pour une sensation de
  /// "pop" satisfaisant distincte des autres retours du jeu.
  Future<void> questRewardClaimed() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  /// Retour haptique joué lorsqu'une tuile bonus gagnée (Combo+, récompense
  /// de placement) devient visible dans la pile de tuiles — distinct du
  /// retour immédiat de [playReward] joué au moment du gain : celui-ci
  /// souligne plutôt l'arrivée concrète de la tuile, potentiellement
  /// plusieurs poses plus tard une fois qu'elle atteint le sommet visible
  /// de la pile. Un simple impact moyen, pour rester perceptible sans se
  /// confondre avec les autres motifs (rotation, sélection, récompense).
  Future<void> bonusTileArrived() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }
}

final hapticsServiceProvider = Provider<HapticsService>((ref) {
  return HapticsService(ref);
});

/// Retour bref — haptique et sonore — pour n'importe quel bouton de
/// l'application.
///
/// Combine :
///  - un clic haptique léger ([HapticFeedback.selectionClick]), sous
///    réserve du réglage « Vibrations » ([OptionsState.vibrationEnabled]) ;
///  - un clic sonore généré procéduralement, sans aucun fichier audio
///    associé (voir [AudioService.playButtonClick]), sous réserve du
///    réglage « Bruitages » ([OptionsState.sfxEnabled]).
///
/// Utilisable depuis n'importe quel widget disposant d'un [BuildContext] —
/// y compris les widgets `StatelessWidget` sans accès direct à `ref` — via le
/// [ProviderContainer] déjà attaché à l'arbre de widgets par [ProviderScope].
/// À placer en première instruction de chaque `onPressed`/`onTap` de bouton
/// qui ne déclenche pas déjà son propre bruitage dédié (ex. pose de tuile,
/// gain de pièces) — pour ces boutons-là, le clic sonore générique serait
/// redondant.
void buttonTapFeedback(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(optionsProvider).vibrationEnabled) {
    HapticFeedback.selectionClick();
  }
  unawaited(container.read(audioServiceProvider).playButtonClick());
}
