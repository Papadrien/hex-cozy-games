/// Tests pour OptionsStateNotifier (réglages son, vibrations et affichage).
///
/// Couvre :
///  - les valeurs par défaut (musique/bruitages activés, volumes à 1.0,
///    vibrations activées, mode immersif activé) ;
///  - toggleMusic / toggleSfx, indépendants l'un de l'autre ;
///  - setMusicVolume / setSfxVolume, bornés entre 0.0 et 1.0 et
///    indépendants l'un de l'autre ;
///  - toggleVibration ;
///  - toggleImmersive ;
///  - la persistance via SharedPreferences entre deux instances du
///    notifier ;
///  - la migration one-shot depuis les anciennes clés uniques
///    (`options_sound_enabled` / `options_volume`) vers les réglages
///    scindés musique/bruitages, avec nettoyage des clés historiques.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hex_haven/providers/options_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('valeurs par défaut', () async {
    await initOptionsPrefs();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(optionsProvider);
    expect(state.musicEnabled, isTrue);
    expect(state.sfxEnabled, isTrue);
    expect(state.musicVolume, 1.0);
    expect(state.sfxVolume, 1.0);
    expect(state.vibrationEnabled, isTrue);
    expect(state.immersiveEnabled, isTrue);
  });

  test('toggleMusic ne modifie pas sfxEnabled', () async {
    await initOptionsPrefs();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(optionsProvider.notifier);

    notifier.toggleMusic();
    expect(container.read(optionsProvider).musicEnabled, isFalse);
    expect(container.read(optionsProvider).sfxEnabled, isTrue);

    notifier.toggleMusic();
    expect(container.read(optionsProvider).musicEnabled, isTrue);
  });

  test('toggleSfx ne modifie pas musicEnabled', () async {
    await initOptionsPrefs();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(optionsProvider.notifier);

    notifier.toggleSfx();
    expect(container.read(optionsProvider).sfxEnabled, isFalse);
    expect(container.read(optionsProvider).musicEnabled, isTrue);

    notifier.toggleSfx();
    expect(container.read(optionsProvider).sfxEnabled, isTrue);
  });

  test(
      'setMusicVolume borne la valeur entre 0.0 et 1.0 et '
      'n\'affecte pas sfxVolume', () async {
    await initOptionsPrefs();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(optionsProvider.notifier);

    notifier.setMusicVolume(0.4);
    expect(container.read(optionsProvider).musicVolume, 0.4);
    expect(container.read(optionsProvider).sfxVolume, 1.0);

    notifier.setMusicVolume(-1.0);
    expect(container.read(optionsProvider).musicVolume, 0.0);

    notifier.setMusicVolume(5.0);
    expect(container.read(optionsProvider).musicVolume, 1.0);
  });

  test(
      'setSfxVolume borne la valeur entre 0.0 et 1.0 et '
      'n\'affecte pas musicVolume', () async {
    await initOptionsPrefs();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(optionsProvider.notifier);

    notifier.setSfxVolume(0.2);
    expect(container.read(optionsProvider).sfxVolume, 0.2);
    expect(container.read(optionsProvider).musicVolume, 1.0);

    notifier.setSfxVolume(-3.0);
    expect(container.read(optionsProvider).sfxVolume, 0.0);

    notifier.setSfxVolume(9.0);
    expect(container.read(optionsProvider).sfxVolume, 1.0);
  });

  test('toggleVibration', () async {
    await initOptionsPrefs();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(optionsProvider.notifier);

    notifier.toggleVibration();
    expect(container.read(optionsProvider).vibrationEnabled, isFalse);
    notifier.toggleVibration();
    expect(container.read(optionsProvider).vibrationEnabled, isTrue);
  });

  test('toggleImmersive n\'affecte pas les autres réglages', () async {
    await initOptionsPrefs();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(optionsProvider.notifier);

    expect(container.read(optionsProvider).immersiveEnabled, isTrue);

    notifier.toggleImmersive();
    expect(container.read(optionsProvider).immersiveEnabled, isFalse);
    expect(container.read(optionsProvider).musicEnabled, isTrue);
    expect(container.read(optionsProvider).sfxEnabled, isTrue);
    expect(container.read(optionsProvider).vibrationEnabled, isTrue);

    notifier.toggleImmersive();
    expect(container.read(optionsProvider).immersiveEnabled, isTrue);
  });

  test('initialImmersiveEnabled lit la préférence persistée', () async {
    SharedPreferences.setMockInitialValues({
      'options_immersive_enabled': false,
    });
    await initOptionsPrefs();

    expect(initialImmersiveEnabled(), isFalse);
  });

  test('les réglages persistent via SharedPreferences entre deux notifiers',
      () async {
    await initOptionsPrefs();
    final container1 = ProviderContainer();
    container1.read(optionsProvider.notifier)
      ..toggleMusic()
      ..setSfxVolume(0.3);
    container1.dispose();

    // Nouvelle instance : doit relire les valeurs sauvegardées dans le même
    // store SharedPreferences mocké plutôt que de repartir des défauts.
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final state = container2.read(optionsProvider);
    expect(state.musicEnabled, isFalse);
    expect(state.sfxVolume, 0.3);
    // Les réglages non touchés restent inchangés.
    expect(state.sfxEnabled, isTrue);
    expect(state.musicVolume, 1.0);
  });

  group('migration depuis les anciennes clés uniques', () {
    test('migre le réglage "son" unique vers musicEnabled + sfxEnabled',
        () async {
      SharedPreferences.setMockInitialValues({
        'options_sound_enabled': false,
      });
      await initOptionsPrefs();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(optionsProvider);
      expect(state.musicEnabled, isFalse);
      expect(state.sfxEnabled, isFalse);

      // La clé historique est nettoyée après migration, les deux nouvelles
      // clés sont bien écrites.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('options_sound_enabled'), isFalse);
      expect(prefs.getBool('options_music_enabled'), isFalse);
      expect(prefs.getBool('options_sfx_enabled'), isFalse);
    });

    test('migre le curseur de volume unique vers musicVolume + sfxVolume',
        () async {
      SharedPreferences.setMockInitialValues({
        'options_volume': 0.6,
      });
      await initOptionsPrefs();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(optionsProvider);
      expect(state.musicVolume, 0.6);
      expect(state.sfxVolume, 0.6);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('options_volume'), isFalse);
      expect(prefs.getDouble('options_music_volume'), 0.6);
      expect(prefs.getDouble('options_sfx_volume'), 0.6);
    });

    test(
        'ne migre qu\'une fois : un build() ultérieur ne relit pas '
        'la clé historique', () async {
      SharedPreferences.setMockInitialValues({
        'options_sound_enabled': false,
        'options_volume': 0.5,
      });
      await initOptionsPrefs();

      final container1 = ProviderContainer();
      expect(container1.read(optionsProvider).musicEnabled, isFalse);
      container1.dispose();

      // Entre-temps, l'utilisateur réactive la musique uniquement.
      final container2 = ProviderContainer();
      container2.read(optionsProvider.notifier).toggleMusic();
      expect(container2.read(optionsProvider).musicEnabled, isTrue);
      container2.dispose();

      // Un troisième build() ne doit pas re-écraser sfxEnabled=false avec
      // l'ancienne valeur "son" unique (les clés historiques ont déjà été
      // supprimées lors de la première migration).
      final container3 = ProviderContainer();
      addTearDown(container3.dispose);
      final state = container3.read(optionsProvider);
      expect(state.musicEnabled, isTrue);
      expect(state.sfxEnabled, isFalse);
    });
  });
}
