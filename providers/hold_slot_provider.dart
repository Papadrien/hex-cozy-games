/// État de l'Emplacement Joker (Hold) — Story B10.
///
/// Garde en mémoire une tuile "en réserve" que le joueur peut échanger
/// contre la tuile active de [tileStackProvider]. La logique d'échange
/// elle-même (qui touche aussi la pile et le compteur d'utilisations de la
/// Story B9) vit dans [swapHoldSlot] (`placement_commit.dart`) pour rester
/// cohérente avec le reste des opérations inter-providers (voir
/// [startNewGame], [undoPlacement]) — ce provider ne fait que stocker l'état.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../game/hex_tile.dart';

part 'hold_slot_provider.g.dart';

/// État de la tuile en réserve.
///
/// [heldTile] est `null` tant qu'aucune tuile n'a été mise en réserve.
class HoldSlotState {
  const HoldSlotState({this.heldTile});

  final HexTile? heldTile;

  bool get hasTile => heldTile != null;
}

@riverpod
class HoldSlot extends _$HoldSlot {
  @override
  HoldSlotState build() => const HoldSlotState();

  /// Remplace la tuile en réserve par [tile] (peut être `null` pour vider
  /// l'emplacement, par exemple quand la tuile en réserve est reprise et
  /// qu'aucune tuile active ne vient la remplacer).
  void set(HexTile? tile) {
    state = HoldSlotState(heldTile: tile);
  }
}
