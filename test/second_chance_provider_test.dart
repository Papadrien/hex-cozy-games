/// Tests pour l'état du mode sélection de Deuxième chance — Story B11.
///
/// Vérifie :
///  - mode inactif à l'initialisation
///  - [SecondChanceMode.activate] active le mode
///  - [SecondChanceMode.cancel] désactive le mode
///
/// Note : l'orchestration cross-provider ([toggleSecondChanceMode],
/// [removePlacedTile], dans `placement_commit.dart`) opère sur un
/// [WidgetRef] au même titre que [startNewGame] / [undoPlacement], qui ne
/// sont pas couverts par des tests unitaires dans ce projet (nécessiteraient
/// un test widget). Ce fichier se limite donc à l'état géré par
/// [secondChanceModeProvider] lui-même.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/providers/second_chance_provider.dart';

void main() {
  group('secondChanceModeProvider (Story B11)', () {
    test('inactif à l\'initialisation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(secondChanceModeProvider), isFalse);
    });

    test('activate() active le mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(secondChanceModeProvider.notifier).activate();

      expect(container.read(secondChanceModeProvider), isTrue);
    });

    test('cancel() désactive le mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(secondChanceModeProvider.notifier).activate();

      container.read(secondChanceModeProvider.notifier).cancel();

      expect(container.read(secondChanceModeProvider), isFalse);
    });
  });
}
