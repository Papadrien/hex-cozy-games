/// Gestion du tutoriel first-launch — Story 1.10a.
///
/// Persiste `hasSeenTutorial` dans SharedPreferences.
/// Fournit l'état [TutorialState] (actif, étape courante) et les
/// actions (next, skip, start).
library;

import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/tutorial_step.dart';

const String _kHasSeenTutorialKey = 'hasSeenTutorial';

/// Position du geste doigt pour les étapes ciblant le plateau : le plateau
/// occupe tout l'écran (aucune zone en évidence précise n'est calculable),
/// on ancre donc le geste sur le pivot visuel de la grille — mêmes
/// fractions que le pivot utilisé par [HexGridComponent] et le shader
/// d'océan (0.42, 0.38), pour rester cohérent avec l'endroit où les tuiles
/// apparaissent réellement à l'écran.
const Offset _kBoardHintAnchor = Offset(0.42, 0.40);

/// Position du geste doigt pour l'étape swipe (rotation) : décalée vers la
/// droite de l'écran, là où le swipe de rotation est réellement effectué
/// pendant une partie (le pouce/index droit reste sur le côté plutôt qu'au
/// centre), au lieu du pivot central de la grille utilisé par erreur
/// auparavant.
const Offset _kSwipeHintAnchor = Offset(0.82, 0.52);

/// Décalage (en pixels logiques, à zoom 1.0) du centre de la case voisine
/// sud-ouest de la tuile centrale (0, 0) par rapport à ce pivot — direction
/// 3 dans [HexCoords] ("sud-ouest" : (-1, 1)).
///
/// Calculé à partir de [kHexSize] (48) et [kIsoScaleY] (0.57), avec les
/// mêmes formules que [HexLayout.hexToPixel] :
///   dx = kHexSize * (sqrt(3) * -1 + sqrt(3)/2 * 1) = -kHexSize * sqrt(3)/2
///   dy = kHexSize * (3/2 * 1) * kIsoScaleY
/// Cette case est toujours l'une des 6 cases disponibles en surbrillance
/// autour de la tuile de départ : le doigt pointe donc vers une case
/// réellement posable, en diagonale bas-gauche, proche du centre.
const Offset _kSwNeighborOffset = Offset(-41.57, 41.04);

const List<TutorialStep> kTutorialSteps = [
  TutorialStep(
    highlightTargetKey: 'board',
    textKey: 'tutorial.step1',
    order: 0,
    gesture: TutorialGesture.tap,
    anchorFraction: _kBoardHintAnchor,
    anchorOffset: _kSwNeighborOffset,
  ),
  TutorialStep(
    highlightTargetKey: 'board',
    textKey: 'tutorial.step2',
    order: 1,
    gesture: TutorialGesture.swipeVertical,
    anchorFraction: _kSwipeHintAnchor,
  ),
  TutorialStep(
    // Aucune zone rectangulaire mise en évidence ici (le plateau occupe tout
    // l'écran) : seul le geste "point" ci-dessous attire l'œil vers l'icône
    // de pièce qui apparaît sur la tuile posée automatiquement pour cette
    // étape — voir [_GameScreenState._autoPlaceTutorialConnection].
    highlightTargetKey: 'board',
    textKey: 'tutorial.step3',
    order: 2,
    gesture: TutorialGesture.point,
    anchorFraction: _kBoardHintAnchor,
    anchorOffset: _kSwNeighborOffset,
  ),
  TutorialStep(
    highlightTargetKey: 'board',
    textKey: 'tutorial.step4',
    order: 3,
    gesture: TutorialGesture.tap,
    anchorFraction: _kBoardHintAnchor,
    anchorOffset: _kSwNeighborOffset,
  ),
  TutorialStep(
    highlightTargetKey: 'board',
    textKey: 'tutorial.step5',
    order: 4,
    gesture: TutorialGesture.none,
  ),
];

class TutorialState {
  final bool isActive;
  final int currentStep;
  final bool hasBeenSeen;

  const TutorialState({
    this.isActive = false,
    this.currentStep = 0,
    this.hasBeenSeen = false,
  });

  TutorialState copyWith({
    bool? isActive,
    int? currentStep,
    bool? hasBeenSeen,
  }) {
    return TutorialState(
      isActive: isActive ?? this.isActive,
      currentStep: currentStep ?? this.currentStep,
      hasBeenSeen: hasBeenSeen ?? this.hasBeenSeen,
    );
  }
}

class TutorialNotifier extends Notifier<TutorialState> {
  @override
  TutorialState build() => const TutorialState();

  /// Vérifie SharedPreferences et démarre le tutoriel si c'est le
  /// premier lancement.
  Future<void> checkAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kHasSeenTutorialKey) ?? false;
    if (!seen) {
      state = const TutorialState(isActive: true, currentStep: 0);
    } else {
      state = state.copyWith(hasBeenSeen: true);
    }
  }

  TutorialStep get currentStepData => kTutorialSteps[state.currentStep];

  bool get isLastStep => state.currentStep >= kTutorialSteps.length - 1;

  bool get canGoNext => state.currentStep < kTutorialSteps.length - 1;

  void next() {
    if (state.currentStep < kTutorialSteps.length - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    } else {
      skip();
    }
  }

  Future<void> skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasSeenTutorialKey, true);
    state = const TutorialState(hasBeenSeen: true);
  }
}

final tutorialProvider =
    NotifierProvider<TutorialNotifier, TutorialState>(TutorialNotifier.new);
