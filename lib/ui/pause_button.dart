/// Bouton Pause — Story 1.5bis-a.
///
/// Positionné en haut à droite de l'écran de jeu, style semi-transparent
/// homogène avec les autres éléments HUD.
library;

import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../providers/pause_provider.dart';

/// Taille visuelle du bouton pause (carré).
const double _kPauseButtonSize = 36.0;

/// Taille de la zone cliquable — plus grande que le rendu visuel pour que
/// le bouton reste facile à toucher malgré sa position en bord d'écran.
const double _kPauseButtonHitSize = 48.0;

class PauseButton extends ConsumerWidget {
  const PauseButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kPauseButtonHitSize / 2),
        onTap: () => ref.read(pauseProvider.notifier).pause(),
        child: const SizedBox(
          width: _kPauseButtonHitSize,
          height: _kPauseButtonHitSize,
          child: Center(
            child: GlassIconButton(
              icon: Icons.pause,
              size: 20,
              padding: const EdgeInsets.all(8),
              borderRadius: 10,
              tintColor: kGlassBlue,
              tintAlpha: 0.22,
              borderColor: kGlassBlueBorder,
              blurSigma: 10,
            ),
          ),
        ),
      ),
    );
  }
}