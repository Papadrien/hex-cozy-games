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

import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../core/tutorial_step.dart';
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _wasActive = false;

  /// Anime en boucle le geste doigt (tap / swipe / point) de l'étape
  /// courante — voir [_TutorialGestureHint].
  late final AnimationController _gestureController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gestureController.dispose();
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
      final hintCenter = _resolveHintCenter(context, step, highlightRect);

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

          // Geste doigt animé illustrant l'action attendue (tap / swipe /
          // simple mise en évidence) — Story 1.10c.
          if (step.gesture != TutorialGesture.none && hintCenter != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _TutorialGestureHint(
                  key: ValueKey(tutorial.currentStep),
                  center: hintCenter,
                  gesture: step.gesture,
                  animation: _gestureController,
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

  /// Détermine où afficher le geste doigt animé : centre de la zone en
  /// évidence si elle existe, sinon la position fractionnelle explicite de
  /// l'étape ([TutorialStep.anchorFraction]), sinon `null` (pas de geste).
  Offset? _resolveHintCenter(
      BuildContext context, TutorialStep step, Rect? highlightRect) {
    if (highlightRect != null) return highlightRect.center + step.anchorOffset;
    final fraction = step.anchorFraction;
    if (fraction == null) return null;
    final screenSize = MediaQuery.of(context).size;
    return Offset(screenSize.width * fraction.dx, screenSize.height * fraction.dy) +
        step.anchorOffset;
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
      case 'tutorial.step6':
        return tr.tutorial_step6;
      case 'tutorial.step7':
        return tr.tutorial_step7;
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

/// Doigt animé illustrant le geste attendu à l'étape courante du tutoriel
/// (Story 1.10c) : tap (anneau qui pulse), swipe vertical (oscillation +
/// flèches), ou simple mise en évidence (léger rebond).
class _TutorialGestureHint extends StatelessWidget {
  const _TutorialGestureHint({
    super.key,
    required this.center,
    required this.gesture,
    required this.animation,
  });

  final Offset center;
  final TutorialGesture gesture;
  final Animation<double> animation;

  static const double _kIconSize = 40.0;
  static const Color _kHintColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value; // boucle 0 → 1
        switch (gesture) {
          case TutorialGesture.tap:
            return _buildTap(t);
          case TutorialGesture.swipeVertical:
            return _buildSwipe(t);
          case TutorialGesture.point:
            return _buildPoint(t);
          case TutorialGesture.none:
            return const SizedBox.shrink();
        }
      },
    );
  }

  /// Le doigt "appuie" (léger rétrécissement) en boucle, avec un anneau qui
  /// s'étend et s'estompe à chaque pression — mime un tap répété.
  Widget _buildTap(double t) {
    final pressAmount = (1 - cos(t * 2 * pi)) / 2; // 0 → 1 → 0, lisse
    final scale = 1.0 - 0.15 * pressAmount;
    final rippleRadius = 16.0 + 34.0 * t;
    final rippleOpacity = (1 - t) * 0.55;

    return Stack(
      children: [
        Positioned(
          left: center.dx - rippleRadius,
          top: center.dy - rippleRadius,
          child: Container(
            width: rippleRadius * 2,
            height: rippleRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _kHintColor.withValues(alpha: rippleOpacity),
                width: 2,
              ),
            ),
          ),
        ),
        Positioned(
          left: center.dx - _kIconSize / 2,
          top: center.dy - _kIconSize / 2,
          child: Transform.scale(scale: scale, child: _fingerIcon()),
        ),
      ],
    );
  }

  /// Le doigt oscille de haut en bas entre deux petites flèches, pour mimer
  /// le swipe vertical utilisé pour faire pivoter la tuile.
  Widget _buildSwipe(double t) {
    final dy = sin(t * 2 * pi) * 26.0;
    final arrowPulse = 0.4 + 0.3 * ((cos(t * 2 * pi) + 1) / 2);

    return Stack(
      children: [
        Positioned(
          left: center.dx - 13,
          top: center.dy - 58,
          child: Icon(Icons.keyboard_arrow_up_rounded,
              color: _kHintColor.withValues(alpha: arrowPulse), size: 26),
        ),
        Positioned(
          left: center.dx - 13,
          top: center.dy + 32,
          child: Icon(Icons.keyboard_arrow_down_rounded,
              color: _kHintColor.withValues(alpha: arrowPulse), size: 26),
        ),
        Positioned(
          left: center.dx - _kIconSize / 2,
          top: center.dy - _kIconSize / 2 + dy,
          child: _fingerIcon(),
        ),
      ],
    );
  }

  /// Simple rebond léger, pour attirer l'attention sans mimer un geste précis
  /// (étapes purement informatives).
  Widget _buildPoint(double t) {
    final dy = sin(t * 2 * pi) * 6.0;
    return Stack(
      children: [
        Positioned(
          left: center.dx - _kIconSize / 2,
          top: center.dy - _kIconSize / 2 + dy,
          child: _fingerIcon(),
        ),
      ],
    );
  }

  Widget _fingerIcon() {
    return Icon(
      Icons.touch_app_rounded,
      color: _kHintColor,
      size: _kIconSize,
      shadows: const [
        Shadow(color: Colors.black54, blurRadius: 8),
      ],
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
