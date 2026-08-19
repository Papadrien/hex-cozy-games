import 'dart:async';
import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/game_enums.dart';
import '../data/app_database.dart';
import '../game/hex_cell.dart';
import '../game/hex_coords.dart';
import '../game/hex_tile.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import 'build_provider.dart';
import 'biome_size_overlay_provider.dart';
import 'end_game_provider.dart';
import 'game_effects_service.dart';
import 'grid_state_provider.dart';
import 'hold_slot_provider.dart';
import 'placement_provider.dart';
import 'placement_commit.dart';
import 'player_profile_provider.dart';
import 'second_chance_provider.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';
import 'upgrade_feedback_provider.dart';

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

    // État "Couleur détestée" (Story B12b/B12x) — `??` pour
    // rétro-compatibilité avec les sessions sauvegardées avant ce correctif.
    final excludeBiomeName = stackJson['excludeBiome'] as String?;
    final excludeBiome = excludeBiomeName != null
        ? BiomeType.values.firstWhere(
            (b) => b.name == excludeBiomeName,
            orElse: () => BiomeType.forest,
          )
        : null;

    ref.read(tileStackProvider.notifier).restoreQueue(
          queueList,
          seed: seed,
          excludeBiome: excludeBiome,
          hatedDuration: stackJson['hatedDuration'] as int? ?? 0,
          hatedStartCount: stackJson['hatedStartCount'] as int?,
          hatedActivated: stackJson['hatedActivated'] as bool? ?? false,
        );

    // Restaurer les compteurs d'utilisations par partie (Emplacement Joker /
    // Deuxième chance — Story B9). Stockés dans le JSON de la pile plutôt que
    // dans de nouvelles colonnes Drift pour éviter une migration de schéma.
    // `?? 0` : rétro-compatibilité avec les sessions sauvegardées avant ce
    // correctif, qui n'ont pas ces clés.
    final holdSlotRemainingUses =
        stackJson['holdSlotRemainingUses'] as int? ?? 0;
    final secondChanceRemainingUses =
        stackJson['secondChanceRemainingUses'] as int? ?? 0;
    final hatedColorRemainingUses =
        stackJson['hatedColorRemainingUses'] as int? ?? 0;

    // Compteurs cumulatifs d'améliorations (Combo+/série de connexions) —
    // `?? 0` : rétro-compatibilité avec les sessions sauvegardées avant ce
    // correctif, qui n'ont pas ces clés (elles retombent alors sur 0 comme
    // avant, sans crash). Sans cette restauration, currentDoubleStreak
    // (Combo+) et currentStreak/bestStreak repartaient de zéro à chaque
    // reprise de partie via "Sauvegarder et quitter", contrairement à
    // Annuler qui les restaure déjà correctement via SessionState
    // .previousSession.
    final currentStreak = stackJson['currentStreak'] as int? ?? 0;
    final bestStreak = stackJson['bestStreak'] as int? ?? 0;
    final currentDoubleStreak = stackJson['currentDoubleStreak'] as int? ?? 0;

    // Restaurer les améliorations sélectionnées pour la partie (Story 2.7b —
    // correctif kill forcé). `?? []` : rétro-compatibilité avec les sessions
    // sauvegardées avant ce correctif, qui n'ont pas cette clé — retombe
    // alors sur aucune sélection plutôt que de planter, comme avant.
    final selectedUpgradeIds =
        (stackJson['selectedUpgradeIds'] as List?)?.cast<String>() ?? [];
    ref.read(selectedUpgradeIdsProvider.notifier).restore(selectedUpgradeIds);

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
          currentStreak: currentStreak,
          bestStreak: bestStreak,
          currentDoubleStreak: currentDoubleStreak,
          holdSlotRemainingUses: holdSlotRemainingUses,
          secondChanceRemainingUses: secondChanceRemainingUses,
          hatedColorRemainingUses: hatedColorRemainingUses,
        ));

    // Restaurer le dernier placement (pour le bouton Annuler).
    if (row.lastTilePlaced != null) {
      final lastJson = jsonDecode(row.lastTilePlaced!) as Map<String, dynamic>;
      final tile = HexTile.fromJson(lastJson);
      final connectedSides =
          (lastJson['connectedSides'] as List?)?.cast<int>() ?? [];
      // Sessions sauvegardées avant l'ajout du snapshot : à défaut, on
      // retombe sur la session courante déjà restaurée ci-dessus plutôt que
      // de planter — Annuler y perdra la décrémentation fine de Combo+ pour
      // cette unique tuile mais restera sans danger (pas de compteur
      // négatif ni de crash).
      final previousSessionJson =
          lastJson['previousSession'] as Map<String, dynamic>?;
      final previousSession = previousSessionJson != null
          ? SessionStateJson.fromJson(previousSessionJson)
          : ref.read(sessionProvider);
      ref.read(lastPlacementProvider.notifier).set(LastPlacement(
            HexCoords(lastJson['q'] as int, lastJson['r'] as int),
            tile,
            bonusTiles: lastJson['bonusTiles'] as int? ?? 0,
            connectedSides: connectedSides,
            coins: lastJson['coins'] as int? ?? 0,
            previousSession: previousSession,
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
  unawaited(AnalyticsService.logEvent('game_start'));

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
  // Sans ce reset, l'affichage à la demande des tailles de zone ("Bonus de
  // clôture", voir `biome_size_overlay_provider.dart` et
  // `active_upgrades_hud.dart`) reste actif d'une partie à l'autre : c'est
  // un provider @riverpod autoDispose, mais [HexBoardGame.onLoad]
  // l'écoute via `_container.listen(...)` sans jamais fermer l'abonnement
  // à la fin de la partie — un écouteur actif suffit à empêcher Riverpod
  // de le disposer, donc son état (`true` si le joueur avait activé
  // l'affichage) survit tel quel à la prochaine partie, même si Atoll
  // n'est plus équipé (le slot pour le désactiver n'est alors même plus
  // affiché).
  ref.invalidate(biomeSizeOverlayProvider);
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

  // Déclencher une pulse ponctuelle pour "Aperçu prolongé" si actif
  // (remplace l'ancien contour doré fixe — pulse au démarrage uniquement).
  if (activeEffects.extendedPreviewCount > 0) {
    ref.read(upgradeFeedbackProvider.notifier).reportTriggered(
          {UpgradeEffectType.extendedPreviewCount},
        );
  }
}
