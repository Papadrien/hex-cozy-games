import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/app_database.dart';
import '../game/hex_coords.dart';
import '../game/hex_tile.dart';
import '../services/cloud_save_service.dart';
import 'end_game_provider.dart';
import 'game_effects_service.dart';
import 'grid_state_provider.dart';
import 'placement_provider.dart';
import 'player_profile_provider.dart';
import 'player_stats_provider.dart';
import 'quest_provider.dart';
import 'reward_model.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';

/// Vérifie si une session active existe en base (Story 1.7b).
final activeSessionProvider = FutureProvider<bool>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final rows = await (db.select(db.activeBoardSession)
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
  try {
    final db = ref.read(appDatabaseProvider);
    final rows = await (db.select(db.activeBoardSession)
          ..where((t) => t.isActive.equals(true))
          ..limit(1))
        .get();
    if (rows.isEmpty) return;

    final row = rows.first;

    // Restaurer le plateau.
    final gridJson = jsonDecode(row.gridState) as Map<String, dynamic>;
    ref.read(gridProvider.notifier)
        .setState(GridState.fromJson(gridJson).placedTiles);

    // Restaurer la pile de tuiles.
    final stackJson = jsonDecode(row.tileStack);
    final seed = stackJson['seed'] as int?;
    final queueList = (stackJson['queue'] as List)
        .map((t) => HexTile.fromJson({'sides': t}))
        .toList();
    ref.read(tileStackProvider.notifier).restoreQueue(queueList, seed: seed);

    // Restaurer la session (pièces, tuiles bonus).
    ref.read(sessionProvider.notifier).restore(SessionState(
          coins: row.coins,
          totalBonusTiles: row.totalBonusTiles,
        ));

    // Restaurer le dernier placement (pour le bouton Annuler).
    if (row.lastTilePlaced != null) {
      final lastJson = jsonDecode(row.lastTilePlaced!) as Map<String, dynamic>;
      final tile = HexTile.fromJson(lastJson);
      final connectedSides =
          (lastJson['connectedSides'] as List?)?.cast<int>() ?? [];
      ref.read(lastPlacementProvider.notifier).set(LastPlacement(
            HexCoords(lastJson['q'] as int, lastJson['r'] as int),
            tile,
            bonusTiles: lastJson['bonusTiles'] as int? ?? 0,
            connectedSides: connectedSides,
          ));
    }
  } catch (e, stack) {
    FirebaseCrashlytics.instance.recordError(e, stack);
    startNewGame(ref);
  }
}

/// Initialise une nouvelle partie : remet à zéro tous les providers de jeu
/// (grille, pile, session, dernier placement, prévisualisation, fin de
/// partie), puis pioche et pose automatiquement une tuile aléatoire au
/// centre du plateau (0, 0), laissant [kStartingTiles] - 1 tuiles en pile.
///
/// Centralisé ici pour être appelé identiquement depuis l'écran d'accueil
/// (nouvelle partie) et l'écran de résultats (rejouer) — évite que l'un des
/// deux flux oublie de vider le dernier placement (bug du bouton Annuler
/// permettant de regagner une tuile gratuite après une nouvelle partie).
void startNewGame(WidgetRef ref) {
  ref.invalidate(gridProvider);
  ref.invalidate(tileStackProvider);
  ref.read(sessionProvider.notifier).reset();
  ref.read(lastPlacementProvider.notifier).set(null);
  ref.read(placementProvider.notifier).clearSelection();
  resetEndGame(ref);

  // Appliquer le bonus de tuiles de départ (Story 2.8a).
  final effects = ref.read(gameEffectsServiceProvider);
  final bonus = effects.getStartingTilesBonus();
  if (bonus > 0) {
    ref.read(tileStackProvider.notifier).addBonusTiles(bonus);
  }

  // Pose automatique de la tuile centrale de départ.
  final initialTile = ref.read(tileStackProvider.notifier).drawInitialTile();
  if (initialTile != null) {
    ref.read(gridProvider.notifier).placeTile(const HexCoords(0, 0), initialTile);
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
  final baseBonus = kBonusScale[c] ?? 0;

  // Appliquer le multiplicateur de tuiles bonus (Story 2.8a).
  final effects = ref.read(gameEffectsServiceProvider);
  final multipliedBonus = effects.applyConnectionMultiplier(baseBonus);

  return PlacementReward(connectedSides: sides, bonusTiles: multipliedBonus);
});

/// Analyse unique du plateau calculée en fin de partie pour éviter les
/// traversées redondantes (Item 6).
class BoardAnalysis {
  final int largestVillage;
  final int closedBiomes;
  final Map<String, int> maxBiomeSizes;

  BoardAnalysis.fromGrid(GridState grid)
      : largestVillage = grid.largestVillage,
        closedBiomes = grid.closedBiomes,
        maxBiomeSizes = grid.maxBiomeSizes;
}

/// Persiste l'état de session dans Drift après chaque placement (Story 1.7a).
///
/// Stocke l'intégralité de l'état nécessaire à une restauration fidèle :
/// plateau, pile, pièces, tuiles bonus, dernier placement (pour annuler).
class SessionSaver {
  static Future<void> save(WidgetRef ref) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final grid = ref.read(gridProvider);
      final stack = ref.read(tileStackProvider);
      final session = ref.read(sessionProvider);
      final lastPlacement = ref.read(lastPlacementProvider);

      final gridJson = jsonEncode(grid.toJson());

      final queue = ref.read(tileStackProvider.notifier).queue;
      final queueJson = queue.map((t) => t.toJson()['sides']).toList();
      final stackJson = jsonEncode({
        'seed': stack.seed,
        'remaining': stack.remaining,
        'visible': stack.visible.map((t) => t.toJson()['sides']).toList(),
        'queue': queueJson,
      });

      String? lastTileJson;
      if (lastPlacement != null) {
        lastTileJson = jsonEncode({
          'q': lastPlacement.coords.q,
          'r': lastPlacement.coords.r,
          ...lastPlacement.tile.toJson(),
          'bonusTiles': lastPlacement.bonusTiles,
          'connectedSides': lastPlacement.connectedSides,
        });
      }

      await db.into(db.activeBoardSession).insert(
            ActiveBoardSessionRow(
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
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }

  /// Marque la session active comme terminée (fin de partie ou abandon).
  static Future<void> endSession(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.activeBoardSession)..where((t) => t.id.equals(1)))
        .write(const ActiveBoardSessionCompanion(isActive: Value(false)));
  }
}

/// Valide le placement de la tuile prévisualisée et attribue les récompenses.
///
/// [onConfirm] : callback appelé avec les coordonnées, la tuile, la liste
/// des côtés connectés et le nombre de tuiles bonus pour mettre à jour le
/// rendu Flame (HexGridComponent).
/// Découplé du provider pour éviter une dépendance circulaire providers → Flame.
Future<void> confirmPlacement(
  WidgetRef ref, {
  required void Function(HexCoords coords, HexTile tile, List<int> connectedSides, int bonusTiles) onConfirm,
}) async {
  final p = ref.read(placementProvider);
  final tile = ref.read(placementProvider.notifier).previewTile;
  if (p.selected == null || tile == null) return;

  final coords = p.selected!;
  final reward = ref.read(previewRewardProvider);

  _placeTileOnGrid(ref, coords, tile);
  onConfirm(coords, tile, reward.connectedSides, reward.bonusTiles);
  _recordPlacement(ref, coords, tile, reward);
  _applyReward(ref, tile, reward);
  _advanceStack(ref);
  await SessionSaver.save(ref);
  _checkGameOver(ref);
}

void _placeTileOnGrid(WidgetRef ref, HexCoords coords, HexTile tile) {
  ref.read(gridProvider.notifier).placeTile(coords, tile);
}

void _recordPlacement(
  WidgetRef ref,
  HexCoords coords,
  HexTile tile,
  PlacementReward reward,
) {
  ref.read(lastPlacementProvider.notifier).set(
    LastPlacement(coords, tile,
        bonusTiles: reward.bonusTiles,
        connectedSides: List.of(reward.connectedSides)),
  );
}

void _applyReward(WidgetRef ref, HexTile tile, PlacementReward reward) {
  if (reward.connectedSides.isEmpty && reward.bonusTiles == 0) {
    ref.read(sessionProvider.notifier).addReward(reward);
  } else {
    final effects = ref.read(gameEffectsServiceProvider);
    final villageSides = effects.countVillageSides(tile, reward.connectedSides);
    final baseCoins = reward.connectedSides.length + reward.bonusTiles;
    final totalCoins = effects.applyCoinBonuses(
      baseCoins: baseCoins,
      villageSides: villageSides,
    );
    ref.read(sessionProvider.notifier).addReward(reward,
        forcedCoins: totalCoins);
  }
  if (reward.bonusTiles > 0) {
    ref.read(tileStackProvider.notifier).addBonusTiles(reward.bonusTiles);
  }
}

void _advanceStack(WidgetRef ref) {
  ref.read(tileStackProvider.notifier).consumeActiveTile();
  ref.read(questServiceProvider).onTilePlaced();
  ref.read(placementProvider.notifier).clearSelection();
}

void _checkGameOver(WidgetRef ref) {
  final remaining = ref.read(tileStackProvider).remaining;
  if (remaining > 0) return;

  final grid = ref.read(gridProvider);
  final session = ref.read(sessionProvider);
  final stats = computeEndGameStats(grid, session.coins);
  final analysis = BoardAnalysis.fromGrid(grid);

  ref.read(isGameOverProvider.notifier).set(true);
  ref.read(endGameStatsProvider.notifier).set(stats);

  SessionSaver.endSession(ref);

  final db = ref.read(appDatabaseProvider);
  addCoinsToProfile(db, session.coins);
  recordGameEnd(
    db,
    coinsEarned: session.coins,
    score: session.coins,
    tilesPlacedInGame: grid.placedTiles.length,
    maxBiomeSizes: analysis.maxBiomeSizes,
  );

  ref.read(questServiceProvider).onGameEnd(
    largestVillage: analysis.largestVillage,
    closedBiomes: analysis.closedBiomes,
  );
  ref.read(cloudSaveServiceProvider).syncAfterGame();
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
