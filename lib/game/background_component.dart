/// Fond d'écran du jeu — couleur eau turquoise unie.
library;

import 'dart:ui';

import 'package:flame/components.dart';

import '../core/colors.dart';

class BackgroundComponent extends PositionComponent {
  BackgroundComponent() : super(priority: 0);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = kGameBackground,
    );
  }
}
