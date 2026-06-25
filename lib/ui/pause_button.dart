/// Bouton Pause — Story 1.5bis-a.
///
/// Positionné en haut à droite de l'écran de jeu, style semi-transparent
/// homogène avec les autres éléments HUD.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../providers/pause_provider.dart';

/// Taille du bouton pause (carré).
const double _kPauseButtonSize = 36.0;

class PauseButton extends ConsumerWidget {
  const PauseButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: kGlassBlue.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => ref.read(pauseProvider.notifier).pause(),
            child: Container(
              width: _kPauseButtonSize,
              height: _kPauseButtonSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: kGlassBlueBorder.withValues(alpha: 0.38),
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
      ),
    );
  }
}