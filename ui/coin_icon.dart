import 'package:flutter/material.dart';

import '../core/game_enums.dart';
import '../providers/progression_provider.dart' show upgradeIconData;

/// Icône "pièce" de l'application — remplace l'ancienne icône Material
/// [Icons.monetization_on] par l'asset `assets/images/coin.png` partout où
/// une pièce est représentée dans l'UI (compteurs, récompenses, quêtes...).
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/coin.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Badge d'amélioration : icône "savings" pour [UpgradeEffectType.coinsPercentBonus]
/// (porté uniquement par `coins_plus`), icône vectorielle standard (teintée)
/// pour tous les autres types d'amélioration (série homogène de badges non
/// liés aux pièces).
class UpgradeEffectIcon extends StatelessWidget {
  const UpgradeEffectIcon({
    super.key,
    required this.effectType,
    this.upgradeId,
    this.color,
    this.size = 20,
  });

  final UpgradeEffectType effectType;
  final String? upgradeId;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (effectType == UpgradeEffectType.coinsPercentBonus) {
      return Icon(Icons.savings, color: color, size: size);
    }
    return Icon(upgradeIconData(effectType), color: color, size: size);
  }
}

