import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../game/hex_coords.dart';
import '../game/hex_tile.dart';
import 'grid_state_provider.dart';
import 'placement_provider.dart';
import 'reward_model.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';

class LastPlacement {
  LastPlacement(this.coords, this.tile, {this.bonusTiles = 0});
  final HexCoords coords;
  final HexTile tile;
  final int bonusTiles;
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
    if (n != null && n.sides[(side + 3) % 6] == tile.sides[side]) {
      sides.add(side);
    }
  }
  final c = sides.length;
  final bonus = c >= 6 ? 10 : c == 5 ? 5 : c == 4 ? 2 : c == 3 ? 1 : 0;
  return PlacementReward(connectedSides: sides, bonusTiles: bonus);
});

/// Persiste l'état de session dans Drift après chaque placement (Story 1.7a).
///
/// Stocke l'intégralité de l'état nécessaire à une restauration fidèle :
/// plateau, pile, pièces, tuiles bonus, dernier placement (pour annuler).
class SessionSaver {
  static void save(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final grid = ref.read(gridProvider);
    final stack = ref.read(tileStackProvider);
    final session = ref.read(sessionProvider);
    final lastPlacement = ref.read(lastPlacementProvider);

    final gridJson = jsonEncode(
      grid.placedTiles.map(
        (k, v) => MapEntry('${k.q},${k.r}', v.sides.map((b) => b.name).toList()),
      ),
    );

    final stackJson = jsonEncode({
      'remaining': stack.remaining,
      'visible': stack.visible
          .map((t) => t.sides.map((b) => b.name).toList())
          .toList(),
    });

    String? lastTileJson;
    if (lastPlacement != null) {
      lastTileJson = jsonEncode({
        'q': lastPlacement.coords.q,
        'r': lastPlacement.coords.r,
        'sides': lastPlacement.tile.sides.map((b) => b.name).toList(),
        'bonusTiles': lastPlacement.bonusTiles,
      });
    }

    await db.into(db.gameSession).insert(
          GameSessionRow(
            id: 1, // Session unique pour le MVP
            gridState: gridJson,
            tileStack: stackJson,
            coins: session.coins,
            totalBonusTiles: session.totalBonusTiles,
            lastTilePlaced: lastTileJson,
            placedTilesCount: grid.placedTiles.length,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.replace,
        );
  }

  /// Marque la session active comme terminée (fin de partie ou abandon).
  static Future<void> endSession(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.gameSession)..where((t) => t.id.equals(1)))
        .write(const GameSessionCompanion(isActive: Value(false)));
  }
}

/// Valide le placement de la tuile prévisualisée et attribue les récompenses.
///
/// [onConfirm] : callback appelé avec les coordonnées, la tuile, la liste
/// des côtés connectés et le nombre de tuiles bonus pour mettre à jour le
/// rendu Flame (HexGridComponent).
/// Découplé du provider pour éviter une dépendance circulaire providers → Flame.
void confirmPlacement(
  WidgetRef ref, {
  required void Function(HexCoords coords, HexTile tile, List<int> connectedSides, int bonusTiles) onConfirm,
}) {
  final p = ref.read(placementProvider);
  final tile = ref.read(placementProvider.notifier).previewTile;
  if (p.selected == null || tile == null) return;

  final coords = p.selected!;
  final reward = ref.read(previewRewardProvider);

  // 1. Mettre à jour le provider de grille (logique pure).
  ref.read(gridProvider.notifier).placeTile(coords, tile);

  // 2. Mettre à jour le rendu Flame via le callback (avec les connexions).
  onConfirm(coords, tile, reward.connectedSides, reward.bonusTiles);

  // 3. Mémoriser pour le bouton Annuler (avec les bonus pour l'undo).
  ref.read(lastPlacementProvider.notifier).set(
    LastPlacement(coords, tile, bonusTiles: reward.bonusTiles),
  );

  // 4. Attribuer les récompenses (story 1.6b).
  if (reward.bonusTiles > 0) {
    ref.read(sessionProvider.notifier).addReward(reward);
    ref.read(tileStackProvider.notifier).addBonusTiles(reward.bonusTiles);
  }

  // 5. Avancer la pile de tuiles.
  ref.read(tileStackProvider.notifier).consumeActiveTile();

  // 6. Effacer la prévisualisation.
  ref.read(placementProvider.notifier).clearSelection();

  // 7. Sauvegarde de session.
  SessionSaver.save(ref);
}

/// Annule le dernier placement.
///
/// [onUndo] : callback pour retirer la tuile du rendu Flame.
void undoPlacement(
  WidgetRef ref, {
  required void Function(HexCoords coords) onUndo,
}) {
  final last = ref.read(lastPlacementProvider);
  if (last == null) return;

  // 1. Retirer du provider de grille (logique pure).
  ref.read(gridProvider.notifier).removeTile(last.coords);

  // 2. Retirer du rendu Flame via le callback.
  onUndo(last.coords);

  // 3. Remettre la tuile au sommet de la pile.
  ref.read(tileStackProvider.notifier).returnTile(last.tile);

  // 4. Annuler les récompenses (story 1.6b).
  if (last.bonusTiles > 0) {
    ref.read(sessionProvider.notifier).removeReward(last.bonusTiles);
    ref.read(tileStackProvider.notifier).removeLastBonusTiles(last.bonusTiles);
  }

  // 5. Effacer la mémoire d'annulation (1 seul niveau).
  ref.read(lastPlacementProvider.notifier).set(null);
}
