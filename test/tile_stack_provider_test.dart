// Tests unitaires pour tileStackProvider — Story 1.4a / 1.9a.
//
// Vérifie :
//  - le pool généré a la taille de kStartingTiles
//  - chaque tuile respecte max 3 biomes et arcs contigus
//  - exactement kVisibleStackSize tuiles sont visibles
//  - consommer la tuile active fait avancer la pile correctement
//  - la pile épuisée n'est pas ré-alimentée (fin de partie)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/core/constants.dart';
import 'package:hex_haven/game/hex_cell.dart';
import 'package:hex_haven/game/hex_coords.dart';
import 'package:hex_haven/game/hex_tile.dart';
import 'package:hex_haven/providers/build_provider.dart';
import 'package:hex_haven/providers/grid_state_provider.dart';
import 'package:hex_haven/providers/tile_stack_provider.dart';

void main() {
  group('tileStackProvider', () {
    ProviderContainer makeContainer() => ProviderContainer(overrides: [
          activeUpgradeEffectsProvider
              .overrideWithValue(const ActiveUpgradeEffects()),
        ]);

    test('expose kVisibleStackSize tuiles visibles et le bon "remaining"', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final state = container.read(tileStackProvider);

      expect(state.visible.length, kVisibleStackSize);
      expect(state.remaining, kStartingTiles);
      expect(state.activeTile, state.visible.first);
    });

    test('le pool généré respecte max 3 biomes et arcs contigus', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final drawn = <HexTile>[];
      for (var i = 0; i < kStartingTiles; i++) {
        final active = container.read(tileStackProvider).activeTile;
        expect(active, isNotNull);
        drawn.add(active!);
        container.read(tileStackProvider.notifier).consumeActiveTile();
      }

      expect(drawn.length, kStartingTiles);

      for (final tile in drawn) {
        // Max 3 biomes par tuile.
        expect(tile.biomeCount, lessThanOrEqualTo(kMaxBiomeTypesPerTile));

        // Arcs contigus : après rotation, les biomes identiques sont groupés.
        // On dédouble la liste pour gérer le wrap-around, et on vérifie
        // que chaque biome n'apparaît que dans un seul bloc continu.
        final sides = tile.sides;
        final doubled = [...sides, ...sides];
        final firsts = <BiomeType, int>{};
        for (var i = 0; i < 6; i++) {
          firsts.putIfAbsent(sides[i], () => i);
        }
        for (final entry in firsts.entries) {
          final start = entry.value;
          final count = sides.where((b) => b == entry.key).length;
          // Tous les count exemplaires doivent être consécutifs à partir
          // de [start].
          for (var i = 0; i < count; i++) {
            expect(doubled[start + i], entry.key);
          }
        }
      }
    });

    test('consumeActiveTile fait avancer la pile et décrémente remaining', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final before = container.read(tileStackProvider);
      final firstTile = before.visible[0];
      final secondTile = before.visible[1];

      container.read(tileStackProvider.notifier).consumeActiveTile();

      final after = container.read(tileStackProvider);
      expect(after.remaining, before.remaining - 1);
      // L'ancienne 2e tuile devient la nouvelle active.
      expect(after.visible.first, secondTile);
      expect(after.visible.first, isNot(firstTile));
    });

    test('la pile épuisée ne se ré-alimente pas (fin de partie)', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      // Vide complètement la pile initiale.
      for (var i = 0; i < kStartingTiles; i++) {
        container.read(tileStackProvider.notifier).consumeActiveTile();
      }

      final state = container.read(tileStackProvider);
      // La pile est vide : plus de tuiles visibles, remaining = 0.
      expect(state.visible.length, 0);
      expect(state.remaining, 0);
      expect(state.activeTile, isNull);
    });
  });

  group('tileStackProvider — Couleur détestée (activation)', () {
    ProviderContainer makeContainer({int hatedColorExclusionDuration = 0}) =>
        ProviderContainer(overrides: [
          activeUpgradeEffectsProvider.overrideWithValue(
            ActiveUpgradeEffects(
              hatedColorExclusionDuration: hatedColorExclusionDuration,
            ),
          ),
        ]);

    test("l'exclusion n'est pas active au lancement de la partie", () {
      final container = makeContainer(hatedColorExclusionDuration: 5);
      addTearDown(container.dispose);

      final state = container.read(tileStackProvider);
      expect(state.excludeBiome, isNull);
      expect(state.hatedDuration, 0);
      expect(state.hatedActivated, isFalse);
    });

    test('activateHatedColor active l\'exclusion pour une couleur de base', () {
      final container = makeContainer(hatedColorExclusionDuration: 5);
      addTearDown(container.dispose);

      container.read(tileStackProvider.notifier).activateHatedColor();
      final state = container.read(tileStackProvider);

      expect(state.hatedActivated, isTrue);
      expect(state.hatedDuration, 5);
      expect(state.hatedStartCount, 0);
      expect(state.excludeBiome, isNotNull);
      // Seules les couleurs disponibles dès le lancement (sans palier de
      // déblocage) peuvent être tirées.
      expect(unlockedBiomesAt(1), contains(state.excludeBiome));
      expect(kBiomeUnlockThresholds.containsKey(state.excludeBiome), isFalse);
    });

    test('la couleur exclue ne réapparaît pas sur les tuiles suivantes', () {
      final container = makeContainer(hatedColorExclusionDuration: 5);
      addTearDown(container.dispose);

      container.read(tileStackProvider.notifier).activateHatedColor();
      final excluded = container.read(tileStackProvider).excludeBiome!;

      for (var i = 0; i < 5; i++) {
        final tile = container.read(tileStackProvider).activeTile!;
        expect(tile.sides, isNot(contains(excluded)));
        container.read(tileStackProvider.notifier).consumeActiveTile();
      }
    });

    test('un deuxième appel pendant une exclusion en cours ne change rien', () {
      final container = makeContainer(hatedColorExclusionDuration: 5);
      addTearDown(container.dispose);

      final notifier = container.read(tileStackProvider.notifier);
      notifier.activateHatedColor();
      final biomeAfterFirstCall = container.read(tileStackProvider).excludeBiome;

      // Un deuxième appel ne doit rien changer (exclusion déjà en cours).
      notifier.activateHatedColor();
      final state = container.read(tileStackProvider);
      expect(state.excludeBiome, biomeAfterFirstCall);
      expect(state.hatedActivated, isTrue);
    });

    test('activateHatedColor peut être réactivée une fois l\'exclusion précédente terminée', () {
      final container = makeContainer(hatedColorExclusionDuration: 3);
      addTearDown(container.dispose);

      final notifier = container.read(tileStackProvider.notifier);
      notifier.activateHatedColor();
      expect(hatedColorTilesRemaining(container.read(tileStackProvider), 0), 3);

      // Consomme les 3 tuiles de la fenêtre d'exclusion : elle se termine.
      final dummyTile = HexTile(sides: const [BiomeType.forest, BiomeType.forest, BiomeType.village, BiomeType.village, BiomeType.plain, BiomeType.plain]);
      for (var i = 0; i < 3; i++) {
        container.read(gridProvider.notifier).placeTile(HexCoords(i, 0), dummyTile);
        notifier.consumeActiveTile();
      }
      expect(
        hatedColorTilesRemaining(container.read(tileStackProvider), 3),
        isNull,
      );

      // Une nouvelle activation doit maintenant réussir (nouvelle couleur
      // possible, durée repart à zéro).
      notifier.activateHatedColor();
      final state = container.read(tileStackProvider);
      expect(state.hatedStartCount, 3);
      expect(hatedColorTilesRemaining(state, 3), 3);
    });

    test('activateHatedColor ne fait rien si l\'amélioration n\'est pas possédée', () {
      final container = makeContainer(); // hatedColorExclusionDuration = 0
      addTearDown(container.dispose);

      container.read(tileStackProvider.notifier).activateHatedColor();
      final state = container.read(tileStackProvider);

      expect(state.excludeBiome, isNull);
      expect(state.hatedActivated, isFalse);
    });
  });
}
