/// GameEffectsService — Story 2.8a / 2.8b.
///
/// Centralise les effets des améliorations dans le game loop :
///   - STARTING_TILES : modifie le stock initial
///   - CONNECTION_BONUS_MULTIPLIER : ajoute des tuiles bonus fixes sur les
///     connexions quintuple/sextuple (Tuile bonus)
///   - COINS_THRESHOLD : accorde 1 pièce bonus si le nombre de pièces de base
///     gagnées sur la pose atteint un seuil (Pièces+)
///   - BIOME_COINS_THRESHOLD : accorde 1 pièce bonus si le nombre de côtés
///     d'un biome connectés sur la pose atteint un seuil (Rouge+/Vert+/Bleu+/
///     Jaune+/Violet+)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_cell.dart';
import '../game/hex_tile.dart';
import 'build_provider.dart';

final gameEffectsServiceProvider =
    Provider<GameEffectsService>((ref) => GameEffectsService(ref));

class GameEffectsService {
  GameEffectsService(this._ref);
  final Ref _ref;

  /// Nombre de tuiles supplémentaires à ajouter dans la pioche de départ.
  int getStartingTilesBonus() {
    return _ref.read(activeUpgradeEffectsProvider).startingTilesBonus;
  }

  /// Applique le bonus Tuile bonus (remanié — ex "Connexions doublées").
  ///
  /// Ajoute un nombre fixe de tuiles bonus supplémentaires sur les
  /// connexions quintuple (5 côtés) et sextuple (6 côtés) uniquement,
  /// selon le niveau de l'amélioration : niveau 1 → +1, niveau 2 → +2,
  /// niveau 3 → +5. Base [kBonusScale] : quint +5, sext +10 → au niveau 3,
  /// ça donne +10 et +15.
  int applyBonusTileUpgrade(int connectedSides, int baseBonus) {
    if (connectedSides != 5 && connectedSides != 6) return baseBonus;
    final level =
        _ref.read(activeUpgradeEffectsProvider).connectionBonusLevel;
    const extraByLevel = {1: 1, 2: 2, 3: 5};
    return baseBonus + (extraByLevel[level] ?? 0);
  }

  /// Calcule les pièces finales après application des bonus — Story 2.8b / B1
  /// (revisité : modèle seuil « N pièces bonus pour N seuils atteints »,
  /// cumulable).
  ///
  /// Pour chaque type d'amélioration active (Pièces+ global, et
  /// Rouge+/Vert+/Bleu+/Jaune+/Violet+ par biome), accorde autant de pièces
  /// bonus que le seuil est contenu dans la quantité mesurée :
  ///   - bonus global : [baseCoins] ÷ [coinsThreshold]
  ///   - bonus village : [villageSides] ÷ [villageCoinsThreshold]
  ///   - bonus forêt   : [forestSides]  ÷ [forestCoinsThreshold]
  ///   - bonus eau     : [waterSides]   ÷ [waterCoinsThreshold]
  ///   - bonus plaine  : [plainSides]   ÷ [plainCoinsThreshold]
  ///   - bonus montagne: [mountainSides]÷ [mountainCoinsThreshold]
  ///
  /// Cumulable : une pose qui dépasse largement le seuil accorde plusieurs
  /// pièces bonus du même type (ex. seuil 2 côtés, 6 côtés connectés → 3
  /// pièces bonus), plutôt qu'une seule quelle que soit la quantité mesurée.
  int applyCoinBonuses({
    required int baseCoins,
    required int villageSides,
    int forestSides = 0,
    int waterSides = 0,
    int plainSides = 0,
    int mountainSides = 0,
  }) {
    final effects = _ref.read(activeUpgradeEffectsProvider);
    var total = baseCoins;
    if (effects.coinsThreshold > 0) {
      total += baseCoins ~/ effects.coinsThreshold;
    }
    if (effects.villageCoinsThreshold > 0) {
      total += villageSides ~/ effects.villageCoinsThreshold;
    }
    if (effects.forestCoinsThreshold > 0) {
      total += forestSides ~/ effects.forestCoinsThreshold;
    }
    if (effects.waterCoinsThreshold > 0) {
      total += waterSides ~/ effects.waterCoinsThreshold;
    }
    if (effects.plainCoinsThreshold > 0) {
      total += plainSides ~/ effects.plainCoinsThreshold;
    }
    if (effects.mountainCoinsThreshold > 0) {
      total += mountainSides ~/ effects.mountainCoinsThreshold;
    }
    return total;
  }

  /// Intervalle (en doubles connexions — 2 côtés connectés — cumulées sur
  /// la partie, sans condition d'affilée) déclenchant l'octroi d'une tuile
  /// bonus (Combo+ — Story B3). Valeurs : 10/8/5 selon niveau ;
  /// 0 = inactif.
  int getComboStreakInterval() {
    return _ref.read(activeUpgradeEffectsProvider).comboStreakInterval;
  }

  /// Multiplicateur du Bonus de clôture (Story B7) : à chaque fermeture de
  /// biome, [closureBonusTiles] tuiles bonus sont ajoutées par tranche de 10
  /// tuiles du cluster fermé — aucune tuile bonus en dessous de 10 tuiles,
  /// pas de plancher garanti (voir le correctif régression Atoll dans
  /// `placement_commit.dart`, [_applyReward]).
  int getClosureBonusTiles() {
    return _ref.read(activeUpgradeEffectsProvider).closureBonusTiles;
  }

  /// Compte le nombre de côtés connectés dont le biome est [biome].
  int countBiomeSides(BiomeType biome, HexTile tile, List<int> connectedSides) {
    return connectedSides
        .where((side) => tile.sides[side] == biome)
        .length;
  }
}
