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
import '../services/haptics_service.dart';

/// Taille du bouton pause (carré).
const double _kPauseButtonSize = 36.0;

class PauseButton extends ConsumerWidget {
  const PauseButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      borderRadius: 10,
      blurSigma: 10,
      tintAlpha: 0.18,
      borderColor: kTropicalTealBorder.withValues(alpha: 0.38),
      width: _kPauseButtonSize,
      height: _kPauseButtonSize,
      onTap: () {
        buttonHapticTap(context);
        ref.read(pauseProvider.notifier).pause();
      },
      child: const Icon(
        Icons.pause,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}