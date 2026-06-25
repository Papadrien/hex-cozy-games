/// Bouton Pause — Story 1.5bis-a.
///
/// Positionné en haut à droite de l'écran de jeu, style glassmorphism homogène
/// avec les autres éléments HUD.
library;

import 'dart:ui' show ImageFilter;

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: _kPauseButtonSize,
            height: _kPauseButtonSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.pause,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
