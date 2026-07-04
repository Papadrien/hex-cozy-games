/// Service centralisé pour les retours haptiques (vibrations).
///
/// Activable/désactivable via le paramètre « Vibrations » des options (voir
/// [optionsProvider]/[OptionsState.vibrationEnabled]) — chaque méthode
/// vérifie ce réglage avant de déclencher quoi que ce soit, donc les appelants
/// n'ont pas besoin de tester le réglage eux-mêmes.
///
/// Retours haptiques couverts :
///  - [tileRotated]         : un clic bref par cran de rotation de tuile.
///  - [tilePreviewed]       : un clic léger lors de la prévisualisation
///                            (premier tap sur un emplacement disponible).
///  - [coinsEarned]         : un retour dédié aux pièces gagnées, différent
///                            des autres interactions pour bien signaler un
///                            gain.
///  - [connectionSucceeded] : un motif différent selon le nombre de côtés
///                            connectés (3 à 6), d'intensité croissante pour
///                            souligner que le bonus est de plus en plus
///                            important.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/options_provider.dart';

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

  /// Retour dédié à un gain de pièce(s), volontairement distinct des retours
  /// de rotation/prévisualisation (impact moyen plutôt qu'un clic sec) pour
  /// bien faire ressentir un gain plutôt qu'une simple interaction d'UI.
  void coinsEarned() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
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
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.heavyImpact();
    }
  }
}

final hapticsServiceProvider = Provider<HapticsService>((ref) {
  return HapticsService(ref);
});
