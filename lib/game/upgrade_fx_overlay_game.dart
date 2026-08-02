/// Canevas Flame superposé, indépendant du plateau ([HexBoardGame]).
///
/// Contexte : dans `game_screen.dart`, le [GameWidget] du plateau est
/// empilé AVANT les widgets Flutter du HUD (encart des améliorations
/// actives, pile de tuiles, compteur de pièces...) — il doit rester en
/// dessous pour ne pas intercepter leurs gestes tactiles (le plateau reçoit
/// tous les gestes bruts sur tout l'écran). Conséquence : tout composant
/// Flame ajouté à la grille du plateau ([HexGridComponent]) est TOUJOURS
/// peint sous ces widgets HUD, quelle que soit sa priorité Flame interne —
/// la priorité ne réordonne que les éléments entre eux à l'intérieur d'un
/// même canevas, jamais vis-à-vis d'un widget Flutter externe qui se
/// trouve au-dessus dans le [Stack] parent.
///
/// Ça posait problème pour les particules de gain (pièce ou tuile bonus)
/// déclenchées par une amélioration (Combo+, Bonus de clôture, Pièces+...) :
/// leur point de départ est l'icône de l'amélioration dans le HUD
/// ([UpgradeHudAnchors]), donc elles apparaissaient visuellement SOUS cette
/// icône au lieu de s'envoler par-dessus.
///
/// Ce jeu superposé sert de "canevas du dessus" : ajouté en dernier dans le
/// [Stack] de `game_screen.dart` (donc peint après, par-dessus, le HUD), et
/// enrobé d'un `IgnorePointer` pour ne jamais intercepter de geste. Seules
/// les particules dont l'origine ou la destination coïncide avec une icône
/// HUD y sont ajoutées — celles déclenchées depuis la tuile posée
/// elle-même (bonus de connexion classique) continuent de vivre sur le
/// plateau, rien ne les recouvre à leur point de départ.
library;

import 'dart:ui' show Color;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

import 'bonus_animations.dart' show CoinComponent, BonusTileAnimComponent;

class UpgradeFxOverlayGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0x00000000);

  /// Fait s'envoler une pièce depuis [origin] (icône d'amélioration, HUD)
  /// vers [flyTarget] (compteur de pièces) — même animation que
  /// [HexGridComponent.showCoinParticleFrom], mais sur ce canevas du
  /// dessus.
  void spawnCoin(
    Vector2 origin, {
    required Vector2 flyTarget,
    required double hexSize,
    VoidCallback? onImpact,
    double startDelay = 0.0,
  }) {
    add(CoinComponent(
      position: origin.clone(),
      hexSize: hexSize,
      animated: true,
      flyTarget: flyTarget,
      onImpact: onImpact,
      startDelay: startDelay,
    ));
  }

  /// Fait s'envoler [count] icônes de tuile bonus INDIVIDUELLES depuis
  /// [origin] (icône d'amélioration, HUD) vers [flyTarget] (pile de
  /// tuiles) — même animation que [HexGridComponent.showBonusParticleFrom],
  /// mais sur ce canevas du dessus.
  void spawnBonusTiles(
    Vector2 origin,
    int count, {
    required double hexSize,
    required double staggerInterval,
    Vector2? flyTarget,
    VoidCallback? onImpact,
    int coinCount = 0,
  }) {
    for (var i = 0; i < count; i++) {
      add(BonusTileAnimComponent(
        position: origin.clone(),
        hexSize: hexSize,
        bonusCount: 1,
        flyTarget: flyTarget,
        startDelay: i * staggerInterval,
        onImpact: onImpact,
        totalBonusTiles: count,
        coinCount: coinCount,
      ));
    }
  }
}
