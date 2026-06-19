/// Overlay du tutoriel first-launch — Story 1.10a / 1.10b.
///
/// Affiche un overlay semi-transparent avec une zone en évidence
/// (highlight) correspondant à l'étape courante, un texte d'instruction,
/// un indicateur de progression, et des boutons Suivant / Passer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../providers/tutorial_provider.dart';

class TutorialOverlay extends ConsumerWidget {
  const TutorialOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutorial = ref.watch(tutorialProvider);
    if (!tutorial.isActive) return const SizedBox.shrink();

    final notifier = ref.read(tutorialProvider.notifier);
    final step = notifier.currentStepData;

    final screenSize = MediaQuery.of(context).size;
    final highlightRect = _highlightRectFor(step.highlightTargetKey, screenSize);

    return Stack(
      children: [
        // Arrière-plan semi-transparent qui bloque les interactions
        GestureDetector(
          onTap: () {},
          child: Container(color: Colors.black.withValues(alpha: 0.65)),
        ),

        // Zone en évidence (highlight)
        if (highlightRect != null)
          Positioned(
            top: highlightRect.top,
            left: highlightRect.left,
            child: SizedBox(
              width: highlightRect.width,
              height: highlightRect.height,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6FA8DC),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6FA8DC).withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Texte d'instruction
        Positioned(
          bottom: 160,
          left: 32,
          right: 32,
          child: _InstructionCard(text: _stepText(step.textKey)),
        ),

        // Indicateur de progression (points)
        Positioned(
          bottom: 108,
          left: 0,
          right: 0,
          child: _StepDots(
            total: kTutorialSteps.length,
            current: tutorial.currentStep,
          ),
        ),

        // Bouton Passer
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: TextButton(
            onPressed: () => notifier.skip(),
            child: Text(
              Str.tutorial_skip,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // Bouton Suivant / Terminer
        Positioned(
          bottom: 48,
          right: 32,
          child: FilledButton(
            onPressed: () => notifier.next(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6FA8DC),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              notifier.isLastStep ? 'OK' : '→',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Rect? _highlightRectFor(String key, Size screen) {
    final w = screen.width;
    final h = screen.height;

    switch (key) {
      case 'board':
        return Rect.fromLTWH(
          w * 0.15,
          h * 0.22,
          w * 0.70,
          h * 0.35,
        );
      case 'preview':
        return Rect.fromLTWH(
          w * 0.20,
          h * 0.30,
          w * 0.60,
          h * 0.35,
        );
      case 'coins':
        return Rect.fromLTWH(
          16,
          h * 0.18,
          120,
          48,
        );
      case 'placement':
        return Rect.fromLTWH(
          w * 0.15,
          h * 0.25,
          w * 0.70,
          h * 0.30,
        );
      case 'connections':
        return Rect.fromLTWH(
          w * 0.10,
          h * 0.22,
          w * 0.80,
          h * 0.35,
        );
      default:
        return null;
    }
  }

  String _stepText(String textKey) {
    switch (textKey) {
      case 'tutorial.step1':
        return Str.tutorial_step1;
      case 'tutorial.step2':
        return Str.tutorial_step2;
      case 'tutorial.step3':
        return Str.tutorial_step3;
      case 'tutorial.step4':
        return Str.tutorial_step4;
      case 'tutorial.step5':
        return Str.tutorial_step5;
      default:
        return '';
    }
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6FA8DC)
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
