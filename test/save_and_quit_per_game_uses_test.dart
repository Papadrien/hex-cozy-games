/// Test de non-régression — Sauvegarder et quitter perdait les compteurs
/// d'utilisations par partie d'Emplacement Joker et de Deuxième chance
/// (Story B9), les faisant retomber à 0 après une reprise de partie.
///
/// Cause : [SessionSaver.save] ne persistait pas
/// [SessionState.holdSlotRemainingUses] / [SessionState.secondChanceRemainingUses],
/// et [restoreSession] reconstruisait un [SessionState] neuf où ces deux
/// champs retombent silencieusement à leur valeur par défaut (0).
///
/// Vérifie que le cycle complet save → reset (simulateur de redémarrage
/// d'app) → restore restitue fidèlement les deux compteurs, y compris
/// après consommation partielle, et que les sessions sauvegardées avant ce
/// correctif (sans les clés JSON) restaurent 0 sans planter.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/data/app_database.dart';
import 'package:hex_haven/data/seed_data.dart';
import 'package:hex_haven/providers/build_provider.dart';
import 'package:hex_haven/providers/placement_commit.dart';
import 'package:hex_haven/providers/session_provider.dart';
import 'package:hex_haven/providers/session_restore.dart';

/// Retourne `null` si sqlite3 natif n'est pas disponible sur cet
/// environnement (même garde que les autres tests DB du projet).
Future<ProviderContainer?> _makeTestContainer() async {
  try {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDatabase(db);
    return ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  } catch (_) {
    return null;
  }
}

void main() {
  testWidgets(
    'Sauvegarder et quitter conserve les utilisations restantes '
    "d'Emplacement Joker et de Deuxième chance",
    (tester) async {
      final container = await _makeTestContainer();
      if (container == null) return; // sqlite3 natif indisponible ici.
      addTearDown(container.dispose);

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Démarre une partie puis simule 2 Emplacement Joker et 1 Deuxième
      // chance achetés, avec une utilisation déjà consommée de chaque.
      startNewGame(capturedRef);
      capturedRef.read(sessionProvider.notifier).initPerGameUses(
            const ActiveUpgradeEffects(holdSlotUses: 2, secondChanceUses: 2),
          );
      capturedRef.read(sessionProvider.notifier).consumeHoldSlot();
      capturedRef.read(sessionProvider.notifier).consumeSecondChance();

      final beforeSave = capturedRef.read(sessionProvider);
      expect(beforeSave.holdSlotRemainingUses, 1);
      expect(beforeSave.secondChanceRemainingUses, 1);

      await SessionSaver.save(capturedRef.container);

      // Simule un redémarrage d'app : les providers reviennent à zéro.
      capturedRef.read(sessionProvider.notifier).reset();
      expect(capturedRef.read(sessionProvider).holdSlotRemainingUses, 0);
      expect(capturedRef.read(sessionProvider).secondChanceRemainingUses, 0);

      await restoreSession(capturedRef);

      final afterRestore = capturedRef.read(sessionProvider);
      expect(afterRestore.holdSlotRemainingUses, 1,
          reason: 'Emplacement Joker doit conserver ses utilisations '
              'restantes après Sauvegarder et quitter.');
      expect(afterRestore.secondChanceRemainingUses, 1,
          reason: 'Deuxième chance doit conserver ses utilisations '
              'restantes après Sauvegarder et quitter.');
    },
  );

  testWidgets(
    'restoreSession reste rétro-compatible avec une session sauvegardée '
    'avant ce correctif (sans les clés holdSlot/secondChance dans le JSON)',
    (tester) async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      startNewGame(capturedRef);
      await SessionSaver.save(capturedRef.container);

      // Réécrit la ligne sauvegardée en retirant les nouvelles clés JSON,
      // pour simuler une sauvegarde antérieure au correctif.
      final db = capturedRef.read(appDatabaseProvider);
      final row =
          await (db.select(db.activeBoardSession)..limit(1)).getSingle();
      final stackJson = jsonDecode(row.tileStack) as Map<String, dynamic>
        ..remove('holdSlotRemainingUses')
        ..remove('secondChanceRemainingUses');
      await (db.update(db.activeBoardSession)..where((t) => t.id.equals(1)))
          .write(
        ActiveBoardSessionCompanion(tileStack: Value(jsonEncode(stackJson))),
      );

      await restoreSession(capturedRef);

      final afterRestore = capturedRef.read(sessionProvider);
      expect(afterRestore.holdSlotRemainingUses, 0);
      expect(afterRestore.secondChanceRemainingUses, 0);
    },
  );
}
