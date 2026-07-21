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
import '../services/ad_service.dart';
import 'build_provider.dart';
import 'end_game_provider.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import 'game_effects_service.dart';
import 'grid_state_provider.dart';
import 'placement_provider.dart';
import 'player_profile_provider.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';
import 'player_stats_provider.dart';
import 'quest_provider.dart';
import 'reward_model.dart';
import 'upgrade_feedback_provider.dart';
import '../core/game_enums.dart';

class LastPlacement {
  LastPlacement(this.coords, this.tile,
      {this.bonusTiles = 0,
      this.connectedSides = const [],
      this.coins = 0,
      required this.previousSession});
  final HexCoords coords;
  final HexTile tile;
  final int bonusTiles;
  final List<int> connectedSides;
  final int coins;

  /// Snapshot de la session juste AVANT l'application des récompenses de ce
  /// placement (pièces, connexions, streak, Combo+...). Permet à Annuler de
  /// restaurer l'état exact d'avant-coup en une fois, plutôt que de
  /// soustraire manuellement chaque compteur — ce qui oubliait jusqu'ici de
  /// revenir en arrière sur les effets cumulatifs des améliorations comme
  /// Combo+ (currentDoubleStreak) ou la série de connexions (currentStreak /
  /// bestStreak).
  final SessionState previousSession;
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
  static Future<void> save(ProviderContainer ref) async {
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
        'holdSlotRemainingUses': session.holdSlotRemainingUses,
        'secondChanceRemainingUses': session.secondChanceRemainingUses,
        // État "Couleur détestée" (Story B12b/B12x) — sans eux, la reprise
        // de partie après kill de l'app perdait l'exclusion de biome.
        'excludeBiome': stack.excludeBiome?.name,
        'hatedDuration': stack.hatedDuration,
        'hatedStartCount': stack.hatedStartCount,
        'hatedActivated': stack.hatedActivated,
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
          // Snapshot pré-placement (voir LastPlacement.previousSession) :
          // sans lui, un Annuler après reprise de partie (kill de l'appli
          // puis restauration) retomberait sur l'ancienne soustraction
          // manuelle et perdrait à nouveau la décrémentation de Combo+.
          'previousSession': lastPlacement.previousSession.toJson(),
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
  static Future<void> endSession(ProviderContainer ref) async {
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
  ProviderContainer ref, {
  required void Function(HexCoords coords, HexTile tile, List<int> connectedSides, int bonusTiles,
          {int bonusCoins})
      onConfirm,
}) async {
  final p = ref.read(placementProvider);
  final tile = ref.read(placementProvider.notifier).previewTile;
  if (p.selected == null || tile == null) return;

  final coords = p.selected!;
  final reward = ref.read(previewRewardProvider);

  // Capturé AVANT _applyReward (qui mute sessionProvider) : c'est l'état
  // exact vers lequel Annuler doit revenir, y compris les compteurs
  // cumulatifs (currentDoubleStreak pour Combo+, currentStreak/bestStreak)
  // que removeReward ne savait pas défaire correctement.
  final previousSession = ref.read(sessionProvider);

  _placeTileOnGrid(ref, coords, tile);
  onConfirm(coords, tile, reward.connectedSides, reward.bonusTiles,
      bonusCoins: reward.bonusCoins);
  final (appliedReward, totalBonusTilesAdded) =
      _applyReward(ref, coords, tile, reward);
  _recordPlacement(
      ref, coords, tile, appliedReward, totalBonusTilesAdded, previousSession);
  _triggerPlacementHaptics(ref, appliedReward);
  _triggerPlacementAudio(ref, appliedReward);
  _advanceStack(ref, reward.connectedSides.length);
  await SessionSaver.save(ref);
  _checkGameOver(ref);
}

/// Déclenche le bruitage de gain de pièces (`coin.mp3`) : une occurrence par
/// pièce effectivement créditée sur ce placement — côtés connectés
/// (pièces "de base") + pièces bonus, à l'exclusion des tuiles bonus qui ne
/// sont pas des pièces (voir [_triggerPlacementHaptics], même périmètre côté
/// vibrations). Aucun son si aucune pièce n'est gagnée (pose sans connexion).
void _triggerPlacementAudio(ProviderContainer ref, PlacementReward reward) {
  final totalCoins = reward.connectedSides.length + reward.bonusCoins;
  if (totalCoins <= 0) return;
  ref.read(audioServiceProvider).playCoinsGained(totalCoins);
}

/// Déclenche les retours haptiques associés à un placement : une vibration
/// légère par pièce "de base" (côtés connectés), une vibration moyenne par
/// pièce bonus, et une vibration forte par tuile bonus — jouées dans cet
/// ordre (léger → moyen → fort) pour souligner l'intensité croissante du
/// gain (voir [HapticsService.playReward]).
void _triggerPlacementHaptics(ProviderContainer ref, PlacementReward reward) {
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

void _placeTileOnGrid(ProviderContainer ref, HexCoords coords, HexTile tile) {
  ref.read(gridProvider.notifier).placeTile(coords, tile);
}

void _recordPlacement(
  ProviderContainer ref,
  HexCoords coords,
  HexTile tile,
  PlacementReward reward,
  int totalBonusTilesAdded,
  SessionState previousSession,
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
        coins: coins,
        previousSession: previousSession),
  );
}

/// Retourne la récompense appliquée (pour l'UI/session, pièces uniquement)
/// et le nombre TOTAL de tuiles bonus effectivement ajoutées à la pile pour
/// cette pose (connexion + Combo+ + Bonus de clôture) — ce second nombre
/// sert uniquement à ce qu'[undoPlacement] puisse toutes les retirer.
(PlacementReward, int) _applyReward(
    ProviderContainer ref, HexCoords pos, HexTile tile, PlacementReward reward) {
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
  // l'amélioration (10/8/5 aux niveaux 1/2/3).
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

void _advanceStack(ProviderContainer ref, int connectedSidesCount) {
  ref.read(tileStackProvider.notifier).consumeActiveTile();
  ref.read(questServiceProvider)
      .onTilePlaced(connectedSidesCount: connectedSidesCount);
  ref.read(adTilesPlacedProvider.notifier).increment();
  ref.read(placementProvider.notifier).clearSelection();
}

void _checkGameOver(ProviderContainer ref) {
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
