/// Compteurs/badges par amélioration pour l'encart des améliorations actives
/// — Story B12b.
///
/// [upgradeCounterFor] centralise, pour chaque [UpgradeEffectType], la
/// décision de ce qu'il faut afficher en overlay sur son icône dans l'encart
/// (rien / un chiffre / un chiffre avec palier / une pastille de couleur) —
/// voir [UpgradeCounterInfo]. Logique volontairement pure (dépend uniquement
/// de l'état des providers au moment de l'appel) pour rester testable
/// isolément, sans monter de widget.
library;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_enums.dart';
import '../game/tile_component.dart' show BiomeColor;
import 'build_provider.dart';
import 'grid_state_provider.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';

/// Ce qu'il faut afficher en overlay sur l'icône d'une amélioration dans
/// l'encart des améliorations actives.
///
///  - [UpgradeCounterInfo.none] : aucun badge (icône seule).
///  - [UpgradeCounterInfo.number] : un chiffre en bas-droite, avec un palier
///    optionnel (ex. "7/15" pour Combo+ via [max], ou juste "2" pour
///    Emplacement Joker/Deuxième chance restants).
///  - [UpgradeCounterInfo.colorSwatch] : une pastille de la couleur du biome
///    concerné, seule, en bas-droite.
///  - [UpgradeCounterInfo.numberWithSwatch] : les deux à la fois (Couleur
///    détestée) — le chiffre (utilisations/tuiles restantes) reprend la
///    position bas-droite habituelle, la pastille de couleur passe en
///    haut-droite pour ne pas se superposer.
class UpgradeCounterInfo {
  const UpgradeCounterInfo._({this.value, this.max, this.swatchColor});

  /// Aucun badge à afficher.
  const UpgradeCounterInfo.none() : this._();

  /// Badge numérique (bas-droite). [max] optionnel affiche un palier
  /// ("value/max").
  const UpgradeCounterInfo.number(int value, {int? max})
      : this._(value: value, max: max);

  /// Badge pastille de couleur seule (bas-droite).
  const UpgradeCounterInfo.colorSwatch(Color color) : this._(swatchColor: color);

  /// Badge combiné : chiffre en bas-droite + pastille de couleur en
  /// haut-droite (Couleur détestée).
  const UpgradeCounterInfo.numberWithSwatch(int value, Color swatchColor)
      : this._(value: value, swatchColor: swatchColor);

  final int? value;
  final int? max;
  final Color? swatchColor;

  /// Vrai si un badge doit effectivement être rendu par-dessus l'icône.
  bool get hasBadge => value != null || swatchColor != null;
}

/// Calcule le badge à afficher pour l'amélioration [effectType], à partir
/// de l'état courant de la session/pile/grille.
///
/// [ref] doit permettre `watch` (widget en cours de build) pour que le
/// badge se mette à jour en temps réel — ne pas appeler depuis un
/// `ref.read` ponctuel hors build.
UpgradeCounterInfo upgradeCounterFor(WidgetRef ref, UpgradeEffectType effectType) {
  switch (effectType) {
    // Combo+ : progression cumulée (doubles connexions, plus besoin
    // d'affilée) vers le prochain palier (N = 10/8/5 selon niveau). Le
    // compteur brut ne se remet jamais à 0 (Story combo cumulatif) ; on
    // affiche donc la progression dans le cycle courant (1..interval),
    // et non le total cumulé, pour que le badge ("7/15") reste borné.
    case UpgradeEffectType.comboBonusTiles:
      final interval =
          ref.watch(activeUpgradeEffectsProvider).comboStreakInterval;
      if (interval <= 0) return const UpgradeCounterInfo.none();
      final total =
          ref.watch(sessionProvider.select((s) => s.currentDoubleStreak));
      final progress = total == 0 ? 0 : ((total - 1) % interval) + 1;
      return UpgradeCounterInfo.number(progress, max: interval);

    // Emplacement Joker / Deuxième chance : utilisations restantes cette
    // partie.
    case UpgradeEffectType.holdSlotUses:
      final remaining =
          ref.watch(sessionProvider.select((s) => s.holdSlotRemainingUses));
      return UpgradeCounterInfo.number(remaining);
    case UpgradeEffectType.secondChanceUses:
      final remaining = ref
          .watch(sessionProvider.select((s) => s.secondChanceRemainingUses));
      return UpgradeCounterInfo.number(remaining);

    // Couleur détestée (Story B12x+) : pendant une exclusion en cours,
    // pastille de la couleur du biome exclu + nombre de tuiles restantes
    // avant la fin de l'exclusion. En dehors (pas encore activée cette
    // partie, ou dernière exclusion déjà terminée), badge du nombre
    // d'utilisations restantes ("restant/max", ex. "1/2").
    case UpgradeEffectType.hatedColorExclusion:
      final stack = ref.watch(tileStackProvider);
      final placedCount =
          ref.watch(gridProvider.select((g) => g.placedTiles.length));
      final tilesRemaining = hatedColorTilesRemaining(stack, placedCount);
      if (tilesRemaining != null) {
        return UpgradeCounterInfo.numberWithSwatch(
          tilesRemaining,
          stack.excludeBiome!.color,
        );
      }
      final maxUses =
          ref.watch(activeUpgradeEffectsProvider).hatedColorExclusionUses;
      if (maxUses <= 0) return const UpgradeCounterInfo.none();
      final usesRemaining =
          ref.watch(sessionProvider.select((s) => s.hatedColorRemainingUses));
      return UpgradeCounterInfo.number(usesRemaining, max: maxUses);

    // Toutes les autres améliorations (Tuile bonus, Pièces+,
    // Rouge+/Vert+/Bleu+/Jaune+/Violet+, Bonus de clôture, Aperçu prolongé,
    // Tuiles de départ+, debug) : pas de compteur — seul le pulse/contour de
    // déclenchement (voir upgrade_feedback_provider.dart) donne le feedback.
    case UpgradeEffectType.startingTilesBonus:
    case UpgradeEffectType.connectionBonusMultiplier:
    case UpgradeEffectType.coinsPercentBonus:
    case UpgradeEffectType.villageCoinsPercentBonus:
    case UpgradeEffectType.forestCoinsPercentBonus:
    case UpgradeEffectType.waterCoinsPercentBonus:
    case UpgradeEffectType.plainCoinsPercentBonus:
    case UpgradeEffectType.mountainCoinsPercentBonus:
    case UpgradeEffectType.closureBonusTiles:
    case UpgradeEffectType.extendedPreviewCount:
    case UpgradeEffectType.millionaireCoins:
    case UpgradeEffectType.warehouseStartingTiles:
      return const UpgradeCounterInfo.none();
  }
}
