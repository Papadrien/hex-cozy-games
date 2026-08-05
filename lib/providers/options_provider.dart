/// Réglages son, vibrations et affichage — Story 1.5bis-a.
///
/// Provider persisté via `shared_preferences` pour que les choix du joueur
/// survivent aux redémarrages de l'app. Les valeurs par défaut sont
/// `true` (musique activée, bruitages activés, vibrations activées, mode
/// immersif activé) et `1.0` (volumes maximum).
///
/// L'ancien réglage unique « Son » ([_kLegacySoundKey]) a été scindé en deux
/// réglages indépendants — [OptionsState.musicEnabled] (musique de fond) et
/// [OptionsState.sfxEnabled] (bruitages) — pour que le joueur puisse par
/// exemple couper la musique tout en gardant les bruitages de jeu. De même,
/// l'ancien curseur de volume unique ([_kLegacyVolumeKey]) a été scindé en
/// [OptionsState.musicVolume] et [OptionsState.sfxVolume], chacun modulant
/// uniquement sa catégorie. Une seule migration a lieu au premier démarrage
/// suivant la mise à jour (voir [OptionsStateNotifier.build]) : chaque
/// valeur historique est reportée sur les deux nouveaux réglages
/// correspondants, puis les clés historiques sont supprimées.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OptionsState {
  const OptionsState({
    this.musicEnabled = true,
    this.sfxEnabled = true,
    this.musicVolume = 1.0,
    this.sfxVolume = 1.0,
    this.vibrationEnabled = true,
    this.immersiveEnabled = true,
  });

  final bool musicEnabled;
  final bool sfxEnabled;

  /// Niveau sonore de la musique de fond, de 0.0 (silencieux) à 1.0
  /// (maximum). Indépendant de [musicVolume] et [sfxEnabled]/[sfxVolume].
  final double musicVolume;

  /// Niveau sonore des bruitages, de 0.0 (silencieux) à 1.0 (maximum).
  /// Indépendant de [sfxEnabled]... et de [musicEnabled]/[musicVolume].
  final double sfxVolume;
  final bool vibrationEnabled;

  /// Mode immersif activé : barres système (statut/navigation) masquées
  /// pendant le jeu (`SystemUiMode.immersiveSticky`). Quand il est
  /// désactivé, on revient à un affichage classique avec barres visibles
  /// pour que le joueur puisse voir l'heure ou le niveau de batterie.
  ///
  /// L'application effective au système est faite par les appelants
  /// (démarrage, retour au premier plan, écran Réglages) via
  /// `applySystemUiMode` de `services/system_ui_service.dart`.
  final bool immersiveEnabled;
}

/// Instance SharedPreferences pré-chargée au démarrage de l'app (voir
/// [main]). Utilisée par [OptionsStateNotifier] pour lire/écrire les
/// préférences sans appels asynchrones dans `build()`.
/// `null` avant l'initialisation (tests) — fallback sur valeurs par défaut.
SharedPreferences? _prefs;

Future<void> initOptionsPrefs() async {
  _prefs = await SharedPreferences.getInstance();
}

/// Préférence de mode immersif lue avant l'initialisation du notifier —
/// utilisée par [main] pour appliquer le mode d'affichage système avant
/// `runApp`. `true` par défaut : le mode immersif est l'expérience par
/// défaut du jeu.
bool initialImmersiveEnabled() =>
    _prefs?.getBool(OptionsStateNotifier.immersiveKey) ?? true;

class OptionsStateNotifier extends Notifier<OptionsState> {
  /// Ancienne clé unique « Son » (avant la scission musique/bruitages) —
  /// conservée uniquement pour la migration one-shot dans [build].
  static const _kLegacySoundKey = 'options_sound_enabled';
  /// Ancienne clé de volume unique (avant la scission musique/bruitages) —
  /// conservée uniquement pour la migration one-shot dans [build].
  static const _kLegacyVolumeKey = 'options_volume';
  static const _kMusicKey = 'options_music_enabled';
  static const _kSfxKey = 'options_sfx_enabled';
  static const _kMusicVolumeKey = 'options_music_volume';
  static const _kSfxVolumeKey = 'options_sfx_volume';
  static const _kVibrationKey = 'options_vibration_enabled';
  static const _kImmersiveKey = 'options_immersive_enabled';

  /// Clé de préférence du mode immersif — exposée pour la lecture initiale
  /// avant l'initialisation du notifier (voir [initialImmersiveEnabled]).
  static const immersiveKey = _kImmersiveKey;

  @override
  OptionsState build() {
    final p = _prefs;
    final vibration = p?.getBool(_kVibrationKey) ?? true;
    final immersive = p?.getBool(_kImmersiveKey) ?? true;

    final legacyVolume = p?.getDouble(_kLegacyVolumeKey);
    double musicVolume;
    double sfxVolume;
    if (legacyVolume != null) {
      // Migration one-shot : reporte l'ancien curseur unique sur les deux
      // nouveaux, puis nettoie la clé historique pour ne migrer qu'une fois.
      p?.setDouble(_kMusicVolumeKey, legacyVolume);
      p?.setDouble(_kSfxVolumeKey, legacyVolume);
      p?.remove(_kLegacyVolumeKey);
      musicVolume = legacyVolume;
      sfxVolume = legacyVolume;
    } else {
      musicVolume = p?.getDouble(_kMusicVolumeKey) ?? 1.0;
      sfxVolume = p?.getDouble(_kSfxVolumeKey) ?? 1.0;
    }

    final legacySound = p?.getBool(_kLegacySoundKey);
    if (legacySound != null) {
      // Migration one-shot : reporte l'ancien réglage unique sur les deux
      // nouveaux, puis nettoie la clé historique pour ne migrer qu'une fois.
      p?.setBool(_kMusicKey, legacySound);
      p?.setBool(_kSfxKey, legacySound);
      p?.remove(_kLegacySoundKey);
      return OptionsState(
        musicEnabled: legacySound,
        sfxEnabled: legacySound,
        musicVolume: musicVolume,
        sfxVolume: sfxVolume,
        vibrationEnabled: vibration,
        immersiveEnabled: immersive,
      );
    }

    final music = p?.getBool(_kMusicKey) ?? true;
    final sfx = p?.getBool(_kSfxKey) ?? true;
    return OptionsState(
      musicEnabled: music,
      sfxEnabled: sfx,
      musicVolume: musicVolume,
      sfxVolume: sfxVolume,
      vibrationEnabled: vibration,
      immersiveEnabled: immersive,
    );
  }

  void toggleMusic() {
    state = OptionsState(
      musicEnabled: !state.musicEnabled,
      sfxEnabled: state.sfxEnabled,
      musicVolume: state.musicVolume,
      sfxVolume: state.sfxVolume,
      vibrationEnabled: state.vibrationEnabled,
      immersiveEnabled: state.immersiveEnabled,
    );
    _prefs?.setBool(_kMusicKey, state.musicEnabled);
  }

  void toggleSfx() {
    state = OptionsState(
      musicEnabled: state.musicEnabled,
      sfxEnabled: !state.sfxEnabled,
      musicVolume: state.musicVolume,
      sfxVolume: state.sfxVolume,
      vibrationEnabled: state.vibrationEnabled,
      immersiveEnabled: state.immersiveEnabled,
    );
    _prefs?.setBool(_kSfxKey, state.sfxEnabled);
  }

  /// Définit le niveau sonore de la musique (voir [OptionsState.musicVolume]),
  /// [value] étant automatiquement borné entre 0.0 et 1.0.
  void setMusicVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    state = OptionsState(
      musicEnabled: state.musicEnabled,
      sfxEnabled: state.sfxEnabled,
      musicVolume: clamped,
      sfxVolume: state.sfxVolume,
      vibrationEnabled: state.vibrationEnabled,
      immersiveEnabled: state.immersiveEnabled,
    );
    _prefs?.setDouble(_kMusicVolumeKey, clamped);
  }

  /// Définit le niveau sonore des bruitages (voir [OptionsState.sfxVolume]),
  /// [value] étant automatiquement borné entre 0.0 et 1.0.
  void setSfxVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    state = OptionsState(
      musicEnabled: state.musicEnabled,
      sfxEnabled: state.sfxEnabled,
      musicVolume: state.musicVolume,
      sfxVolume: clamped,
      vibrationEnabled: state.vibrationEnabled,
      immersiveEnabled: state.immersiveEnabled,
    );
    _prefs?.setDouble(_kSfxVolumeKey, clamped);
  }

  void toggleVibration() {
    state = OptionsState(
      musicEnabled: state.musicEnabled,
      sfxEnabled: state.sfxEnabled,
      musicVolume: state.musicVolume,
      sfxVolume: state.sfxVolume,
      vibrationEnabled: !state.vibrationEnabled,
      immersiveEnabled: state.immersiveEnabled,
    );
    _prefs?.setBool(_kVibrationKey, state.vibrationEnabled);
  }

  /// Active/désactive le mode immersif (barres système masquées pendant le
  /// jeu — voir [OptionsState.immersiveEnabled]). L'application effective au
  /// système est faite par les appelants (démarrage, retour au premier plan,
  /// écran Réglages) via `applySystemUiMode`.
  void toggleImmersive() {
    state = OptionsState(
      musicEnabled: state.musicEnabled,
      sfxEnabled: state.sfxEnabled,
      musicVolume: state.musicVolume,
      sfxVolume: state.sfxVolume,
      vibrationEnabled: state.vibrationEnabled,
      immersiveEnabled: !state.immersiveEnabled,
    );
    _prefs?.setBool(_kImmersiveKey, state.immersiveEnabled);
  }
}

final optionsProvider = NotifierProvider<OptionsStateNotifier, OptionsState>(
  OptionsStateNotifier.new,
);
