/// Tests pour la réclamation manuelle des récompenses de quêtes
/// ([QuestService.claimReward]).
///
/// Depuis cette story, une quête terminée (`isCompleted == true`) n'octroie
/// plus sa récompense automatiquement : elle reste en attente
/// (`rewardClaimed == false`, point rouge côté UI) tant que le joueur n'a
/// pas tapé dessus. Vérifie :
///  - la complétion d'une quête ne crédite pas les pièces immédiatement
///  - [claimReward] crédite la récompense et marque la quête réclamée
///  - un double appel à [claimReward] ne crédite pas deux fois (idempotence)
///  - [claimReward] sur une quête répétable réinitialise `currentValue`/
///    `isCompleted`/`rewardClaimed` pour permettre une nouvelle progression
///  - [claimReward] sur une quête non répétable ne touche pas au palier
///    suivant (déjà visible car seedé) et ne relance pas d'octroi
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/data/app_database.dart';
import 'package:hex_haven/data/seed_data.dart';
import 'package:hex_haven/providers/quest_provider.dart';

/// Installe une base mémoire, seed les données, et retourne un
/// [ProviderContainer] prêt à l'emploi.
///
/// Retourne `null` si sqlite3 natif n'est pas disponible sur cet
/// environnement (même garde que les autres tests de ce dossier).
Future<ProviderContainer?> _makeTestContainer() async {
  try {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDatabase(db);
    await db.into(db.playerProfile).insert(
          const PlayerProfileCompanion(id: Value(1)),
        );
    return ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  } catch (_) {
    return null;
  }
}

Future<PermanentQuestRow> _questById(AppDatabase db, String id) =>
    (db.select(db.permanentQuests)..where((q) => q.id.equals(id)))
        .getSingle();

void main() {
  group('QuestService — complétion sans octroi automatique', () {
    test('atteindre le palier marque isCompleted mais pas rewardClaimed, '
        'et ne crédite pas encore les pièces', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      // 'coins_500' (seed) : coins_earned, palier 500, récompense 50 pièces.
      await container
          .read(questServiceProvider)
          .onGameEnd(coinsEarned: 500, largestVillage: 0, closedBiomes: 0);

      final quest = await _questById(db, 'coins_500');
      expect(quest.isCompleted, isTrue);
      expect(quest.rewardClaimed, isFalse,
          reason: 'la récompense ne doit pas être auto-octroyée');

      final profile =
          await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
              .getSingle();
      expect(profile.coins, 0,
          reason: 'aucune pièce créditée avant réclamation manuelle');
    });
  });

  group('QuestService.claimReward', () {
    test('crédite la récompense et marque la quête réclamée', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await container
          .read(questServiceProvider)
          .onGameEnd(coinsEarned: 500, largestVillage: 0, closedBiomes: 0);
      await container.read(questServiceProvider).claimReward('coins_500');

      final quest = await _questById(db, 'coins_500');
      expect(quest.isCompleted, isTrue);
      expect(quest.rewardClaimed, isTrue);

      final profile =
          await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
              .getSingle();
      expect(profile.coins, 50);
    });

    test('un second appel ne crédite pas les pièces deux fois', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await container
          .read(questServiceProvider)
          .onGameEnd(coinsEarned: 500, largestVillage: 0, closedBiomes: 0);
      final service = container.read(questServiceProvider);
      await service.claimReward('coins_500');
      await service.claimReward('coins_500');

      final profile =
          await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
              .getSingle();
      expect(profile.coins, 50,
          reason: 'double-tap : la récompense ne doit être créditée '
              'qu\'une seule fois');
    });

    test('ne fait rien sur une quête non terminée', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await container.read(questServiceProvider).claimReward('coins_500');

      final quest = await _questById(db, 'coins_500');
      expect(quest.isCompleted, isFalse);
      expect(quest.rewardClaimed, isFalse);

      final profile =
          await (db.select(db.playerProfile)..where((t) => t.id.equals(1)))
              .getSingle();
      expect(profile.coins, 0);
    });

    test('quête répétable : la réclamation réinitialise le palier pour '
        'une nouvelle progression', () async {
      final container = await _makeTestContainer();
      if (container == null) return;
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      // 'connections_triple' (seed) : répétable, palier 100. La catégorie
      // contient aussi 'connections_triple_first' (one-shot, palier 15) qui
      // se complète en premier mais reste isRepeatable == false — on cible
      // spécifiquement la quête répétable pour ce test.
      final service = container.read(questServiceProvider);
      for (var i = 0; i < 100; i++) {
        final row = await _questById(db, 'connections_triple');
        if (row.isCompleted) break;
        await service.onTilePlaced(connectedSidesCount: 3);
      }

      final target = await _questById(db, 'connections_triple');
      expect(target.isCompleted, isTrue);
      expect(target.isRepeatable, isTrue);
      expect(target.rewardClaimed, isFalse);

      await service.claimReward(target.id);

      final reset = await _questById(db, target.id);
      expect(reset.currentValue, 0);
      expect(reset.isCompleted, isFalse);
      expect(reset.rewardClaimed, isFalse);
    });
  });
}
