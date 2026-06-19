/// Gestion du tutoriel first-launch — Story 1.10a.
///
/// Persiste `hasSeenTutorial` dans SharedPreferences.
/// Fournit l'état [TutorialState] (actif, étape courante) et les
/// actions (next, skip, start).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/tutorial_step.dart';

const String _kHasSeenTutorialKey = 'hasSeenTutorial';

const List<TutorialStep> kTutorialSteps = [
  TutorialStep(
    highlightTargetKey: 'board',
    textKey: 'tutorial.step1',
    order: 0,
  ),
  TutorialStep(
    highlightTargetKey: 'preview',
    textKey: 'tutorial.step2',
    order: 1,
  ),
  TutorialStep(
    highlightTargetKey: 'coins',
    textKey: 'tutorial.step3',
    order: 2,
  ),
  TutorialStep(
    highlightTargetKey: 'placement',
    textKey: 'tutorial.step4',
    order: 3,
  ),
  TutorialStep(
    highlightTargetKey: 'connections',
    textKey: 'tutorial.step5',
    order: 4,
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
