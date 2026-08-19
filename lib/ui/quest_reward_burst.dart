/// Petite explosion de particules jouée lorsqu'une récompense de quête est
/// réclamée manuellement — voir [_QuestCard] dans `quests_screen.dart`.
/// Réutilisée en version élargie (plus de particules, palette multicolore)
/// pour la pop-up de succès d'achat — voir `purchase_success_popup.dart`.
///
/// Purement visuel et sans état propre : piloté par un [progress] externe
/// (0.0 → 1.0) fourni par l'`AnimationController` du parent via
/// `AnimatedBuilder`, pour rester synchronisé avec le reste de l'animation
/// de claim (bounce de la carte, halo doré, texte flottant).
library;

import 'dart:math';

import 'package:flutter/material.dart';

class QuestRewardBurst extends StatelessWidget {
  const QuestRewardBurst({
    super.key,
    required this.progress,
    this.color = Colors.amber,
    this.colors,
    this.particleCount = 10,
    this.maxDistance = 42,
  });

  /// Avancement de l'animation, de 0.0 (départ, particules au centre) à
  /// 1.0 (fin, particules dispersées et invisibles).
  final double progress;

  /// Couleur unique des particules — ignorée si [colors] est fourni.
  final Color color;

  /// Palette multicolore optionnelle : chaque particule pioche dedans en
  /// alternance (index % colors.length) au lieu d'utiliser [color] seul —
  /// donne un effet confetti pour les célébrations plus marquantes (achat).
  final List<Color>? colors;

  final int particleCount;
  final double maxDistance;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();

    // Les particules partent un peu après le début du bounce de la carte,
    // pour que le "pop" précède l'explosion plutôt que de se superposer.
    final burst = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final fade = Curves.easeIn.transform(progress.clamp(0.0, 1.0));
    final palette = colors;

    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(particleCount, (i) {
          final angle = (2 * pi / particleCount) * i + (i.isEven ? 0.18 : 0);
          final distance = burst * maxDistance;
          final dx = cos(angle) * distance;
          final dy = sin(angle) * distance - (burst * 6); // léger envol
          final opacity = (1 - fade).clamp(0.0, 1.0);
          final scale = (1 - burst * 0.5).clamp(0.0, 1.0);
          final isStar = i.isEven;
          final particleColor =
              palette != null ? palette[i % palette.length] : color;

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Icon(
                  isStar ? Icons.star_rounded : Icons.circle,
                  size: isStar ? 13 : 6,
                  color: particleColor,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
