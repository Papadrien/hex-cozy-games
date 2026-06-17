import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Point d'entrée Flame du jeu.
///
/// Pour la story 1.1, ce `FlameGame` ne fait qu'afficher un fond coloré afin
/// de valider l'intégration du `GameWidget` dans l'écran Flutter. La grille
/// hexagonale, les tuiles et la caméra isométrique seront implémentées dans
/// les stories suivantes (1.2 et 1.3).
class HexBoardGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF2B6CB0);
}
