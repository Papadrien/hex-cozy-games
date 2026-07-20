import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Transition "blur progressif" : la page entrante apparaît d'abord floutée
/// puis se stabilise (blur -> net) pendant qu'elle fond en opacité.
/// Cohérent avec l'esthétique glassmorphism de l'app — pensée pour les
/// navigations fréquentes (retour au menu, ouverture d'un écran secondaire).
class BlurFadePageRoute<T> extends PageRouteBuilder<T> {
  BlurFadePageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.maxBlurSigma = 18,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return AnimatedBuilder(
              animation: curved,
              child: child,
              builder: (context, child) {
                final t = curved.value.clamp(0.0, 1.0);
                final sigma = maxBlurSigma * (1 - t);
                return Opacity(
                  opacity: t,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: sigma,
                      sigmaY: sigma,
                      tileMode: TileMode.decal,
                    ),
                    child: child,
                  ),
                );
              },
            );
          },
        );

  final double maxBlurSigma;
}

/// Transition "wipe hexagonal" : un hexagone s'ouvre depuis le centre de
/// l'écran pour révéler la page entrante — clin d'œil à la grille du jeu.
/// Réservée aux moments forts (ex. entrer en partie).
class HexWipePageRoute<T> extends PageRouteBuilder<T> {
  HexWipePageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 650),
          reverseTransitionDuration: const Duration(milliseconds: 450),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );
            return AnimatedBuilder(
              animation: curved,
              child: child,
              builder: (context, child) {
                return ClipPath(
                  clipper: _HexWipeClipper(curved.value),
                  child: child,
                );
              },
            );
          },
        );
}

class _HexWipeClipper extends CustomClipper<Path> {
  _HexWipeClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Rayon suffisant pour couvrir tout l'écran (jusqu'aux coins) une fois
    // l'hexagone pleinement ouvert.
    final maxRadius = size.longestSide * 0.75;
    final radius = maxRadius * progress;
    return _hexagonPath(center, radius);
  }

  Path _hexagonPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      // Pointe en haut, comme les tuiles du plateau.
      final angle = (math.pi / 3) * i - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _HexWipeClipper oldClipper) =>
      oldClipper.progress != progress;
}
