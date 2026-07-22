/// Tests pour CoinIcon et UpgradeEffectIcon (lib/ui/coin_icon.dart).
///
/// Couvre :
///  - CoinIcon affiche bien l'asset `assets/images/coin.png`, à la taille
///    par défaut (20) et à une taille personnalisée ;
///  - UpgradeEffectIcon affiche un CoinIcon pour
///    [UpgradeEffectType.coinsPercentBonus] (le seul type d'amélioration
///    représenté par l'asset pièce) ;
///  - UpgradeEffectIcon affiche une icône vectorielle standard (teintable)
///    pour tous les autres types d'amélioration — y compris les bonus
///    biome-spécifiques (village/forêt/eau/plaine/montagne), qui restent
///    volontairement sur une icône générique plutôt que l'asset pièce,
///    pour garder une série de badges homogène ;
///  - la couleur et la taille sont bien transmises à l'icône vectorielle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/core/game_enums.dart';
import 'package:hex_haven/ui/coin_icon.dart';

/// Tous les types d'amélioration autres que
/// [UpgradeEffectType.coinsPercentBonus] — y compris les bonus % pièces
/// spécifiques à un biome, qui NE sont PAS traités comme des icônes
/// "pièce" par [UpgradeEffectIcon] malgré leur lien avec les pièces.
const _nonCoinEffectTypes = [
  UpgradeEffectType.startingTilesBonus,
  UpgradeEffectType.connectionBonusMultiplier,
  UpgradeEffectType.villageCoinsPercentBonus,
  UpgradeEffectType.forestCoinsPercentBonus,
  UpgradeEffectType.waterCoinsPercentBonus,
  UpgradeEffectType.plainCoinsPercentBonus,
  UpgradeEffectType.mountainCoinsPercentBonus,
  UpgradeEffectType.closureBonusTiles,
  UpgradeEffectType.hatedColorExclusion,
  UpgradeEffectType.extendedPreviewCount,
  UpgradeEffectType.holdSlotUses,
  UpgradeEffectType.secondChanceUses,
  UpgradeEffectType.comboBonusTiles,
  UpgradeEffectType.millionaireCoins,
  UpgradeEffectType.warehouseStartingTiles,
];

void main() {
  testWidgets('CoinIcon affiche l\'asset coin.png à la taille par défaut',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CoinIcon())),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/images/coin.png');
    expect(image.width, 20);
    expect(image.height, 20);
  });

  testWidgets('CoinIcon respecte une taille personnalisée', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CoinIcon(size: 42))),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/images/coin.png');
    expect(image.width, 42);
    expect(image.height, 42);
  });

  testWidgets('UpgradeEffectIcon affiche un CoinIcon pour coinsPercentBonus',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UpgradeEffectIcon(
            effectType: UpgradeEffectType.coinsPercentBonus,
            size: 24,
          ),
        ),
      ),
    );

    expect(find.byType(CoinIcon), findsOneWidget);
    expect(find.byType(Icon), findsNothing);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 24);
  });

  for (final effectType in _nonCoinEffectTypes) {
    testWidgets(
        'UpgradeEffectIcon affiche une icône vectorielle (pas l\'asset '
        'pièce) pour $effectType', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpgradeEffectIcon(effectType: effectType),
          ),
        ),
      );

      expect(find.byType(CoinIcon), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });
  }

  testWidgets(
      'UpgradeEffectIcon transmet couleur et taille à l\'icône vectorielle',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UpgradeEffectIcon(
            effectType: UpgradeEffectType.closureBonusTiles,
            color: Colors.red,
            size: 30,
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, Colors.red);
    expect(icon.size, 30);
  });
}
