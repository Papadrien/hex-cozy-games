/// Bottom sheet de demande d'avis — proposée une seule fois, une fois que
/// le joueur a terminé au moins [kReviewPromptGamesThreshold] parties (voir
/// [ReviewService]). Reprend l'esthétique glassmorphism de l'app (mêmes
/// tons que [GlassContainer] et les boutons de `results_modal.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';

import '../services/review_service.dart';
import 'glass_container.dart';

/// Propose la bottom sheet de demande d'avis si elle n'a jamais encore été
/// affichée et que [totalGamesPlayed] atteint le seuil. Marque la demande
/// comme faite avant même l'affichage : elle ne sera plus jamais proposée
/// automatiquement ensuite, quel que soit le choix du joueur.
Future<void> maybeShowReviewPrompt(
  BuildContext context,
  WidgetRef ref, {
  required int totalGamesPlayed,
}) async {
  final reviewService = ref.read(reviewServiceProvider);
  if (!await reviewService.shouldPromptForReview(totalGamesPlayed)) return;
  await reviewService.markPromptShown();

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ReviewBottomSheet(),
  );
}

class _ReviewBottomSheet extends ConsumerWidget {
  const _ReviewBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      // Laisse respirer la sheet au-dessus de la zone home indicator / clavier.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: GlassContainer(
            tintColor: kGlassBlue,
            tintAlpha: 0.32,
            borderColor: kGlassBlueBorder,
            borderWidth: 1.5,
            borderRadius: 24,
            blurSigma: 16,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Poignée visuelle de la bottom sheet.
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(Icons.emoji_events, color: kCoinAmber, size: 40),
                const SizedBox(height: 14),
                Text(
                  context.tr.review_title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr.review_body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: kTropicalTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    onPressed: () => _rateNow(context, ref),
                    child: Text(
                      context.tr.review_rateNow,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                    onPressed: () => _later(context),
                    child: Text(
                      context.tr.review_later,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _rateNow(BuildContext context, WidgetRef ref) {
    ref.read(reviewServiceProvider).requestReview();
    Navigator.of(context).pop();
  }

  void _later(BuildContext context) {
    Navigator.of(context).pop();
  }
}
