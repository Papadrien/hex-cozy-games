/// Tests pour AudioService (musique de fond et bruitages).
///
/// L'environnement de test n'a pas de véritable sortie audio : ces tests
/// vérifient donc le comportement observable sans dépendre d'une lecture
/// audio réelle :
///  - [audioServiceProvider] construit un service utilisable et le dispose
///    proprement avec son container ;
///  - le gate `sfxEnabled` : bruitages désactivés → aucun appel bloquant,
///    quel que soit le nombre de pièces demandé ;
///  - le plafond de répétitions de [AudioService.playCoinsGained]
///    ([_kMaxCoinSfxRepeats] en interne) : un très grand nombre de pièces
///    ne doit jamais faire attendre indéfiniment (sinon le test expire) ;
///  - [AudioService.playCoinsGained] avec `count: 0` ne joue rien ;
///  - [AudioService.playTilePlaced] / [AudioService.playTileGained] ne
///    lèvent pas d'exception, bruitages activés ou non ;
///  - [AudioService.resumeMusicFromBackground] ne fait rien tant qu'aucune
///    musique n'a jamais été lancée.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/providers/options_provider.dart';
import 'package:hex_haven/services/audio_service.dart';

void main() {
  test('audioServiceProvider construit un AudioService', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(audioServiceProvider);
    expect(service, isA<AudioService>());
  });

  test('le service est disposé sans erreur avec son container', () {
    final container = ProviderContainer();
    container.read(audioServiceProvider);

    expect(container.dispose, returnsNormally);
  });

  test(
      'playCoinsGained ne joue rien et ne bloque pas quand les bruitages '
      'sont désactivés, même pour un grand nombre de pièces', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(optionsProvider.notifier).toggleSfx();
    final service = container.read(audioServiceProvider);

    final stopwatch = Stopwatch()..start();
    await service.playCoinsGained(500);
    stopwatch.stop();

    // Sans le early-return sur sfxEnabled, 500 itérations espacées de 80ms
    // prendraient ~40s : une exécution quasi instantanée prouve le gate.
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('playCoinsGained(0) ne joue rien (aucune itération)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(audioServiceProvider);

    await service.playCoinsGained(0).timeout(const Duration(seconds: 2));
  });

  test(
      'playCoinsGained plafonne ses répétitions (ne bloque pas '
      'indéfiniment même avec un très grand nombre de pièces)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(audioServiceProvider);

    // Sans plafond interne, 500 pièces * 80ms d'écart dépasserait largement
    // ce délai ; le plafond documenté (6 répétitions max) le rend rapide.
    await service.playCoinsGained(500).timeout(const Duration(seconds: 5));
  });

  test(
      'playTilePlaced et playTileGained ne lèvent pas d\'exception, '
      'bruitages activés ou désactivés', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(audioServiceProvider);

    await service.playTilePlaced();
    await service.playTileGained();

    container.read(optionsProvider.notifier).toggleSfx();
    await service.playTilePlaced();
    await service.playTileGained();
  });

  test(
      'resumeMusicFromBackground ne fait rien tant qu\'aucune musique '
      'n\'a été lancée', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(audioServiceProvider);

    await service
        .resumeMusicFromBackground()
        .timeout(const Duration(seconds: 2));
  });
}
