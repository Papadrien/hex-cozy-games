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

/// Badge d'amélioration : image pièce pour [UpgradeEffectType.coinsPercentBonus],
/// icône vectorielle standard (teintée) pour tous les autres types
/// d'amélioration (série homogène de badges non liés aux pièces).
///
/// `coinsPercentBonus` est partagé par deux améliorations distinctes
/// (`coins_plus` et `jackpot_plus`) qui doivent maintenant afficher des
/// icônes différentes : `jackpot_plus` garde l'asset pièce (comportement
/// historique, [upgradeId] non fourni ou différent de `coins_plus`), tandis
/// que `coins_plus` passe à une icône "savings" dédiée.
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
      if (upgradeId == 'coins_plus') {
        return Icon(Icons.savings, color: color, size: size);
      }
      return CoinIcon(size: size);
    }
    return Icon(upgradeIconData(effectType), color: color, size: size);
  }
}

