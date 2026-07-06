/// Mode sélection de Deuxième chance — Story B11.
///
/// État booléen pur : actif après un appui sur le bouton HUD dédié, tant
/// que le joueur n'a pas encore tapé une tuile posée sur le plateau (ou
/// annulé). L'orchestration cross-provider (activation conditionnée aux
/// utilisations restantes de la Story B9, retrait effectif de la tuile,
/// réinjection en pile) vit dans `placement_commit.dart`
/// ([toggleSecondChanceMode], [removePlacedTile]) — même séparation que
/// pour l'Emplacement Joker (voir `hold_slot_provider.dart`).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'second_chance_provider.g.dart';

@riverpod
class SecondChanceMode extends _$SecondChanceMode {
  @override
  bool build() => false;

  /// Active le mode sélection.
  void activate() => state = true;

  /// Désactive le mode sélection (annulation, ou après un retrait effectué).
  void cancel() => state = false;
}
