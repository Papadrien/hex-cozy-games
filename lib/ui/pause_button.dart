/// Bouton Pause — Story 1.5bis-a.
///
/// Positionné en haut à droite de l'écran de jeu, style sobre homogène avec
/// les autres badges HUD (contexte 7.4) : fond semi-transparent, coins
/// arrondis, icône simple (deux barres verticales).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pause_provider.dart';

/// Taille du bouton pause (carré).
const double _kPauseButtonSize = 36.0;

class PauseButton extends ConsumerWidget {
  const PauseButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(pauseProvider.notifier).pause();
      },
      child: Container(
        width: _kPauseButtonSize,
        height: _kPauseButtonSize,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.pause,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
