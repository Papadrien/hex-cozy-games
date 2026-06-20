/// Build — améliorations sélectionnées avant une partie — Story 2.7b.
///
/// [selectedUpgradeIdsProvider] mémorise les IDs des améliorations choisies
/// par le joueur (0 à [kMaxSelectedUpgrades]). Le build persiste en mémoire
/// entre les runs (durée de vie de l'app).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.connectionMultiplier = 1.0,
    this.coinsMultiplier = 0.0,
    this.villageCoinsBonus = 0.0,
  });

  /// Nombre de tuiles supplémentaires au début de la partie.
  final int startingTilesBonus;

  /// Multiplicateur des tuiles bonus gagnées par connexions (≥3 côtés).
  final double connectionMultiplier;

  /// Multiplicateur de toutes les pièces générées (ex: 0.10 = +10%).
  final double coinsMultiplier;

  /// Bonus de pièces pour chaque côté connecté de type village
  /// (ex: 0.33 = +33% sur la pièce de base du côté).
  final double villageCoinsBonus;
}

final activeUpgradeEffectsProvider = Provider<ActiveUpgradeEffects>((ref) {
  final selected = ref.watch(selectedUpgradesProvider);
  int startingBonus = 0;
  double connectionMult = 1.0;
  double coinsMult = 0.0;
  double villageBonus = 0.0;

  for (final u in selected) {
    final val = upgradeEffectValue(u.effectType, u.currentLevel);
    switch (u.effectType) {
      case 'starting_tiles_bonus':
        startingBonus += val.toInt();
      case 'connection_bonus_multiplier':
        connectionMult *= val;
      case 'coins_percent_bonus':
        coinsMult += val;
      case 'village_coins_percent_bonus':
        villageBonus += val;
    }
  }

  return ActiveUpgradeEffects(
    startingTilesBonus: startingBonus,
    connectionMultiplier: connectionMult,
    coinsMultiplier: coinsMult,
    villageCoinsBonus: villageBonus,
  );
});

