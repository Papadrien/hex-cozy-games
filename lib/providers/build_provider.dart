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
    this.coinsMultiplier = 0.0,
    this.villageCoinsBonus = 0.0,
    this.forestCoinsBonus = 0.0,
    this.waterCoinsBonus = 0.0,
    this.plainCoinsBonus = 0.0,
    this.mountainCoinsBonus = 0.0,
    this.comboBonusTiles = 0,
    this.extendedPreviewCount = 0,
    this.hatedColorExclusionDuration = 0,
    this.closureBonusTiles = 0,
    this.holdSlotUses = 0,
    this.secondChanceUses = 0,
  });

  /// Nombre de tuiles supplémentaires au début de la partie.
  final int startingTilesBonus;

  /// Niveau du bonus Connexions doublées (Story B8).
  /// 0 = inactif ; 1 = quint+sext ; 2 = +quad ; 3 = +triple.
  final int connectionBonusLevel;

  /// Multiplicateur de toutes les pièces générées (ex: 0.10 = +10%).
  final double coinsMultiplier;

  /// Bonus de pièces pour chaque côté connecté de type village
  /// (ex: 0.33 = +33% sur la pièce de base du côté).
  final double villageCoinsBonus;

  /// Bonus de pièces pour chaque côté connecté de type forêt (Vert+).
  final double forestCoinsBonus;

  /// Bonus de pièces pour chaque côté connecté de type eau (Bleu+).
  final double waterCoinsBonus;

  /// Bonus de pièces pour chaque côté connecté de type plaine (Jaune+).
  final double plainCoinsBonus;

  /// Bonus de pièces pour chaque côté connecté de type montagne (Violet+).
  final double mountainCoinsBonus;

  /// Nombre de tuiles bonus ajoutées à chaque pallier de 5 dans la série de
  /// connexions consécutives (Combo+ — Story B3).
  final int comboBonusTiles;

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
}

final activeUpgradeEffectsProvider = Provider<ActiveUpgradeEffects>((ref) {
  final selected = ref.watch(selectedUpgradesProvider);
  int startingBonus = 0;
  int connectionBonusLevel = 0;
  double coinsMult = 0.0;
  double villageBonus = 0.0;
  double forestBonus = 0.0;
  double waterBonus = 0.0;
  double plainBonus = 0.0;
  double mountainBonus = 0.0;
  int comboBonus = 0;
  int extendedPreviewCount = 0;
  int hatedColorExclusionDuration = 0;
  int closureBonus = 0;
  int holdSlotUses = 0;
  int secondChanceUses = 0;

  for (final u in selected) {
    final et = UpgradeEffectType.fromDb(u.effectType);
    final val = upgradeEffectValue(et, u.currentLevel);
    switch (et) {
      case UpgradeEffectType.startingTilesBonus:
        startingBonus += val.toInt();
      case UpgradeEffectType.connectionBonusMultiplier:
        connectionBonusLevel = val.toInt();
      case UpgradeEffectType.coinsPercentBonus:
        coinsMult += val;
      case UpgradeEffectType.villageCoinsPercentBonus:
        villageBonus += val;
      case UpgradeEffectType.forestCoinsPercentBonus:
        forestBonus += val;
      case UpgradeEffectType.waterCoinsPercentBonus:
        waterBonus += val;
      case UpgradeEffectType.plainCoinsPercentBonus:
        plainBonus += val;
      case UpgradeEffectType.mountainCoinsPercentBonus:
        mountainBonus += val;
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
        comboBonus += val.toInt();
    }
  }

  return ActiveUpgradeEffects(
    startingTilesBonus: startingBonus,
    connectionBonusLevel: connectionBonusLevel,
    coinsMultiplier: coinsMult,
    villageCoinsBonus: villageBonus,
    forestCoinsBonus: forestBonus,
    waterCoinsBonus: waterBonus,
    plainCoinsBonus: plainBonus,
    mountainCoinsBonus: mountainBonus,
    comboBonusTiles: comboBonus,
    extendedPreviewCount: extendedPreviewCount,
    hatedColorExclusionDuration: hatedColorExclusionDuration,
    closureBonusTiles: closureBonus,
    holdSlotUses: holdSlotUses,
    secondChanceUses: secondChanceUses,
  );
});

