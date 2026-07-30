/// Tests unitaires pour les helpers purs du système d'améliorations
/// ([progression_provider.dart]).
///
/// Vérifie :
///  - [upgradeEffectValue] retourne la bonne valeur numérique pour chaque
///    type d'effet à tous les paliers, et se clamps hors-limite
///  - [upgradeAllLevelEffects] retourne les bonnes chaînes d'effet pour
///    chaque type d'effet
///  - [upgradeIconData] retourne une icône non-null pour chaque type d'effet
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/core/game_enums.dart';
import 'package:hex_haven/providers/progression_provider.dart';

void main() {
  group('upgradeEffectValue', () {
    test('startingTilesBonus → 2, 5, 10', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.startingTilesBonus, 0),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.startingTilesBonus, 1),
        5.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.startingTilesBonus, 2),
        10.0,
      );
    });

    test('connectionBonusMultiplier → 1, 2, 3 (palier transmis à applyBonusTileUpgrade)', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.connectionBonusMultiplier, 0),
        1.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.connectionBonusMultiplier, 1),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.connectionBonusMultiplier, 2),
        3.0,
      );
    });

    test('coinsPercentBonus → 8, 4, 2 (seuils)', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.coinsPercentBonus, 0),
        8.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.coinsPercentBonus, 1),
        4.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.coinsPercentBonus, 2),
        2.0,
      );
    });

    test('villageCoinsPercentBonus → 4, 2, 1 (seuils)', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.villageCoinsPercentBonus, 0),
        4.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.villageCoinsPercentBonus, 1),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.villageCoinsPercentBonus, 2),
        1.0,
      );
    });

    test('forestCoinsPercentBonus → 4, 2, 1 (seuils)', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.forestCoinsPercentBonus, 0),
        4.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.forestCoinsPercentBonus, 1),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.forestCoinsPercentBonus, 2),
        1.0,
      );
    });

    test('waterCoinsPercentBonus → 4, 2, 1 (seuils)', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.waterCoinsPercentBonus, 0),
        4.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.waterCoinsPercentBonus, 1),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.waterCoinsPercentBonus, 2),
        1.0,
      );
    });

    test('plainCoinsPercentBonus → 4, 2, 1 (seuils)', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.plainCoinsPercentBonus, 0),
        4.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.plainCoinsPercentBonus, 1),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.plainCoinsPercentBonus, 2),
        1.0,
      );
    });

    test('mountainCoinsPercentBonus → 4, 2, 1 (seuils)', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.mountainCoinsPercentBonus, 0),
        4.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.mountainCoinsPercentBonus, 1),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.mountainCoinsPercentBonus, 2),
        1.0,
      );
    });

    test('closureBonusTiles → 1, 2, 3', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.closureBonusTiles, 0),
        1.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.closureBonusTiles, 1),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.closureBonusTiles, 2),
        3.0,
      );
    });

    test('hatedColorExclusion → 5, 8, 10', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.hatedColorExclusion, 0),
        5.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.hatedColorExclusion, 1),
        8.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.hatedColorExclusion, 2),
        10.0,
      );
    });

    test('hatedColorExclusionUsesForLevel → 1, 2, 3', () {
      expect(hatedColorExclusionUsesForLevel(0), 1);
      expect(hatedColorExclusionUsesForLevel(1), 2);
      expect(hatedColorExclusionUsesForLevel(2), 3);
    });

    test('extendedPreviewCount → 4, 5, 6', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.extendedPreviewCount, 0),
        4.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.extendedPreviewCount, 1),
        5.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.extendedPreviewCount, 2),
        6.0,
      );
    });

    test('holdSlotUses → 1, 2, 3', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.holdSlotUses, 0),
        1.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.holdSlotUses, 1),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.holdSlotUses, 2),
        3.0,
      );
    });

    test('secondChanceUses → 1, 2, 3', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.secondChanceUses, 0),
        1.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.secondChanceUses, 1),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.secondChanceUses, 2),
        3.0,
      );
    });

    test('comboBonusTiles → 10, 8, 5 (intervalle)', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.comboBonusTiles, 0),
        10.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.comboBonusTiles, 1),
        8.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.comboBonusTiles, 2),
        5.0,
      );
    });

    test('millionaireCoins → toujours 1000000', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.millionaireCoins, 0),
        1000000.0,
      );
    });

    test('warehouseStartingTiles → toujours 500', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.warehouseStartingTiles, 0),
        500.0,
      );
    });

    test('se clamps si level dépasse le nombre de paliers', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.coinsPercentBonus, 99),
        2.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.startingTilesBonus, 99),
        10.0,
      );
    });

    test('se clamps si level négatif', () {
      expect(
        upgradeEffectValue(UpgradeEffectType.coinsPercentBonus, -1),
        8.0,
      );
      expect(
        upgradeEffectValue(UpgradeEffectType.startingTilesBonus, -5),
        2.0,
      );
    });
  });

  group('upgradeAllLevelEffects', () {
    test('startingTilesBonus → +2, +5, +10 tuiles de départ', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.startingTilesBonus),
        ['+2 tuiles de départ', '+5 tuiles de départ', '+10 tuiles de départ'],
      );
    });

    test('connectionBonusMultiplier → +1/2/5 tuiles bonus (connexion 5-6)', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.connectionBonusMultiplier),
        [
          '+1 tuile bonus (connexion 5-6)',
          '+2 tuiles bonus (connexion 5-6)',
          '+5 tuiles bonus (connexion 5-6)',
        ],
      );
    });

    test('coinsPercentBonus → +1 pièce par tranche de 8/4/2 pièces', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.coinsPercentBonus),
        [
          '+1 pièce par tranche de 8 pièces',
          '+1 pièce par tranche de 4 pièces',
          '+1 pièce par tranche de 2 pièces',
        ],
      );
    });

    test('villageCoinsPercentBonus → +1 pièce par tranche de 4/2/1 côtés', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.villageCoinsPercentBonus),
        ['+1 pièce par tranche de 4 côtés', '+1 pièce par tranche de 2 côtés', '+1 pièce par côté'],
      );
    });

    test('forest/water/plain/mountain → +1 pièce par tranche de 4/2/1 côtés', () {
      const expected = [
        '+1 pièce par tranche de 4 côtés',
        '+1 pièce par tranche de 2 côtés',
        '+1 pièce par côté',
      ];
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.forestCoinsPercentBonus),
        expected,
      );
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.waterCoinsPercentBonus),
        expected,
      );
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.plainCoinsPercentBonus),
        expected,
      );
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.mountainCoinsPercentBonus),
        expected,
      );
    });

    test('closureBonusTiles → +1/2/3 tuiles bonus / 10 tuiles de la zone', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.closureBonusTiles),
        [
          '+1 tuile bonus / 10 tuiles de la zone',
          '+2 tuiles bonus / 10 tuiles de la zone',
          '+3 tuiles bonus / 10 tuiles de la zone',
        ],
      );
    });

    test('hatedColorExclusion → 5/1, 8/2, 10/3 (tuiles/usages)', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.hatedColorExclusion),
        [
          'Exclut une couleur (5 tuiles), 1 usage',
          'Exclut une couleur (8 tuiles), 2 usages',
          'Exclut une couleur (10 tuiles), 3 usages',
        ],
      );
    });

    test('extendedPreviewCount → voir 4, 5, 6 tuiles à venir', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.extendedPreviewCount),
        ['Voir 4 tuiles à venir', 'Voir 5 tuiles à venir', 'Voir 6 tuiles à venir'],
      );
    });

    test('holdSlotUses → stocke une tuile, 1, 2, 3 usages', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.holdSlotUses),
        [
          'Stocke une tuile, 1 usage',
          'Stocke une tuile, 2 usages',
          'Stocke une tuile, 3 usages',
        ],
      );
    });

    test('secondChanceUses → retire une tuile posée, 1, 2, 3 usages', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.secondChanceUses),
        [
          'Retire une tuile posée, 1 usage',
          'Retire une tuile posée, 2 usages',
          'Retire une tuile posée, 3 usages',
        ],
      );
    });

    test('comboBonusTiles → tuile bonus toutes les 10/8/5 doubles connexions', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.comboBonusTiles),
        [
          'Tuile bonus toutes les 10 doubles connexions',
          'Tuile bonus toutes les 8 doubles connexions',
          'Tuile bonus toutes les 5 doubles connexions',
        ],
      );
    });

    test('millionaireCoins → +1 000 000 pièces', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.millionaireCoins),
        ['+1 000 000 pièces'],
      );
    });

    test('warehouseStartingTiles → +500 tuiles de départ', () {
      expect(
        upgradeAllLevelEffects(UpgradeEffectType.warehouseStartingTiles),
        ['+500 tuiles de départ'],
      );
    });
  });

  group('upgradeIconData', () {
    test('retourne une icône Material non-null pour chaque type', () {
      for (final type in UpgradeEffectType.values) {
        final icon = upgradeIconData(type);
        expect(icon, isA<IconData>(), reason: '$type doit avoir une icône');
      }
    });

    test('chaque type d\'effet non-biome a une icône différente', () {
      final icons = UpgradeEffectType.values.map(upgradeIconData).toSet();
      expect(icons.length, 12,
          reason: 'les 5 types biome partagent Icons.circle → 12 icônes uniques');
    });
  });
}
