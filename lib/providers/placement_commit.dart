import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../game/hex_cell.dart';
import '../game/hex_coords.dart';
import '../game/hex_tile.dart';
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
  final seed = stackJson['seed'] as int?;
  final queueList = (stackJson['queue'] as List)
      .map((t) => (t as List)
          .map((s) => BiomeType.values.firstWhere((b) => b.name == s))
          .toList())
      .map((sides) => HexTile(sides: sides))
      .toList();
  ref.read(tileStackProvider.notifier).restoreQueue(queueList, seed: seed);

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
  final baseBonus = c >= 6 ? 10 : c == 5 ? 5 : c == 4 ? 2 : c == 3 ? 1 : 0;

  // Appliquer le multiplicateur de tuiles bonus (Story 2.8a).
  final effects = ref.read(gameEffectsServiceProvider);
  final multipliedBonus = effects.applyConnectionMultiplier(baseBonus);

  return PlacementReward(connectedSides: sides, bonusTiles: multipliedBonus);
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
      'seed': stack.seed,
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
  // Les tuiles bonus tiennent déjà compte du multiplicateur de connexions
  // (Story 2.8a, [previewRewardProvider]).
  ref.read(sessionProvider.notifier).addReward(reward);
  if (reward.bonusTiles > 0) {
    ref.read(tileStackProvider.notifier).addBonusTiles(reward.bonusTiles);
  }

  // 5. Avancer la pile de tuiles.
  ref.read(tileStackProvider.notifier).consumeActiveTile();

  // 5b. Mettre à jour la progression des quêtes (Story 2.3a).
  ref.read(questServiceProvider).onTilePlaced();

  // 6. Effacer la prévisualisation.
  ref.read(placementProvider.notifier).clearSelection();

  // 7. Sauvegarde de session.
  SessionSaver.save(ref);

  // 8. Détection de fin de partie (Story 1.8a / 1.8b / 2.2b).
  final remaining = ref.read(tileStackProvider).remaining;
  if (remaining == 0) {
    final grid = ref.read(gridProvider);
    final session = ref.read(sessionProvider);
    final stats = computeEndGameStats(grid, session.coins);

    ref.read(isGameOverProvider.notifier).set(true);
    ref.read(endGameStatsProvider.notifier).set(stats);

    SessionSaver.endSession(ref);

    // Persistance fin de partie (Story 2.2b) : les pièces de session
    // sont ajoutées au solde total, et les stats cumulées sont mises à
    // jour. Le score retenu pour best_score = pièces gagnées dans la run.
    final db = ref.read(appDatabaseProvider);
    addCoinsToProfile(db, session.coins);
    recordGameEnd(db, coinsEarned: session.coins, score: session.coins);

    // Mise à jour des quêtes village_size & biomes_closed (Story 2.3a).
    ref.read(questServiceProvider).onGameEnd(grid);
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
