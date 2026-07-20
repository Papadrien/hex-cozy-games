/// Build — améliorations sélectionnées avant une partie — Story 2.7b.
///
/// [selectedUpgradeIdsProvider] mémorise les IDs des améliorations choisies
/// par le joueur (0 à [kMaxSelectedUpgrades]). Le build persiste en mémoire
/// entre les runs (durée de vie de l'app).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_enums.dart';
import '../core/constants.dart';
import '../data/app_database.dart';
import 'progression_provider.dart';

/// IDs des améliorations actuellement sélectionnées pour le build (0–3).
final selectedUpgradeIdsProvider =
    NotifierProvider<SelectedUpgradeIdsNotifier, List<String>>(
        SelectedUpgradeIdsNotifier.new);

class SelectedUpgradeIdsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  bool isSelected(String id) => state.contains(id);

  void toggle(String id) {
    if (state.contains(id)) {
      state = [...state.where((s) => s != id)];
    } else if (state.length < kMaxSelectedUpgrades) {
      state = [...state, id];
    }
  }
}

/// Les améliorations sélectionnées (objets complets).
final selectedUpgradesProvider = Provider<List<UpgradeRow>>((ref) {
  final ids = ref.watch(selectedUpgradeIdsProvider);
  final all = ref.watch(upgradesProvider).maybeWhen(
        data: (list) => list,
        orElse: () => <UpgradeRow>[],
      );
  return all.where((u) => ids.contains(u.id)).toList();
});

/// Effets numériques actifs dérivés des améliorations sélectionnées.
///
/// Fournit les valeurs brutes que la logique de jeu utilise pour appliquer
/// les bonus : tuiles de départ supplémentaires, multiplicateurs, etc.
class ActiveUpgradeEffects {
  const ActiveUpgradeEffects({
    this.startingTilesBonus = 0,
    this.connectionBonusLevel = 0,
    this.coinsThreshold = 0,
    this.villageCoinsThreshold = 0,
    this.forestCoinsThreshold = 0,
    this.waterCoinsThreshold = 0,
    this.plainCoinsThreshold = 0,
    this.mountainCoinsThreshold = 0,
    this.comboStreakInterval = 0,
    this.extendedPreviewCount = 0,
    this.hatedColorExclusionDuration = 0,
    this.closureBonusTiles = 0,
    this.holdSlotUses = 0,
    this.secondChanceUses = 0,
    this.millionaireCoins = 0,
    this.warehouseStartingTiles = 0,
  });

  /// Nombre de tuiles supplémentaires au début de la partie.
  final int startingTilesBonus;

  /// Niveau du bonus Tuile bonus (ex "Connexions doublées", Story B8).
  /// 0 = inactif ; 1 = +1 tuile ; 2 = +2 tuiles ; 3 = +5 tuiles — sur les
  /// connexions quintuple/sextuple uniquement.
  final int connectionBonusLevel;

  /// Seuil (en pièces de base gagnées sur une pose) au-delà duquel 1 pièce
  /// bonus est accordée (Pièces+, Jackpot+). 0 = inactif ; 4/2/1 selon niveau.
  /// Non-cumulable : une seule pièce bonus par pose, même si baseCoins >> seuil.
  final int coinsThreshold;

  /// Seuil (en côtés village connectés sur une pose) au-delà duquel 1 pièce
  /// bonus est accordée (Rouge+). 0 = inactif ; 4/2/1 selon niveau.
  final int villageCoinsThreshold;

  /// Seuil (en côtés forêt connectés sur une pose) au-delà duquel 1 pièce
  /// bonus est accordée (Vert+). 0 = inactif ; 4/2/1 selon niveau.
  final int forestCoinsThreshold;

  /// Seuil (en côtés eau connectés sur une pose) au-delà duquel 1 pièce
  /// bonus est accordée (Bleu+). 0 = inactif ; 4/2/1 selon niveau.
  final int waterCoinsThreshold;

  /// Seuil (en côtés plaine connectés sur une pose) au-delà duquel 1 pièce
  /// bonus est accordée (Jaune+). 0 = inactif ; 4/2/1 selon niveau.
  final int plainCoinsThreshold;

  /// Seuil (en côtés montagne connectés sur une pose) au-delà duquel 1 pièce
  /// bonus est accordée (Violet+). 0 = inactif ; 4/2/1 selon niveau.
  final int mountainCoinsThreshold;

  /// Intervalle (en doubles connexions cumulées sur la partie, plus besoin
  /// d'être d'affilée) entre deux octrois d'une tuile bonus (Combo+ —
  /// Story B3). Valeurs : 10/8/5 selon niveau ; 0 = inactif. Une seule
  /// tuile bonus est accordée à chaque palier, quel que soit le niveau.
  final int comboStreakInterval;

  /// Nombre de tuiles visibles dans la pile d'attente (Story B4 — Aperçu
  /// prolongé). 0 = utiliser la valeur par défaut [kVisibleStackSize].
  final int extendedPreviewCount;

  /// Nombre de tuiles au début de la partie pendant lesquelles un biome
  /// aléatoire est exclu du pool (Story B5 — Couleur détestée).
  /// Valeurs : 5/8/10 selon niveau ; 0 = inactif.
  final int hatedColorExclusionDuration;

  /// Multiplicateur du Bonus de clôture (Story B7) : tuiles bonus = (taille du
  /// biome ÷ 10) × [closureBonusTiles] pour chaque fermeture détectée.
  /// Valeurs : 1/2/3 selon niveau ; 0 = inactif.
  final int closureBonusTiles;

  /// Nombre d'utilisations d'Emplacement Joker par partie (Story B9-B10).
  /// Valeurs : 1/2/3 selon niveau ; 0 = inactif.
  final int holdSlotUses;

  /// Nombre d'utilisations de Deuxième chance par partie (Story B9-B11).
  /// Valeurs : 1/2/3 selon niveau ; 0 = inactif.
  final int secondChanceUses;

  /// Millionnaire (debug) : pièces créditées au démarrage d'une partie.
  final int millionaireCoins;

  /// Entrepôt de tuiles (debug) : nombre de tuiles initiales dans la pile
  /// (remplace [kStartingTiles] si > 0).
  final int warehouseStartingTiles;
}

final activeUpgradeEffectsProvider = Provider<ActiveUpgradeEffects>((ref) {
  final selected = ref.watch(selectedUpgradesProvider);
  int startingBonus = 0;
  int connectionBonusLevel = 0;
  int coinsThreshold = 0;
  int villageThreshold = 0;
  int forestThreshold = 0;
  int waterThreshold = 0;
  int plainThreshold = 0;
  int mountainThreshold = 0;
  int comboStreakInterval = 0;
  int extendedPreviewCount = 0;
  int hatedColorExclusionDuration = 0;
  int closureBonus = 0;
  int holdSlotUses = 0;
  int secondChanceUses = 0;
  int millionaireCoins = 0;
  int warehouseStartingTiles = 0;

  for (final u in selected) {
    final et = UpgradeEffectType.fromDb(u.effectType);
    final val = upgradeEffectValue(et, u.currentLevel);
    switch (et) {
      case UpgradeEffectType.startingTilesBonus:
        startingBonus += val.toInt();
      case UpgradeEffectType.connectionBonusMultiplier:
        connectionBonusLevel = val.toInt();
      case UpgradeEffectType.coinsPercentBonus:
        // En cas de multiples améliorations globales sélectionnées (Pièces+ +
        // Jackpot+), on conserve le seuil le plus permissif (le plus petit).
        final v = val.toInt();
        if (v > 0 && (coinsThreshold == 0 || v < coinsThreshold)) {
          coinsThreshold = v;
        }
      case UpgradeEffectType.villageCoinsPercentBonus:
        final v = val.toInt();
        if (v > 0 && (villageThreshold == 0 || v < villageThreshold)) {
          villageThreshold = v;
        }
      case UpgradeEffectType.forestCoinsPercentBonus:
        final v = val.toInt();
        if (v > 0 && (forestThreshold == 0 || v < forestThreshold)) {
          forestThreshold = v;
        }
      case UpgradeEffectType.waterCoinsPercentBonus:
        final v = val.toInt();
        if (v > 0 && (waterThreshold == 0 || v < waterThreshold)) {
          waterThreshold = v;
        }
      case UpgradeEffectType.plainCoinsPercentBonus:
        final v = val.toInt();
        if (v > 0 && (plainThreshold == 0 || v < plainThreshold)) {
          plainThreshold = v;
        }
      case UpgradeEffectType.mountainCoinsPercentBonus:
        final v = val.toInt();
        if (v > 0 && (mountainThreshold == 0 || v < mountainThreshold)) {
          mountainThreshold = v;
        }
      case UpgradeEffectType.extendedPreviewCount:
        extendedPreviewCount = val.toInt();
        break;
      case UpgradeEffectType.hatedColorExclusion:
        hatedColorExclusionDuration = val.toInt();
        break;
      case UpgradeEffectType.closureBonusTiles:
        closureBonus = val.toInt();
        break;
      case UpgradeEffectType.holdSlotUses:
        holdSlotUses = val.toInt();
        break;
      case UpgradeEffectType.secondChanceUses:
        secondChanceUses = val.toInt();
        break;
      case UpgradeEffectType.comboBonusTiles:
        comboStreakInterval = val.toInt();
      case UpgradeEffectType.millionaireCoins:
        millionaireCoins = val.toInt();
      case UpgradeEffectType.warehouseStartingTiles:
        warehouseStartingTiles = val.toInt();
    }
  }

  return ActiveUpgradeEffects(
    startingTilesBonus: startingBonus,
    connectionBonusLevel: connectionBonusLevel,
    coinsThreshold: coinsThreshold,
    villageCoinsThreshold: villageThreshold,
    forestCoinsThreshold: forestThreshold,
    waterCoinsThreshold: waterThreshold,
    plainCoinsThreshold: plainThreshold,
    mountainCoinsThreshold: mountainThreshold,
    comboStreakInterval: comboStreakInterval,
    extendedPreviewCount: extendedPreviewCount,
    hatedColorExclusionDuration: hatedColorExclusionDuration,
    closureBonusTiles: closureBonus,
    holdSlotUses: holdSlotUses,
    secondChanceUses: secondChanceUses,
    millionaireCoins: millionaireCoins,
    warehouseStartingTiles: warehouseStartingTiles,
  );
});

