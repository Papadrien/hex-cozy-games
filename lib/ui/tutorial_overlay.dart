/// Overlay du tutoriel first-launch — Story 1.10a / 1.10b.
///
/// Affiche un overlay semi-transparent avec une zone en évidence
/// (highlight) correspondant à l'étape courante, un texte d'instruction,
/// un indicateur de progression, et des boutons Suivant / Passer.
///
/// Story 1.10a (fix) : le highlight suit la position et la taille réelles
/// du widget ciblé — calculées via la [GlobalKey] correspondante
/// (transmise par [GameScreen] dans [targetKeys]) — au lieu de coordonnées
/// arbitraires en pourcentage d'écran, qui ne correspondaient à aucun
/// élément UI réel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../l10n/app_localizations.dart';
import '../providers/tutorial_provider.dart';

class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key, required this.targetKeys});

  /// Map `highlightTargetKey` (cf. [TutorialStep]) → [GlobalKey] du widget
  /// réel à mettre en évidence dans l'arbre de [GameScreen].
  final Map<String, GlobalKey> targetKeys;

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with WidgetsBindingObserver {
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Recalcule le highlight si la taille de l'écran change (rotation,
  // split-screen, etc.) puisque les rects sont dérivés du layout réel.
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  /// Force un second build juste après le premier frame où le tutoriel
  /// devient actif : garantit que les [RenderBox] ciblées sont bien
  /// mesurées (le tout premier build après activation peut survenir avant
  /// que le layout des widgets cibles ne soit stabilisé).
  void _scheduleHighlightRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final tutorial = ref.watch(tutorialProvider);
      if (!tutorial.isActive) {
        _wasActive = false;
        return const SizedBox.shrink();
      }
      if (!_wasActive) {
        _wasActive = true;
        _scheduleHighlightRefresh();
      }

      final notifier = ref.read(tutorialProvider.notifier);
      final step = notifier.currentStepData;
      final highlightRect = _resolveRect(step.highlightTargetKey);

      // Place la carte d'instruction au-dessus ou en dessous de la zone
      // surlignée selon l'espace disponible, pour ne jamais la recouvrir.
      final screenSize = MediaQuery.of(context).size;
      final safeBottom = MediaQuery.of(context).padding.bottom;
      final cardBelowHighlight = highlightRect == null ||
          highlightRect.bottom < screenSize.height * 0.55;
      final cardTop = cardBelowHighlight
          ? (highlightRect?.bottom ?? screenSize.height * 0.5) + 24
          : null;
      final cardBottom = cardBelowHighlight ? null : 160 + safeBottom;

      return Stack(
        children: [
          // Arrière-plan semi-transparent qui bloque les interactions.
          GestureDetector(
            onTap: () {},
            child: Container(color: Colors.black.withValues(alpha: 0.65)),
          ),

          // Zone en évidence (highlight) — uniquement si le widget ciblé
          // est bien monté et mesurable.
          if (highlightRect != null)
            Positioned(
              top: highlightRect.top,
              left: highlightRect.left,
              child: IgnorePointer(
                child: SizedBox(
                  width: highlightRect.width,
                  height: highlightRect.height,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: kBrandBlue,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kBrandBlue.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Texte d'instruction — repositionné dynamiquement pour ne pas
          // chevaucher le highlight.
          Positioned(
            top: cardTop,
            bottom: cardBottom,
            left: 32,
            right: 32,
            child: _InstructionCard(text: _stepText(context, step.textKey)),
          ),

          // Indicateur de progression (points)
          Positioned(
            bottom: 48 + safeBottom,
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
                context.tr.tutorial_skip,
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
            bottom: 96 + safeBottom,
            right: 32,
            child: FilledButton(
              onPressed: () => notifier.next(),
              style: FilledButton.styleFrom(
                backgroundColor: kBrandBlue,
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
    });
  }

  /// Calcule le [Rect] global (coordonnées écran) du widget ciblé par
  /// [highlightKey], à partir de sa [GlobalKey] réelle. Retourne `null`
  /// si la clé est inconnue, si le widget n'est pas encore monté/mesuré
  /// (premier frame), ou si la cible occupe la quasi-totalité de l'écran
  /// (ex. le plateau de jeu en plein écran) — dans ce dernier cas, un
  /// cadre de highlight n'apporterait rien visuellement, seuls le texte
  /// et les dots de progression restent affichés.
  Rect? _resolveRect(String highlightKey) {
    final key = widget.targetKeys[highlightKey];
    if (key == null) return null;

    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screenSize = MediaQuery.of(context).size;
    final coversScreen =
        size.width >= screenSize.width * 0.9 && size.height >= screenSize.height * 0.9;
    if (coversScreen) return null;

    // Léger padding autour du widget pour que le highlight "respire"
    // au lieu de coller exactement aux bords du contenu.
    const padding = 10.0;
    return Rect.fromLTWH(
      topLeft.dx - padding,
      topLeft.dy - padding,
      size.width + padding * 2,
      size.height + padding * 2,
    );
  }

  String _stepText(BuildContext context, String textKey) {
    final tr = AppLocalizations.of(context)!;
    switch (textKey) {
      case 'tutorial.step1':
        return tr.tutorial_step1;
      case 'tutorial.step2':
        return tr.tutorial_step2;
      case 'tutorial.step3':
        return tr.tutorial_step3;
      case 'tutorial.step4':
        return tr.tutorial_step4;
      case 'tutorial.step5':
        return tr.tutorial_step5;
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
        color: kBackgroundColor,
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
                ? kBrandBlue
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
