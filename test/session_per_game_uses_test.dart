/// Tests pour les compteurs d'utilisations par partie — Story B9.
///
/// Vérifie :
///  - [Session.initPerGameUses] initialise les deux compteurs depuis
///    [ActiveUpgradeEffects]
///  - [Session.consumeHoldSlot] et [Session.consumeSecondChance]
///    décrémentent chaque compteur indépendamment
///  - Les deux compteurs ne descendent jamais sous 0
///  - La consommation d'un compteur n'affecte pas le reste de l'état
///    de session (pièces, séries, etc.)
///  - [Session.reset] remet les deux compteurs à 0
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/providers/build_provider.dart';
import 'package:hex_haven/providers/session_provider.dart';

ProviderContainer _makeContainer() => ProviderContainer();

void main() {
  group('Session — initPerGameUses (Story B9)', () {
    test('initialise les deux compteurs depuis les améliorations actives',
        () {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.initPerGameUses(
        const ActiveUpgradeEffects(holdSlotUses: 2, secondChanceUses: 1),
      );

      final state = container.read(sessionProvider);
      expect(state.holdSlotRemainingUses, 2);
      expect(state.secondChanceRemainingUses, 1);
    });

    test('améliorations à zéro → compteurs à zéro', () {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.initPerGameUses(const ActiveUpgradeEffects());

      final state = container.read(sessionProvider);
      expect(state.holdSlotRemainingUses, 0);
      expect(state.secondChanceRemainingUses, 0);
    });
  });

  group('Session — consumeHoldSlot / consumeSecondChance (Story B9)', () {
    test('consumeHoldSlot décrémente uniquement le compteur Emplacement Joker',
        () {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.initPerGameUses(
        const ActiveUpgradeEffects(holdSlotUses: 2, secondChanceUses: 1),
      );
      notifier.consumeHoldSlot();

      final state = container.read(sessionProvider);
      expect(state.holdSlotRemainingUses, 1);
      expect(state.secondChanceRemainingUses, 1);
    });

    test(
        'consumeSecondChance décrémente uniquement le compteur Deuxième '
        'chance', () {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.initPerGameUses(
        const ActiveUpgradeEffects(holdSlotUses: 2, secondChanceUses: 1),
      );
      notifier.consumeSecondChance();

      final state = container.read(sessionProvider);
      expect(state.holdSlotRemainingUses, 2);
      expect(state.secondChanceRemainingUses, 0);
    });

    test('les compteurs ne descendent jamais sous 0', () {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.initPerGameUses(
        const ActiveUpgradeEffects(holdSlotUses: 1, secondChanceUses: 0),
      );
      notifier.consumeHoldSlot();
      notifier.consumeHoldSlot();
      notifier.consumeSecondChance();

      final state = container.read(sessionProvider);
      expect(state.holdSlotRemainingUses, 0);
      expect(state.secondChanceRemainingUses, 0);
    });
  });

  group('Session — non-interférence avec le reste de l\'état (Story B9)', () {
    test('consommer les compteurs ne modifie pas pièces/séries/connexions',
        () {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.initPerGameUses(
        const ActiveUpgradeEffects(holdSlotUses: 2, secondChanceUses: 2),
      );
      final before = container.read(sessionProvider);
      notifier.consumeHoldSlot();
      notifier.consumeSecondChance();
      final after = container.read(sessionProvider);

      expect(after.coins, before.coins);
      expect(after.totalBonusTiles, before.totalBonusTiles);
      expect(after.connections3, before.connections3);
      expect(after.connections4, before.connections4);
      expect(after.connections5, before.connections5);
      expect(after.connections6, before.connections6);
      expect(after.currentStreak, before.currentStreak);
      expect(after.bestStreak, before.bestStreak);
    });
  });

  group('Session — reset (Story B9)', () {
    test('reset remet les deux compteurs à 0', () {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.initPerGameUses(
        const ActiveUpgradeEffects(holdSlotUses: 3, secondChanceUses: 3),
      );
      notifier.reset();

      final state = container.read(sessionProvider);
      expect(state.holdSlotRemainingUses, 0);
      expect(state.secondChanceRemainingUses, 0);
    });
  });
}
