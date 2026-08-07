// Tests unitaires pour `confirmPlacement` (placement_commit.dart) — le
// cœur de la logique de récompense du jeu (Story 1.6b / B3 / B7).
//
// Vérifie, sur le flux complet de confirmation d'une pose :
//  - une pose sans connexion ne rapporte rien mais est enregistrée comme
//    dernier placement (annulable) ;
//  - une pose à 3 connexions rapporte les tuiles bonus de connexion
//    ([kBonusScale]) ;
//  - Combo+ accorde sa tuile bonus à chaque palier de doubles connexions
//    cumulées, sans se re-déclencher après coup ;
//  - le Bonus de clôture accorde (taille ÷ 8) × niveau tuiles à la
//    fermeture d'un biome de 8 tuiles ;
//  - les seuils de pièces (Pièces+) attribuent le nombre exact de pièces
//    bonus par type.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/core/game_enums.dart';
import 'package:hex_haven/data/app_database.dart';
import 'package:hex_haven/data/seed_data.dart';
import 'package:hex_haven/game/hex_cell.dart';
import 'package:hex_haven/game/hex_coords.dart';
import 'package:hex_haven/game/hex_tile.dart';
import 'package:hex_haven/providers/build_provider.dart';
import 'package:hex_haven/providers/grid_state_provider.dart';
import 'package:hex_haven/providers/options_provider.dart';
import 'package:hex_haven/providers/placement_commit.dart';
import 'package:hex_haven/providers/placement_provider.dart';
import 'package:hex_haven/providers/session_provider.dart';
import 'package:hex_haven/providers/tile_stack_provider.dart';

const _f = BiomeType.forest;
const _p = BiomeType.plain;

/// Tuile forcée basée sur [TileStack], avec une seule tuile active contrôlée
/// et un état stable : les mutations de pile restent sans effet pour que
/// `remaining` ne puisse jamais atteindre 0 (sinon confirmationPlacement
/// déclencherait la fin de partie et ses effets plugin/DB). Le bonus de
/// tuiles ajouté à la pile est vérifié via `session.totalBonusTiles` /
/// `lastPlacement.bonusTiles`.
class _ForcedTileStack extends TileStack {
  _ForcedTileStack(this._tile);

  final HexTile _tile;

  @override
  TileStackState build() => TileStackState(remaining: 30, visible: [_tile]);

  @override
  void addBonusTiles(int count) {}

  @override
  void consumeActiveTile() {}
}

/// Session initialisée avec un état donné (ex. compteurs cumulés).
class _SessionInit extends Session {
  _SessionInit(this._initial);

  final SessionState _initial;

  @override
  SessionState build() => _initial;
}

/// Options figées (bruitages/vibration coupés) pour éviter toute dépendance
/// aux plugins natifs dans les services réels (haptique/audio).
class _FixedOptions extends OptionsStateNotifier {
  _FixedOptions(this._state);

  final OptionsState _state;

  @override
  OptionsState build() => _state;
}

/// Récapitulatif des callbacks émis par une confirmation, pour assertions.
class _PlacementReport {
  HexCoords? coords;
  List<int> connectedSides = const [];
  int baseBonusTiles = 0;
  int? bonusCoins;
  (int, int)? combo;
  (int, int)? closure;
  (int, int)? connectionExtra;
  Map<UpgradeEffectType, int>? coinBonusTypes;
}

/// Monte le container avec une DB mémoire seedée et les services réduits à
/// néant (bruitages/vibration désactivés pour éviter toute dépendance aux
/// plugins) — la pile (tuile active) et les effets d'amélioration sont
/// contrôlés par test.
Future<ProviderContainer> _makeContainer({
  HexTile? activeTile,
  ActiveUpgradeEffects effects = const ActiveUpgradeEffects(),
  SessionState? session,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedDatabase(db);
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      activeUpgradeEffectsProvider.overrideWithValue(effects),
      optionsProvider.overrideWith(
        () => _FixedOptions(
          const OptionsState(
            musicEnabled: false,
            sfxEnabled: false,
            vibrationEnabled: false,
          ),
        ),
      ),
      if (activeTile != null)
        tileStackProvider.overrideWith(() => _ForcedTileStack(activeTile)),
      if (session != null)
        sessionProvider.overrideWith(() => _SessionInit(session)),
    ],
  );
}

/// Pose [tile] directement sur la grille (setup de scénario, pas via
/// [confirmPlacement] pour ne pas attribuer de récompense).
void _place(ProviderContainer container, HexCoords coords, HexTile tile) {
  container.read(gridProvider.notifier).placeTile(coords, tile);
}

/// Sélectionne [coords], confirme la pose et renvoie le rapport des
/// callbacks émis.
Future<_PlacementReport> _confirm(
  ProviderContainer container,
  HexCoords coords,
) async {
  final report = _PlacementReport();
  container.read(placementProvider.notifier).selectCell(coords);
  await confirmPlacement(
    container,
    onConfirm: (placedCoords, tile, sides, baseBonusTiles,
        {int? bonusCoins}) {
      report.coords = placedCoords;
      report.connectedSides = sides;
      report.baseBonusTiles = baseBonusTiles;
      report.bonusCoins = bonusCoins;
    },
    onComboBonusTiles: (count, coinCount) => report.combo = (count, coinCount),
    onClosureBonusTiles: (count, coinCount) =>
        report.closure = (count, coinCount),
    onConnectionBonusExtra: (count, coinCount) =>
        report.connectionExtra = (count, coinCount),
    onCoinBonusTypes: (amounts) => report.coinBonusTypes = amounts,
  );
  // confirmPlacement laisse certains effets tourner en arrière-plan
  // (questServiceProvider.onTilePlaced, fire-and-forget) : on les laisse se
  // terminer avant la prochaine pose ou le dispose du container, sinon leur
  // `Ref` est détruit en cours de route (erreur en fin de test).
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return report;
}

HexTile get _allForest => HexTile(sides: List.filled(6, _f));
HexTile get _plain => HexTile(sides: List.filled(6, _p));

void main() {
  group('confirmPlacement — pose vide', () {
    test('sans connexion ne rapporte rien et enregistre le placement',
        () async {
      final container = await _makeContainer(activeTile: _allForest);
      addTearDown(container.dispose);

      final report = await _confirm(container, const HexCoords(0, 0));

      expect(report.coords, const HexCoords(0, 0));
      expect(report.connectedSides, isEmpty);
      expect(report.baseBonusTiles, 0);
      expect(report.bonusCoins, 0);
      expect(report.combo, isNull);
      expect(report.closure, isNull);
      expect(report.connectionExtra, isNull);
      expect(report.coinBonusTypes, isNull);

      final session = container.read(sessionProvider);
      expect(session.coins, 0);
      expect(session.totalBonusTiles, 0);
      expect(session.currentStreak, 0);

      final last = container.read(lastPlacementProvider);
      expect(last, isNotNull);
      expect(last!.coords, const HexCoords(0, 0));
      expect(last.connectedSides, isEmpty);
      expect(last.bonusTiles, 0);
      expect(last.coins, 0);

      expect(container.read(gridProvider).placedTiles.length, 1);
      expect(container.read(tileStackProvider).remaining, 30);
    });

    test('sans sélection (cellule indisponible) ne fait rien', () async {
      final container = await _makeContainer(activeTile: _allForest);
      addTearDown(container.dispose);

      final before = container.read(gridProvider).placedTiles.length;
      await _confirm(container, const HexCoords(1, 0));

      expect(container.read(gridProvider).placedTiles.length, before);
      expect(container.read(lastPlacementProvider), isNull);
    });
  });

  group('confirmPlacement — bonus de connexion', () {
    test('3 connexions rapportent kBonusScale[3] (+1 tuile) et 4 pièces',
        () async {
      final container = await _makeContainer(activeTile: _allForest);
      addTearDown(container.dispose);

      const origin = HexCoords(0, 0);
      _place(container, origin.neighbor(0), _allForest);
      _place(container, origin.neighbor(1), _allForest);
      _place(container, origin.neighbor(2), _allForest);

      final report = await _confirm(container, origin);

      expect(report.connectedSides, [0, 1, 2]);
      expect(report.baseBonusTiles, 1);
      expect(report.bonusCoins, 0);

      final session = container.read(sessionProvider);
      expect(session.coins, 4); // 3 côtés + 1 tuile bonus
      expect(session.totalBonusTiles, 1);
      expect(session.connections3, 1);
      expect(session.currentStreak, 1);
      expect(session.bestStreak, 1);

      final last = container.read(lastPlacementProvider)!;
      expect(last.bonusTiles, 1);
      expect(last.coins, 4);

      // Le bonus de connexion passe par onConfirm (tuile de base), pas par
      // une particule Combo+/clôture dédiée.
      expect(report.connectionExtra, isNull);
      expect(report.combo, isNull);
      expect(report.closure, isNull);
    });
  });

  group('confirmPlacement — Combo+', () {
    test('un palier de doubles connexions cumulées accorde sa tuile bonus',
        () async {
      final container = await _makeContainer(
        activeTile: _allForest,
        effects: const ActiveUpgradeEffects(comboStreakInterval: 10),
        session: const SessionState(currentDoubleStreak: 9),
      );
      addTearDown(container.dispose);

      const origin = HexCoords(0, 0);
      _place(container, origin.neighbor(0), _allForest);
      _place(container, origin.neighbor(1), _allForest);

      final report = await _confirm(container, origin);

      // La pose fait passer la 10e double connexion → 1 tuile Combo+.
      expect(report.connectedSides, [0, 1]);
      expect(report.combo, (1, 2));

      final session = container.read(sessionProvider);
      expect(session.coins, 2);
      expect(session.totalBonusTiles, 1); // tuile Combo+
      expect(session.currentDoubleStreak, 10);

      final last = container.read(lastPlacementProvider)!;
      expect(last.bonusTiles, 1);
      expect(last.coins, 2);
    });

    test("ne se re-déclenche pas tant qu'un nouveau palier n'est pas franchi",
        () async {
      final container = await _makeContainer(
        activeTile: _allForest,
        effects: const ActiveUpgradeEffects(comboStreakInterval: 10),
        session: const SessionState(currentDoubleStreak: 9),
      );
      addTearDown(container.dispose);

      const origin = HexCoords(0, 0);
      _place(container, origin.neighbor(0), _allForest);
      _place(container, origin.neighbor(1), _allForest);

      // 1er palier (10e double connexion) → Combo+ déclenché.
      final first = await _confirm(container, origin);
      expect(first.combo, isNotNull);

      // 2e pose en double connexion : 11e double — pas un nouveau palier.
      final second = await _confirm(container, origin.neighbor(5));
      expect(second.connectedSides, [1, 2]);
      expect(second.combo, isNull);

      final session = container.read(sessionProvider);
      expect(session.currentDoubleStreak, 11);
      expect(session.totalBonusTiles, 1); // toujours 1 seule tuile Combo+
    });
  });

  group('confirmPlacement — Bonus de clôture', () {
    test('fermer un biome de 8 tuiles rapporte (8 ÷ 8) × niveau', () async {
      final container = await _makeContainer(
        activeTile: HexTile(sides: [_f, _p, _p, _p, _p, _p]),
        effects: const ActiveUpgradeEffects(closureBonusTiles: 1),
      );
      addTearDown(container.dispose);

      const origin = HexCoords(0, 0);
      // Cluster forestier de 7 tuiles (centre + 6 du ring-1) + 1 tuile
      // ring-2 : 8 tuiles connexes. Le centre reste vide pour l'instant —
      // la pose finale (tuile mi-forêt/mi-plaine) comble la dernière arête
      // ouverte et scelle le biome.
      _place(container, origin.neighbor(0),
          HexTile(sides: [_f, _p, _f, _f, _f, _p]));
      _place(container, origin.neighbor(1),
          HexTile(sides: [_p, _p, _p, _f, _f, _f]));
      _place(container, origin.neighbor(2),
          HexTile(sides: [_f, _p, _p, _p, _f, _f]));
      _place(container, origin.neighbor(3),
          HexTile(sides: [_f, _f, _p, _p, _p, _f]));
      _place(container, origin.neighbor(4),
          HexTile(sides: [_f, _f, _f, _p, _p, _p]));
      _place(container, origin.neighbor(5),
          HexTile(sides: [_p, _f, _f, _f, _p, _p]));
      _place(container, origin.neighbor(0).neighbor(0),
          HexTile(sides: [_p, _p, _f, _f, _f, _p]));

      // Toutes les arêtes extérieures du cluster doivent avoir un voisin
      // posé : combles plaine autour de la tuile ring-2 et en ring-3.
      final ring2 = origin.neighbor(0).neighbor(0);
      _place(container, ring2.neighbor(0), _plain);
      _place(container, ring2.neighbor(1), _plain);
      _place(container, ring2.neighbor(2), _plain);
      _place(container, ring2.neighbor(4), _plain);
      _place(container, ring2.neighbor(5), _plain);

      final report = await _confirm(container, origin);

      // 1 seule connexion (le côté forêt face au ring-1) : pas de tuile
      // bonus de connexion de base (kBonusScale[1] n'existe pas).
      expect(report.connectedSides, [0]);
      expect(report.baseBonusTiles, 0);
      expect(report.closure, (1, 1));

      final session = container.read(sessionProvider);
      expect(session.coins, 1);
      expect(session.totalBonusTiles, 1);
      // 2 fermetures détectées : le cluster forêt (8, éligible au bonus) et le
      // cluster plaine singleton au centre — toutes ses faces plaine font
      // face à des tuiles posées, donc il est compté par `closedBiomes`.
      expect(container.read(gridProvider).closedBiomes, 2);

      final last = container.read(lastPlacementProvider)!;
      expect(last.bonusTiles, 1);
      expect(last.coins, 1);
    });
  });

  group('confirmPlacement — pièces bonus (Pièces+)', () {
    test('un seuil de pièces franchi attribue le nombre exact de pièces bonus',
        () async {
      final container = await _makeContainer(
        activeTile: _allForest,
        effects: const ActiveUpgradeEffects(coinsThreshold: 4),
      );
      addTearDown(container.dispose);

      const origin = HexCoords(0, 0);
      _place(container, origin.neighbor(0), _allForest);
      _place(container, origin.neighbor(1), _allForest);
      _place(container, origin.neighbor(2), _allForest);

      final report = await _confirm(container, origin);

      // baseCoins = 3 connexions + 1 tuile bonus = 4 → 4 ~/ 4 = 1 pièce
      // bonus de type coinsPercentBonus (cumulable).
      expect(report.coinBonusTypes,
          {UpgradeEffectType.coinsPercentBonus: 1});

      // onConfirm expose reward.bonusCoins (pré-calcul de la preview, 0) ;
      // les pièces bonus réelles sont pilotées par onCoinBonusTypes et le
      // cumul de session.
      expect(report.bonusCoins, 0);
      final session = container.read(sessionProvider);
      expect(session.coins, 5); // 3 + 1 + 1 bonus
      expect(session.totalBonusTiles, 1);
    });
  });
}