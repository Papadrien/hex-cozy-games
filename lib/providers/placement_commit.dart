
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/hex_coords.dart';
import '../game/hex_tile.dart';
import 'grid_state_provider.dart';
import 'placement_provider.dart';
import 'tile_stack_provider.dart';

class PlacementReward {
  const PlacementReward({required this.connectedSides, required this.bonusTiles});
  final List<int> connectedSides;
  final int bonusTiles;
}

class LastPlacement {
  LastPlacement(this.coords, this.tile);
  final HexCoords coords;
  final HexTile tile;
}

class LastPlacementNotifier extends Notifier<LastPlacement?> {
  @override
  LastPlacement? build() => null;

  void set(LastPlacement? last) => state = last;
}

final lastPlacementProvider =
    NotifierProvider<LastPlacementNotifier, LastPlacement?>(LastPlacementNotifier.new);

final previewRewardProvider = Provider<PlacementReward>((ref) {
  final placement = ref.watch(placementProvider);
  final tile = ref.watch(placementProvider.notifier).previewTile;
  if (placement.selected == null || tile == null) {
    return const PlacementReward(connectedSides: [], bonusTiles: 0);
  }
  final grid = ref.watch(gridProvider);
  final sides = <int>[];
  for (int side = 0; side < 6; side++) {
    final n = grid.tileAt(placement.selected!.neighbor(side));
    if (n != null && n.sides[(side + 3) % 6] == tile.sides[side]) sides.add(side);
  }
  final c = sides.length;
  final bonus = c >= 6 ? 10 : c == 5 ? 5 : c == 4 ? 2 : c == 3 ? 1 : 0;
  return PlacementReward(connectedSides: sides, bonusTiles: bonus);
});

class SessionSaver {
  static String? lastSnapshot;
  static void save(WidgetRef ref) {
    final grid = ref.read(gridProvider);
    lastSnapshot = jsonEncode({'tiles': grid.placedTiles.length});
  }
}

void confirmPlacement(WidgetRef ref) {
  final p = ref.read(placementProvider);
  final tile = ref.read(placementProvider.notifier).previewTile;
  if (p.selected == null || tile == null) return;
  ref.read(gridProvider.notifier).placeTile(p.selected!, tile);
  ref.read(lastPlacementProvider.notifier).set(LastPlacement(p.selected!, tile));
  ref.read(tileStackProvider.notifier).consumeActiveTile();
  ref.read(placementProvider.notifier).clearSelection();
  SessionSaver.save(ref);
}

void undoPlacement(WidgetRef ref) {
  final last = ref.read(lastPlacementProvider);
  if (last == null) return;
  ref.read(gridProvider.notifier).removeTile(last.coords);
  ref.read(lastPlacementProvider.notifier).set(null);
}
