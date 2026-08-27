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

/// Illustrations dédiées à chaque amélioration (power-up), indexées par
/// `upgradeId`. Les deux améliorations de debug (Millionnaire, Entrepôt)
/// n'ont pas d'illustration dédiée et gardent leur icône vectorielle
/// Material via [upgradeIconData].
const Map<String, String> _kUpgradeIconAssets = {
  'starting_tiles_plus': 'assets/images/power-ups/cargaison.png',
  'doubled_connections': 'assets/images/power-ups/maree_genereuse.png',
  'coins_plus': 'assets/images/power-ups/butin.png',
  'villages_plus': 'assets/images/power-ups/rouge.png',
  'combo_plus': 'assets/images/power-ups/alizes.png',
  'extended_preview': 'assets/images/power-ups/longue-vue.png',
  'hold_slot': 'assets/images/power-ups/sacoche.png',
  'second_chance': 'assets/images/power-ups/ressac.png',
  'forest_plus': 'assets/images/power-ups/vert.png',
  'water_plus': 'assets/images/power-ups/bleu.png',
  'plain_plus': 'assets/images/power-ups/jaune.png',
  'mountain_plus': 'assets/images/power-ups/violet.png',
  'closure_bonus': 'assets/images/power-ups/atoll.png',
  'hated_color': 'assets/images/power-ups/exil.png',
};

/// Badge d'amélioration : illustration PNG dédiée pour chaque power-up
/// identifié par `upgradeId` ; repli sur l'icône "savings" pour
/// [UpgradeEffectType.coinsPercentBonus] et sur l'icône vectorielle
/// Material standard pour les améliorations de debug (Millionnaire,
/// Entrepôt) qui n'ont pas d'illustration.
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
    final assetPath = _kUpgradeIconAssets[upgradeId];
    if (assetPath != null) {
      final image = Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
      // Les illustrations sont en couleurs fixes : pas de teinte (elle
      // dénaturerait le dessin), seule l'opacité de [color] est reprise
      // pour conserver le retour visuel sélectionné/non sélectionné.
      return color != null ? Opacity(opacity: color!.a, child: image) : image;
    }
    if (effectType == UpgradeEffectType.coinsPercentBonus) {
      return Icon(Icons.savings, color: color, size: size);
    }
    return Icon(upgradeIconData(effectType), color: color, size: size);
  }
}

