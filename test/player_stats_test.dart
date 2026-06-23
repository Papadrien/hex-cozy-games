/// Tests pour les statistiques joueur — Story 2.9a.
///
/// Vérifie :
///  - [computeMaxBiomeSizes] retourne les bonnes tailles de groupes
///  - [recordGameEnd] persiste correctement toutes les stats
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_cozy_games/data/app_database.dart';
import 'package:hex_cozy_games/data/seed_data.dart';
import 'package:hex_cozy_games/game/hex_cell.dart';
import 'package:hex_cozy_games/game/hex_coords.dart';
import 'package:hex_cozy_games/game/hex_tile.dart';
import 'package:hex_cozy_games/providers/grid_state_provider.dart';
import 'package:hex_cozy_games/providers/player_stats_provider.dart';

/// Crée une tuile dont les 6 faces sont du même biome.
HexTile _mono(BiomeType b) => HexTile(sides: List.filled(6, b));

/// Crée une tuile avec des biomes mixtes (forest/village).
HexTile _mixed() => HexTile(sides: [
      BiomeType.forest,
      BiomeType.forest,
      BiomeType.village,
      BiomeType.village,
      BiomeType.forest,
      BiomeType.forest,
    ]);

Future<AppDatabase> _makeDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedDatabase(db);
  return db;
}

void main() {
  group('computeMaxBiomeSizes', () {
    test('plateau vide → toutes les tailles à 0', () {
      final grid = GridState(placedTiles: {});
      final sizes = computeMaxBiomeSizes(grid);
      for (final biome in BiomeType.values) {
        expect(sizes[biome.name], 0);
      }
    });

    test('une seule tuile mono-biome → 1 pour ce biome', () {
      final grid = GridState(placedTiles: {
        HexCoords(0, 0): _mono(BiomeType.forest),
      });
      final sizes = computeMaxBiomeSizes(grid);
      expect(sizes['forest'], 1);
      expect(sizes['village'], 0);
    });

    test('deux tuiles forest adjacentes connectées → cluster de 2 forest', () {
      // Tuile en (0,0) avec forest partout.
      // Tuile en (1,0) avec forest partout.
      // Elles sont adjacentes. Le côté 2 de (0,0) touche le côté 5 de (1,0).
      final t = _mono(BiomeType.forest);
      final grid = GridState(placedTiles: {
        HexCoords(0, 0): t,
        HexCoords(1, 0): t,
      });
      final sizes = computeMaxBiomeSizes(grid);
      expect(sizes['forest'], 2);
    });

    test('deux clusters forest séparés → max = le plus grand', () {
      // Cluster A : (0,0) + (1,0) = 2
      // Cluster B : (0,2) + (1,2) + (2,2) = 3
      final t = _mono(BiomeType.forest);
      final grid = GridState(placedTiles: {
        HexCoords(0, 0): t,
        HexCoords(1, 0): t,
        HexCoords(0, 2): t,
        HexCoords(1, 2): t,
        HexCoords(2, 2): t,
      });
      final sizes = computeMaxBiomeSizes(grid);
      expect(sizes['forest'], 3);
    });

    test('tuile mixte forest+village → les deux biomes comptés', () {
      // (0,0) mixte : côtés 0,1,4,5 = forest ; côtés 2,3 = village
      // (1,0) mono forest → connecté côté 2 de (0,0) → forest
      // (0,1) mono village → connecté côté 3 de (0,0) → village
      final grid = GridState(placedTiles: {
        HexCoords(0, 0): _mixed(),
        HexCoords(1, 0): _mono(BiomeType.forest),
        HexCoords(0, 1): _mono(BiomeType.village),
      });
      final sizes = computeMaxBiomeSizes(grid);
      // forest : (0,0)+côtés 0,1,4,5 + (1,0) = 2
      // village : (0,0)+côtés 2,3 + (0,1) = 2
      expect(sizes['forest'], 2);
      expect(sizes['village'], 2);
    });
  });

  group('recordGameEnd', () {
    late AppDatabase db;

    setUp(() async {
      db = await _makeDb();
    });

    Future<PlayerStatsRow> getStats() async {
      return (db.select(db.playerStats)..where((t) => t.id.equals(1)))
          .getSingle();
    }

    test('première fin de partie → stats créées et à jour', () async {
      await recordGameEnd(
        db,
        coinsEarned: 50,
        score: 50,
        tilesPlacedInGame: 20,
        maxBiomeSizes: {'forest': 5, 'village': 3},
      );
      final stats = await getStats();
      expect(stats.totalCoinsEarned, 50);
      expect(stats.totalGamesPlayed, 1);
      expect(stats.totalTilesPlaced, 20);
      expect(stats.bestScore, 50);
      expect(stats.maxBiomeSizes, '{"forest":5,"village":3}');
    });

    test('deuxième partie → cumul et meilleur score', () async {
      // Première partie : score 50, 20 tuiles
      await recordGameEnd(
        db,
        coinsEarned: 50,
        score: 50,
        tilesPlacedInGame: 20,
        maxBiomeSizes: {'forest': 5},
      );
      // Deuxième partie : meilleur score 80, 30 tuiles
      await recordGameEnd(
        db,
        coinsEarned: 80,
        score: 80,
        tilesPlacedInGame: 30,
        maxBiomeSizes: {'village': 7, 'forest': 3},
      );

      final stats = await getStats();
      expect(stats.totalCoinsEarned, 130); // 50 + 80
      expect(stats.totalGamesPlayed, 2);
      expect(stats.totalTilesPlaced, 50); // 20 + 30
      expect(stats.bestScore, 80); // meilleur des deux
      // biome forest max = 5, village max = 7
      expect(stats.maxBiomeSizes, '{"forest":5,"village":7}');
    });

    test('meilleur score non écrasé si score inférieur', () async {
      await recordGameEnd(
        db,
        coinsEarned: 100,
        score: 100,
        tilesPlacedInGame: 30,
        maxBiomeSizes: {},
      );
      await recordGameEnd(
        db,
        coinsEarned: 30,
        score: 30,
        tilesPlacedInGame: 10,
        maxBiomeSizes: {},
      );

      final stats = await getStats();
      expect(stats.bestScore, 100);
    });
  });
}
