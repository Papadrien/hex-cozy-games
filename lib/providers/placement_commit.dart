import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/app_database.dart';
import '../game/hex_cell.dart';
import '../game/hex_coords.dart';
import '../game/hex_tile.dart';
import '../services/cloud_save_service.dart';
import 'build_provider.dart';
import 'end_game_provider.dart';
import '../services/ad_service.dart';
import '../services/haptics_service.dart';
import 'game_effects_service.dart';
import 'grid_state_provider.dart';
import 'hold_slot_provider.dart';
import 'placement_provider.dart';
import 'player_profile_provider.dart';
import 'second_chance_provider.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';
import 'player_stats_provider.dart';
import 'quest_provider.dart';
import 'reward_model.dart';
import 'upgrade_feedback_provider.dart';
import '../core/game_enums.dart';

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

    // Forcer une bannière fraîche (même raison que dans startNewGame) :
    // sans ça, la reprise peut réutiliser une instance de BannerAd encore
    // attachée à l'AdWidget de l'écran précédent en cours de démontage,
    // ce qui provoque l'erreur AdMob "This AdWidget is already in the
    // widget tree".
    ref.invalidate(bannerAdProvider);

    // Restaurer le plateau.
    final gridJson = jsonDecode(row.gridState) as Map<String, dynamic>;
    ref.read(gridProvider.notifier)
        .setState(GridState.fromJson(gridJson).placedTiles);

    // Restaurer la pile de tuiles.
    final stackJson = jsonDecode(row.tileStack);
    final seed = stackJson['seed'] as int?;
    final queueList = (stackJson['queue'] as List)
        .map((t) => HexTile.fromJson(t as Map<String, dynamic>))
        .toList();
    ref.read(tileStackProvider.notifier).restoreQueue(queueList, seed: seed);

    // Restaurer la session (pièces, tuiles bonus, connexions).
    final grid = ref.read(gridProvider);
    int c3 = 0, c4 = 0, c5 = 0, c6 = 0;
    for (final entry in grid.placedTiles.entries) {
      final connected = grid.countConnectedSides(entry.key, entry.value);
      if (connected == 3) c3++;
      if (connected == 4) c4++;
      if (connected == 5) c5++;
      if (connected == 6) c6++;
    }
    ref.read(sessionProvider.notifier).restore(SessionState(
          coins: row.coins,
          totalBonusTiles: row.totalBonusTiles,
          connections3: c3,
          connections4: c4,
          connections5: c5,
          connections6: c6,
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
            coins: lastJson['coins'] as int? ?? 0,
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
  // Appels directs à reset() (et non invalidate + mutation sur notifier
  // stale) : les providers @Riverpod(keepAlive: true) ne se reconstruisent
  // pas immédiatement sur simple invalidate — sans ça, drawInitialTile()
  // et placeTile() opèrent sur l'ancienne instance, et les modifications
  // sont perdues au premier watch() de GameScreen.
  ref.read(gridProvider.notifier).reset();
  ref.read(tileStackProvider.notifier).reset();
  ref.invalidate(bannerAdProvider);
  ref.invalidate(holdSlotProvider);
  ref.invalidate(secondChanceModeProvider);
  ref.read(sessionProvider.notifier).reset();
  ref.read(upgradeFeedbackProvider.notifier).reset();
  ref.read(lastPlacementProvider.notifier).set(null);
  ref.read(placementProvider.notifier).clearSelection();
  resetEndGame(ref);

  // Appliquer le bonus de tuiles de départ (Story 2.8a) en tête de file
  // pour que le joueur les voie immédiatement.
  final effects = ref.read(gameEffectsServiceProvider);
  final bonus = effects.getStartingTilesBonus();
  if (bonus > 0) {
    ref.read(tileStackProvider.notifier).addStartingBonusTiles(bonus);
  }

  // Millionnaire (debug) : crédite les pièces au démarrage si l'amélioration
  // est active — un seul·e coup suffit pour la session de test.
  final activeEffects = ref.read(activeUpgradeEffectsProvider);
  if (activeEffects.millionaireCoins > 0) {
    addCoinsToProfile(ref.read(appDatabaseProvider), activeEffects.millionaireCoins);
  }

  // Initialiser les compteurs d'utilisations par partie (Story B9).
  ref.read(sessionProvider.notifier).initPerGameUses(
        ref.read(activeUpgradeEffectsProvider),
      );

  // Pose automatique de la tuile centrale de départ.
  final initialTile = ref.read(tileStackProvider.notifier).drawInitialTile();
  if (initialTile != null) {
    ref.read(gridProvider.notifier).placeTile(const HexCoords(0, 0), initialTile);
  }
}

class LastPlacement {
  LastPlacement(this.coords, this.tile,
      {this.bonusTiles = 0, this.connectedSides = const [], this.coins = 0});
  final HexCoords coords;
  final HexTile tile;
  final int bonusTiles;
  final List<int> connectedSides;
  final int coins;
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

  // Appliquer le bonus Tuile bonus sur quint/sext (Story 2.8a, remanié).
  final effects = ref.read(gameEffectsServiceProvider);
  final multipliedBonus = effects.applyBonusTileUpgrade(c, baseBonus);

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
      final queueJson = queue.map((t) => t.toJson()).toList();
      final stackJson = jsonEncode({
        'seed': stack.seed,
        'remaining': stack.remaining,
        'visible': stack.visible.map((t) => t.toJson()).toList(),
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
          'coins': lastPlacement.coins,
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
  required void Function(HexCoords coords, HexTile tile, List<int> connectedSides, int bonusTiles,
          {int bonusCoins})
      onConfirm,
}) async {
  final p = ref.read(placementProvider);
  final tile = ref.read(placementProvider.notifier).previewTile;
  if (p.selected == null || tile == null) return;

  final coords = p.selected!;
  final reward = ref.read(previewRewardProvider);

  _placeTileOnGrid(ref, coords, tile);
  onConfirm(coords, tile, reward.connectedSides, reward.bonusTiles,
      bonusCoins: reward.bonusCoins);
  final (appliedReward, totalBonusTilesAdded) =
      _applyReward(ref, coords, tile, reward);
  _recordPlacement(ref, coords, tile, appliedReward, totalBonusTilesAdded);
  _triggerPlacementHaptics(ref, appliedReward);
  _advanceStack(ref, reward.connectedSides.length);
  await SessionSaver.save(ref);
  _checkGameOver(ref);
}

/// Déclenche les retours haptiques associés à un placement : une vibration
/// légère par pièce "de base" (côtés connectés), une vibration moyenne par
/// pièce bonus, et une vibration forte par tuile bonus — jouées dans cet
/// ordre (léger → moyen → fort) pour souligner l'intensité croissante du
/// gain (voir [HapticsService.playReward]).
void _triggerPlacementHaptics(WidgetRef ref, PlacementReward reward) {
  final baseCoins = reward.connectedSides.length;
  if (baseCoins == 0 && reward.bonusCoins == 0 && reward.bonusTiles == 0) {
    return;
  }
  ref.read(hapticsServiceProvider).playReward(
        coins: baseCoins,
        bonusCoins: reward.bonusCoins,
        bonusTiles: reward.bonusTiles,
      );
}

void _placeTileOnGrid(WidgetRef ref, HexCoords coords, HexTile tile) {
  ref.read(gridProvider.notifier).placeTile(coords, tile);
}

void _recordPlacement(
  WidgetRef ref,
  HexCoords coords,
  HexTile tile,
  PlacementReward reward,
  int totalBonusTilesAdded,
) {
  // Les pièces annulables ne comptent que le bonus de connexion (reward
  // .bonusTiles) : les tuiles bonus Combo+/Clôture n'ont jamais été
  // converties en pièces, seulement ajoutées physiquement à la pile — voir
  // [totalBonusTilesAdded] ci-dessous pour leur annulation.
  final coins = reward.connectedSides.length + reward.bonusTiles + reward.bonusCoins;
  ref.read(lastPlacementProvider.notifier).set(
    LastPlacement(coords, tile,
        // Total réellement ajouté à la pile (connexion + Combo+ + Bonus de
        // clôture) : Annuler doit retirer exactement ce nombre de tuiles,
        // pas seulement celles du bonus de connexion (voir undoPlacement).
        bonusTiles: totalBonusTilesAdded,
        connectedSides: List.of(reward.connectedSides),
        coins: coins),
  );
}

/// Retourne la récompense appliquée (pour l'UI/session, pièces uniquement)
/// et le nombre TOTAL de tuiles bonus effectivement ajoutées à la pile pour
/// cette pose (connexion + Combo+ + Bonus de clôture) — ce second nombre
/// sert uniquement à ce qu'[undoPlacement] puisse toutes les retirer.
(PlacementReward, int) _applyReward(
    WidgetRef ref, HexCoords pos, HexTile tile, PlacementReward reward) {
  if (reward.connectedSides.isEmpty && reward.bonusTiles == 0) {
    ref.read(sessionProvider.notifier).addReward(reward);
    // Story B12a : signale une pose "vide" (tick incrémenté, aucun type
    // déclenché) pour que l'encart des améliorations actives puisse malgré
    // tout réagir à l'évènement pose si besoin.
    ref.read(upgradeFeedbackProvider.notifier).reportTriggered(const {});
    return (reward, 0);
  }
  // Story B12a — accumule au fil du calcul les UpgradeEffectType ayant
  // effectivement produit un bonus sur CETTE pose, pour piloter le feedback
  // visuel (pulsation/contour) de l'encart des améliorations actives. Les
  // conditions de seuil ci-dessous dupliquent volontairement celles
  // d'[GameEffectsService.applyCoinBonuses] plutôt que d'en changer la
  // signature (fonction pure déjà testée) : à réévaluer si un futur besoin
  // justifie de faire remonter le détail directement depuis le service.
  final triggeredTypes = <UpgradeEffectType>{};
  final effects = ref.read(gameEffectsServiceProvider);
  final villageSides = effects.countBiomeSides(BiomeType.village, tile, reward.connectedSides);
  final forestSides = effects.countBiomeSides(BiomeType.forest, tile, reward.connectedSides);
  final waterSides = effects.countBiomeSides(BiomeType.water, tile, reward.connectedSides);
  final plainSides = effects.countBiomeSides(BiomeType.plain, tile, reward.connectedSides);
  final mountainSides = effects.countBiomeSides(BiomeType.mountain, tile, reward.connectedSides);
  final baseCoins = reward.connectedSides.length + reward.bonusTiles;
  final totalCoins = effects.applyCoinBonuses(
    baseCoins: baseCoins,
    villageSides: villageSides,
    forestSides: forestSides,
    waterSides: waterSides,
    plainSides: plainSides,
    mountainSides: mountainSides,
  );
  final bonusCoins = totalCoins - baseCoins;
  final applied = PlacementReward(
    connectedSides: reward.connectedSides,
    bonusTiles: reward.bonusTiles,
    bonusCoins: bonusCoins,
  );
  ref.read(sessionProvider.notifier).addReward(applied, forcedCoins: totalCoins);

  // Seuils pièces (Pièces+/Jackpot+ global + Rouge+/Vert+/Bleu+/Jaune+/
  // Violet+ par biome) — même logique que
  // [GameEffectsService.applyCoinBonuses], dupliquée pour identifier QUEL
  // seuil précis a été franchi sur cette pose.
  final activeEffects = ref.read(activeUpgradeEffectsProvider);
  if (activeEffects.coinsThreshold > 0 &&
      baseCoins >= activeEffects.coinsThreshold) {
    triggeredTypes.add(UpgradeEffectType.coinsPercentBonus);
  }
  if (activeEffects.villageCoinsThreshold > 0 &&
      villageSides >= activeEffects.villageCoinsThreshold) {
    triggeredTypes.add(UpgradeEffectType.villageCoinsPercentBonus);
  }
  if (activeEffects.forestCoinsThreshold > 0 &&
      forestSides >= activeEffects.forestCoinsThreshold) {
    triggeredTypes.add(UpgradeEffectType.forestCoinsPercentBonus);
  }
  if (activeEffects.waterCoinsThreshold > 0 &&
      waterSides >= activeEffects.waterCoinsThreshold) {
    triggeredTypes.add(UpgradeEffectType.waterCoinsPercentBonus);
  }
  if (activeEffects.plainCoinsThreshold > 0 &&
      plainSides >= activeEffects.plainCoinsThreshold) {
    triggeredTypes.add(UpgradeEffectType.plainCoinsPercentBonus);
  }
  if (activeEffects.mountainCoinsThreshold > 0 &&
      mountainSides >= activeEffects.mountainCoinsThreshold) {
    triggeredTypes.add(UpgradeEffectType.mountainCoinsPercentBonus);
  }

  var totalBonusTilesAdded = 0;
  if (reward.bonusTiles > 0) {
    ref.read(tileStackProvider.notifier).addBonusTiles(reward.bonusTiles);
    totalBonusTilesAdded += reward.bonusTiles;
    // Tuile bonus (connectionBonusMultiplier) n'ajoute un bonus SUPPLÉMENTAIRE
    // qu'à partir de quint/sext (voir [GameEffectsService.applyBonusTileUpgrade])
    // — reward.bonusTiles > 0 seul ne suffit pas car kBonusScale accorde déjà
    // des tuiles bonus de base dès 3 côtés sans amélioration active.
    if (activeEffects.connectionBonusLevel > 0 &&
        (reward.connectedSides.length == 5 ||
            reward.connectedSides.length == 6)) {
      triggeredTypes.add(UpgradeEffectType.connectionBonusMultiplier);
    }
  }
  // Story B3 — Combo+ : à chaque palier de N doubles connexions
  // (exactement 2 côtés connectés) cumulées sur la partie (plus besoin
  // d'être d'affilée), ajoute 1 tuile bonus. N dépend du niveau de
  // l'amélioration (15/13/10 aux niveaux 1/2/3).
  final doubleStreak = ref.read(sessionProvider).currentDoubleStreak;
  final comboInterval = effects.getComboStreakInterval();
  if (comboInterval > 0 && doubleStreak > 0 && doubleStreak % comboInterval == 0) {
    const comboCount = 1;
    ref.read(tileStackProvider.notifier).addBonusTiles(comboCount);
    ref.read(sessionProvider.notifier).addExtraBonusTiles(comboCount);
    totalBonusTilesAdded += comboCount;
    triggeredTypes.add(UpgradeEffectType.comboBonusTiles);
  }
  // Story B7 — Bonus de clôture : détecte les biomes qui viennent de se
  // fermer après cette pose et ajoute (taille ÷ 10) × niveau tuiles bonus,
  // avec un minimum garanti de [closureMult] tuiles par fermeture (sinon
  // une petite zone refermée sans avoir atteint 10 tuiles ne rapportait
  // rien, alors que la fermeture a bien eu lieu).
  final closureMult = effects.getClosureBonusTiles();
  if (closureMult > 0) {
    final grid = ref.read(gridProvider);
    final closures = grid.biomesJustClosed(pos, tile);
    var closureTiles = 0;
    for (final entry in closures) {
      final ratioBonus = (entry.value ~/ 10) * closureMult;
      closureTiles += ratioBonus > 0 ? ratioBonus : closureMult;
    }
    if (closureTiles > 0) {
      ref.read(tileStackProvider.notifier).addBonusTiles(closureTiles);
      ref.read(sessionProvider.notifier).addExtraBonusTiles(closureTiles);
      totalBonusTilesAdded += closureTiles;
      triggeredTypes.add(UpgradeEffectType.closureBonusTiles);
    }
  }

  ref.read(upgradeFeedbackProvider.notifier).reportTriggered(triggeredTypes);
  return (applied, totalBonusTilesAdded);
}

void _advanceStack(WidgetRef ref, int connectedSidesCount) {
  ref.read(tileStackProvider.notifier).consumeActiveTile();
  ref.read(questServiceProvider)
      .onTilePlaced(connectedSidesCount: connectedSidesCount);
  ref.read(adTilesPlacedProvider.notifier).increment();
  ref.read(placementProvider.notifier).clearSelection();
}

void _checkGameOver(WidgetRef ref) {
  final remaining = ref.read(tileStackProvider).remaining;
  if (remaining > 0) return;

  final grid = ref.read(gridProvider);
  final session = ref.read(sessionProvider);
  final stats = computeEndGameStats(
    placedTilesCount: grid.placedTiles.length,
    coins: session.coins,
    connections3: session.connections3,
    connections4: session.connections4,
    connections5: session.connections5,
    connections6: session.connections6,
  );
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
    coinsEarned: session.coins,
    largestVillage: analysis.largestVillage,
    closedBiomes: analysis.closedBiomes,
    maxBiomeSizes: analysis.maxBiomeSizes,
    bestStreak: session.bestStreak,
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
    last.coins,
    last.bonusTiles,
    connectedCount: last.connectedSides.length,
  );
  if (last.bonusTiles > 0) {
    ref.read(tileStackProvider.notifier).removeLastBonusTiles(last.bonusTiles);
  }

  // 5. Effacer la mémoire d'annulation (1 seul niveau).
  ref.read(lastPlacementProvider.notifier).set(null);
}

/// Échange la tuile active avec la tuile en réserve de l'Emplacement Joker
/// (Story B10).
///
/// - Aucune tuile en réserve : la tuile active part en réserve, et la
///   suivante de la pile devient la nouvelle tuile active.
/// - Une tuile est déjà en réserve : elle devient la nouvelle tuile active
///   (réinsérée en tête de pile) et l'ancienne tuile active part en réserve
///   à sa place — un échange à double sens.
/// - Pile vide mais tuile en réserve présente : permet de la récupérer même
///   sans tuile active à lui opposer.
///
/// Ne fait rien si aucune utilisation ne reste pour cette partie (Story B9)
/// ou s'il n'y a ni tuile active ni tuile en réserve à échanger.
///
/// Note (limite connue, non bloquante) : si la pile ne contenait plus
/// qu'une seule tuile et qu'aucune tuile n'était en réserve, la mettre en
/// réserve vide la pile (`remaining` passe à 0) sans déclencher la fin de
/// partie — elle attend que le joueur la récupère via un nouvel échange.
/// [_checkGameOver] n'est donc pas appelé ici, à la différence de
/// [confirmPlacement].
///
/// Comportement volontairement asymétrique selon l'état de l'emplacement :
///
///  • Emplacement VIDE (1er clic) : la tuile active est retirée de la pile
///    et mise en réserve — consomme 1 utilisation.
///  • Emplacement PLEIN (2e clic) : la tuile en réserve est remise en tête
///    de la pile (elle devient la nouvelle tuile active, l'ancienne tuile
///    active passant en 2e position) et l'emplacement est vidé — ne
///    consomme AUCUNE utilisation, il ne s'agit pas d'un nouvel échange
///    mais de la simple reprise d'une tuile déjà mise de côté.
void swapHoldSlot(WidgetRef ref) {
  final heldTile = ref.read(holdSlotProvider).heldTile;
  final stackNotifier = ref.read(tileStackProvider.notifier);

  if (heldTile != null) {
    // 2e clic : reprise de la tuile en réserve, gratuite.
    stackNotifier.returnTile(heldTile);
    ref.read(holdSlotProvider.notifier).set(null);
    // La sélection de prévisualisation en cours (le cas échéant) portait
    // sur l'ancienne tuile active : elle n'a plus de sens, la tuile reprise
    // devient la nouvelle tuile active en tête de pile.
    ref.read(placementProvider.notifier).clearSelection();
    return;
  }

  // 1er clic : mise en réserve de la tuile active, coûte 1 utilisation.
  final session = ref.read(sessionProvider);
  if (session.holdSlotRemainingUses <= 0) return;

  final activeTile = ref.read(tileStackProvider).activeTile;
  if (activeTile == null) return;

  stackNotifier.consumeActiveTile();
  ref.read(holdSlotProvider.notifier).set(activeTile);
  ref.read(placementProvider.notifier).clearSelection();
  ref.read(sessionProvider.notifier).consumeHoldSlot();
}

/// Active ou désactive le mode sélection de Deuxième chance (Story B11).
///
/// Activer le mode annule toute prévisualisation de placement en cours :
/// les deux modes sont mutuellement exclusifs (un tap sur le plateau ne
/// peut pas à la fois valider un placement et retirer une tuile). Ne fait
/// rien à l'activation si aucune utilisation ne reste pour cette partie
/// (Story B9) ; la désactivation, elle, est toujours possible (annulation).
void toggleSecondChanceMode(WidgetRef ref) {
  final notifier = ref.read(secondChanceModeProvider.notifier);
  if (ref.read(secondChanceModeProvider)) {
    notifier.cancel();
    return;
  }
  if (ref.read(sessionProvider).secondChanceRemainingUses <= 0) return;
  ref.read(placementProvider.notifier).clearSelection();
  notifier.activate();
}

/// Retire la tuile posée en [coords] du plateau et la réinjecte en tête de
/// pile (Story B11 — Deuxième chance).
///
/// [onRemove] : callback pour retirer la tuile du rendu Flame (même
/// signature que le callback [onUndo] de [undoPlacement]).
///
/// Ne fait rien si aucune utilisation ne reste pour cette partie, ou si
/// aucune tuile n'est posée à [coords] (tap dans le vide pendant le mode
/// sélection — le mode reste actif, ce n'est pas une annulation).
///
/// Contrairement à [undoPlacement], les récompenses déjà gagnées pour cette
/// tuile (pièces, tuiles bonus, série de connexions) ne sont PAS reprises :
/// Deuxième chance permet de replacer une tuile existante ailleurs ou
/// autrement tournée, pas d'annuler l'action passée dans son ensemble — à
/// la différence du bouton Annuler, la tuile visée peut avoir été posée il
/// y a plusieurs coups, et ses récompenses peuvent depuis s'être mêlées à
/// celles d'autres tuiles connectées. Défaire cela proprement nécessiterait
/// de rejouer tout l'historique des connexions, ce qui dépasse le
/// périmètre de cette story.
void removePlacedTile(
  WidgetRef ref,
  HexCoords coords, {
  required void Function(HexCoords coords) onRemove,
}) {
  final session = ref.read(sessionProvider);
  if (session.secondChanceRemainingUses <= 0) return;

  final tile = ref.read(gridProvider).tileAt(coords);
  if (tile == null) return;

  // 1. Retirer du provider de grille (logique pure).
  ref.read(gridProvider.notifier).removeTile(coords);

  // 2. Retirer du rendu Flame via le callback.
  onRemove(coords);

  // 3. Remettre la tuile au sommet de la pile.
  ref.read(tileStackProvider.notifier).returnTile(tile);

  // 4. Consommer une utilisation (Story B9).
  ref.read(sessionProvider.notifier).consumeSecondChance();

  // 5. Sortir du mode sélection : le retrait est terminé.
  ref.read(secondChanceModeProvider.notifier).cancel();
}
