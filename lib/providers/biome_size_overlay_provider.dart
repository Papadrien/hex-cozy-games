/// Affichage à la demande des tailles de zones de couleur (Bonus de
/// clôture).
///
/// État booléen pur : actif après un appui sur le slot "Bonus de clôture"
/// de l'encart des améliorations actives, tant que le joueur ne retape pas
/// dessus pour le désactiver (même pattern que [SecondChanceMode] dans
/// `second_chance_provider.dart`). Pendant que ce mode est actif,
/// [HexBoardGame] recalcule [GridState.allBiomeClusters] à chaque
/// pose/retrait et transmet les clusters à [HexGridComponent] pour affichage
/// (voir `hex_grid_component.dart`, `biomeSizeClusters`).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biome_size_overlay_provider.g.dart';

@riverpod
class BiomeSizeOverlay extends _$BiomeSizeOverlay {
  @override
  bool build() => false;

  /// Bascule l'affichage (tap sur le slot "Bonus de clôture").
  void toggle() => state = !state;
}
