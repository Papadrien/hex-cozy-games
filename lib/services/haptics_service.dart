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
///     - [HapticsService.playReward]    : vibration pour les tuiles bonus
///       gagnées lors d'un placement (plus aucune vibration pour les pièces,
///       base ou bonus), voir sa doc.
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
  ///  - une vibration FORTE par tuile gagnée en bonus.
  ///
  /// Les pièces (gain "de base" comme bonus) ne déclenchent plus aucune
  /// vibration : elles arrivent dans le stock de façon trop fréquente/rapide
  /// pour que la crépitation haptique reste agréable, et leur gain est déjà
  /// signalé par `coin.mp3` (voir [AudioService.playCoinsGained]).
  Future<void> playReward({
    required int coins,
    required int bonusCoins,
    required int bonusTiles,
  }) async {
    if (!_enabled) return;
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

  /// Unité de référence pour la durée des vibrations de connexion 5/6
  /// côtés (voir [connectionSucceeded]) — l'API haptique ne renvoie aucune
  /// durée réelle d'impulsion, donc cette constante ne mesure rien : elle
  /// sert uniquement de base documentée pour respecter les ratios demandés
  /// (quintuple = 1,5× cette unité, sextuple = 2× cette unité), matérialisés
  /// par l'espacement entre impulsions répétées de même intensité
  /// ([HapticFeedback.heavyImpact]) — seul moyen, avec cette API, de faire
  /// "durer" perceptiblement plus longtemps une vibration au-delà d'un
  /// simple clic.
  static const Duration _kConnectionDurationUnit = Duration(milliseconds: 100);

  /// Retour spécifique à chaque pose de tuile, avec une intensité qui
  /// grandit avec le nombre de côtés connectés :
  ///  - 0/1/2 côté(s) (aucune / simple / double connexion) : vibration
  ///    faible (léger).
  ///  - 3 côtés : plus intense que ce qui précède (moyen).
  ///  - 4 côtés : encore un cran au-dessus (fort).
  ///  - 5 côtés : intensité augmentée par rapport à 4 côtés (double
  ///    impulsion forte plutôt qu'une seule) ET durée 1,5× celle de 4
  ///    côtés (espacement = 1,5 × [_kConnectionDurationUnit]).
  ///  - 6 côtés ("jackpot") : intensité maximum (triple impulsion forte,
  ///    la plus marquée de toutes) ET durée 2× celle de 4 côtés
  ///    (espacement total = 2 × [_kConnectionDurationUnit]).
  Future<void> connectionSucceeded(int connectedSides) async {
    if (!_enabled) return;
    switch (connectedSides) {
      case 0:
      case 1:
      case 2:
        await HapticFeedback.lightImpact();
      case 3:
        await HapticFeedback.mediumImpact();
      case 4:
        await HapticFeedback.heavyImpact();
      case 5:
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(_kConnectionDurationUnit * 1.5);
        await HapticFeedback.heavyImpact();
      case 6:
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(_kConnectionDurationUnit);
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(_kConnectionDurationUnit);
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

  /// Retour haptique joué lorsqu'une tuile bonus gagnée (Combo+, Bonus de
  /// clôture, Tuile bonus, récompense de connexion) devient visible dans la
  /// pile de tuiles — distinct du retour immédiat de [playReward]/
  /// [connectionSucceeded] joué au moment du gain : celui-ci souligne
  /// plutôt l'arrivée concrète de chaque tuile, une par une (voir
  /// [HexGridComponent.showRewardIndicators]/[UpgradeFxOverlayGame.spawnBonusTiles], qui
  /// envoient désormais systématiquement une icône "+1" par tuile plutôt
  /// que de fusionner plusieurs tuiles dans une seule icône "+N").
  ///
  /// [index] est le rang (1-based) de cette particule dans la série de
  /// gains de LA POSE en cours, toutes sources confondues (voir
  /// [HexBoardGame._bonusImpactCounter]) — l'intensité augmente par
  /// paliers avec [index], jusqu'à atteindre le maximum au 10e impact ;
  /// au-delà, le maximum est simplement maintenu.
  Future<void> bonusTileArrived(int index) async {
    if (!_enabled) return;
    if (index <= 3) {
      await HapticFeedback.lightImpact();
    } else if (index <= 6) {
      await HapticFeedback.mediumImpact();
    } else if (index <= 9) {
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    }
  }

  /// Retour haptique joué à l'ouverture de la pop-up de succès d'achat
  /// in-app (pack de pièces ou premium) — voir `purchase_success_popup.dart`.
  /// Triple impact fort, plus marqué que [questRewardClaimed] (qui n'en
  /// utilise que deux, moyen puis fort) : un achat réel reste un événement
  /// plus rare et plus engageant qu'une simple récompense de quête, la
  /// célébration doit se sentir nettement au-dessus.
  Future<void> purchaseSuccess() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.heavyImpact();
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
