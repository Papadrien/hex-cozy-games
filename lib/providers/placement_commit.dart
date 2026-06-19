import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../game/hex_cell.dart';
import '../game/hex_coords.dart';
import '../game/hex_tile.dart';
import 'end_game_provider.dart';
import 'grid_state_provider.dart';
import 'placement_provider.dart';
import 'reward_model.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';

/// Vérifie si une session active existe en base (Story 1.7b).
final activeSessionProvider = FutureProvider<bool>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final rows = await (db.select(db.gameSession)
        ..where((t) => t.isActive.equals(true))
        ..limit(1))
      .get();
  return rows.isNotEmpty;
});

/// Restaure l'état complet d'une session active depuis la base.
///
/// À appeler avant de naviguer vers l'écran de jeu pour que les providers
/// soient déjà initialisés lors de la création du [HexBoardGame].
Future<void> restoreSession(WidgetRef ref) async {
  final db = ref.read(appDatabaseProvider);
  final rows = await (db.select(db.gameSession)
        ..where((t) => t.isActive.equals(true))
        ..limit(1))
      .get();
  if (rows.isEmpty) return;

  final row = rows.first;

  // Restaurer le plateau.
  final gridJson =
      jsonDecode(row.gridState) as Map<String, dynamic>;
  final placedTiles = <HexCoords, HexTile>{};
  for (final entry in gridJson.entries) {
    final parts = entry.key.split(',');
    final q = int.parse(parts[0]);
    final r = int.parse(parts[1]);
    final sides = (entry.value as List)
        .map((s) => BiomeType.values.firstWhere((b) => b.name == s))
        .toList();
    placedTiles[HexCoords(q, r)] = HexTile(sides: sides);
  }
  ref.read(gridProvider.notifier).setState(placedTiles);

  // Restaurer la pile de tuiles.
  final stackJson = jsonDecode(row.tileStack);
  final queueList = (stackJson['queue'] as List)
      .map((t) => (t as List)
          .map((s) => BiomeType.values.firstWhere((b) => b.name == s))
          .toList())
      .map((sides) => HexTile(sides: sides))
      .toList();
  ref.read(tileStackProvider.notifier).restoreQueue(queueList);

  // Restaurer la session (pièces, tuiles bonus).
  ref.read(sessionProvider.notifier).restore(SessionState(
        coins: row.coins,
        totalBonusTiles: row.totalBonusTiles,
      ));

  // Restaurer le dernier placement (pour le bouton Annuler).
  if (row.lastTilePlaced != null) {
    final lastJson = jsonDecode(row.lastTilePlaced!);
    final sides = (lastJson['sides'] as List)
        .map((s) => BiomeType.values.firstWhere((b) => b.name == s))
        .toList();
    final tile = HexTile(sides: sides);
    final connectedSides = (lastJson['connectedSides'] as List?)
            ?.cast<int>() ??
        [];
    ref.read(lastPlacementProvider.notifier).set(LastPlacement(
          HexCoords(lastJson['q'], lastJson['r']),
          tile,
          bonusTiles: lastJson['bonusTiles'] ?? 0,
          connectedSides: connectedSides,
        ));
  }
}

class LastPlacement {
  LastPlacement(this.coords, this.tile,
      {this.bonusTiles = 0, this.connectedSides = const []});
  final HexCoords coords;
  final HexTile tile;
  final int bonusTiles;
  final List<int> connectedSides;
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

    final queue = ref.read(tileStackProvider.notifier).queue;
    final queueJson =
        queue.map((t) => t.sides.map((b) => b.name).toList()).toList();
    final stackJson = jsonEncode({
      'remaining': stack.remaining,
      'visible':
          stack.visible.map((t) => t.sides.map((b) => b.name).toList()).toList(),
      'queue': queueJson,
    });

    String? lastTileJson;
    if (lastPlacement != null) {
      lastTileJson = jsonEncode({
        'q': lastPlacement.coords.q,
        'r': lastPlacement.coords.r,
        'sides': lastPlacement.tile.sides.map((b) => b.name).toList(),
        'bonusTiles': lastPlacement.bonusTiles,
        'connectedSides': lastPlacement.connectedSides,
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

  // 3. Mémoriser pour le bouton Annuler (avec les récompenses pour l'undo).
  ref.read(lastPlacementProvider.notifier).set(
    LastPlacement(coords, tile,
        bonusTiles: reward.bonusTiles,
        connectedSides: List.of(reward.connectedSides)),
  );

  // 4. Attribuer les récompenses (story 1.6b / 1.7c).
  ref.read(sessionProvider.notifier).addReward(reward);
  if (reward.bonusTiles > 0) {
    ref.read(tileStackProvider.notifier).addBonusTiles(reward.bonusTiles);
  }

  // 5. Avancer la pile de tuiles.
  ref.read(tileStackProvider.notifier).consumeActiveTile();

  // 6. Effacer la prévisualisation.
  ref.read(placementProvider.notifier).clearSelection();

  // 7. Sauvegarde de session.
  SessionSaver.save(ref);

  // 8. Détection de fin de partie (Story 1.8a).
  final remaining = ref.read(tileStackProvider).remaining;
  if (remaining == 0) {
    final grid = ref.read(gridProvider);
    final session = ref.read(sessionProvider);
    final stats = computeEndGameStats(grid, session.coins);

    ref.read(isGameOverProvider.notifier).state = true;
    ref.read(endGameStatsProvider.notifier).state = stats;

    SessionSaver.endSession(ref);
  }
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

  // 4. Annuler les récompenses (story 1.6b / 1.7c).
  ref.read(sessionProvider.notifier).removeReward(
      last.connectedSides.length + last.bonusTiles, last.bonusTiles);
  if (last.bonusTiles > 0) {
    ref.read(tileStackProvider.notifier).removeLastBonusTiles(last.bonusTiles);
  }

  // 5. Effacer la mémoire d'annulation (1 seul niveau).
  ref.read(lastPlacementProvider.notifier).set(null);
}
