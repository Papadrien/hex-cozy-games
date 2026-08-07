import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../services/haptics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON JOUER PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class HomePlayButton extends StatelessWidget {
  const HomePlayButton({
    super.key,
    required this.activeSession,
    required this.onPlay,
    required this.onResume,
  });

  final AsyncValue<bool> activeSession;
  final Future<void> Function() onPlay;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    final label = activeSession.when(
      loading: () => null,
      data: (active) => active ? context.tr.home_resume : context.tr.home_play,
      error: (_, _) => context.tr.home_play,
    );
    final onTap = activeSession.when(
      loading: () => null,
      data: (active) => active ? onResume : onPlay,
      error: (_, _) => onPlay,
    );

    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Bouton principal
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: kTropicalTeal.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: onTap == null
                      ? null
                      : () async {
                          buttonTapFeedback(context);
                          await onTap();
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      // Aligné sur le contour glassmorphism commun
                      // (kGlassBlueBorder, blanc 20%) pour rester cohérent
                      // avec le reste des composants — même épaisseur que
                      // les autres accents mis en avant (1.5).
                      border: Border.all(
                        color: kGlassBlueBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: label == null
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              label,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Fleur hibiscus qui déborde à gauche
          Positioned(
            left: -8,
            top: -20,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/hibiscus.png',
                width: 72,
                height: 72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
