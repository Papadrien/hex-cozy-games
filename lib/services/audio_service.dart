/// Service centralisé pour l'audio du jeu : musique de fond et bruitages.
///
/// Activable/désactivable via le paramètre « Son » des options (voir
/// [optionsProvider]/[OptionsState.soundEnabled]) :
///  - la musique est coupée/rétablie en direct via [refreshMuteState]
///    (appelé depuis l'écran des réglages juste après
///    [OptionsStateNotifier.toggleSound]) — sans relancer la piste ni perdre
///    la position de lecture ;
///  - chaque bruitage vérifie le réglage à son propre déclenchement, comme
///    [HapticsService] pour les vibrations — les appelants n'ont pas besoin
///    de tester le réglage eux-mêmes.
///
/// Musique de fond ([MusicTrack]) :
///  - [MusicTrack.home] (home.mp3) : tous les écrans hors partie en cours
///    (splash, accueil, atelier, quêtes, boutique, stats, réglages).
///  - [MusicTrack.ambient] (ambient_1.mp3) : écran de partie en cours.
/// Un seul lecteur en boucle ([_musicPlayer]) — [playMusic] ne relance rien
/// si la piste demandée est déjà active, pour ne pas interrompre la musique
/// en circulant entre écrans qui partagent la même piste (ex. accueil →
/// boutique → accueil).
///
/// Bruitages ([SfxTrack]) : chaque appel pioche un lecteur dans un petit
/// pool tournant ([_sfxPool]), ce qui permet à plusieurs sons de se
/// chevaucher sans se couper les uns les autres — notamment
/// [playTilePlaced] qui démarre sans attendre la fin de [playTilePlacing].
/// La hauteur de chaque son est légèrement randomisée à chaque lecture
/// ([_kPitchVariance]) pour un rendu organique en cas de répétitions
/// rapprochées (ex. plusieurs poses de tuiles, ou plusieurs pièces gagnées
/// d'affilée via [playCoinsGained]).
library;

import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/options_provider.dart';

/// Pistes de musique de fond disponibles.
enum MusicTrack {
  home('audio/home.mp3'),
  ambient('audio/ambient_1.mp3');

  const MusicTrack(this.assetPath);

  /// Chemin relatif au dossier `assets/` (voir [AssetSource]).
  final String assetPath;
}

/// Bruitages ponctuels disponibles.
enum SfxTrack {
  coin('audio/coin.mp3'),
  tilePlacing('audio/tile_placing.mp3'),
  tilePlaced('audio/tile_placed.mp3');

  const SfxTrack(this.assetPath);

  /// Chemin relatif au dossier `assets/` (voir [AssetSource]).
  final String assetPath;
}

/// Variation de hauteur appliquée à chaque bruitage : ± cette valeur autour
/// de 1.0 (vitesse/hauteur normale), tirée aléatoirement à chaque lecture.
const double _kPitchVariance = 0.08;

/// Nombre de lecteurs dans le pool de bruitages — permet à plusieurs sons de
/// se superposer (ex. tile_placing encore audible quand tile_placed démarre)
/// sans s'interrompre mutuellement.
const int _kSfxPoolSize = 6;

/// Nombre maximal de `coin.mp3` joués pour un même placement — au-delà,
/// un très gros gain (améliorations cumulées) déclencherait une rafale
/// sonore de plusieurs secondes. Même plafond que
/// [HapticsService.playReward] pour rester cohérent avec le retour haptique.
const int _kMaxCoinSfxRepeats = 6;

/// Délai entre deux `coin.mp3` d'un même gain, pour qu'ils restent
/// perceptibles comme des impulsions distinctes plutôt qu'un unique son.
const Duration _kCoinSfxGap = Duration(milliseconds: 80);

class AudioService {
  AudioService(this._ref) {
    unawaited(_musicPlayer.setReleaseMode(ReleaseMode.loop));
  }

  final Ref _ref;
  final Random _random = Random();

  final AudioPlayer _musicPlayer = AudioPlayer();
  MusicTrack? _currentTrack;

  final List<AudioPlayer> _sfxPool =
      List.generate(_kSfxPoolSize, (_) => AudioPlayer());
  int _sfxCursor = 0;

  bool get _soundEnabled => _ref.read(optionsProvider).soundEnabled;

  /// Joue [track] en boucle, en remplaçant la piste en cours. Ne fait rien
  /// si [track] est déjà la piste active — évite un redémarrage audible en
  /// naviguant entre deux écrans qui partagent la même musique.
  ///
  /// Le volume suit immédiatement le réglage « Son » courant (silencieux
  /// mais lancé si désactivé, pour que [refreshMuteState] puisse rétablir
  /// le son instantanément sans avoir à relancer la piste).
  Future<void> playMusic(MusicTrack track) async {
    if (_currentTrack == track) return;
    _currentTrack = track;
    await _musicPlayer.setVolume(_soundEnabled ? 1.0 : 0.0);
    await _musicPlayer.play(AssetSource(track.assetPath));
  }

  /// Coupe/rétablit instantanément le volume de la musique en cours selon
  /// le réglage « Son » courant — à appeler juste après bascule du réglage
  /// (voir `settings_screen.dart`). Ne relance pas la piste et ne perd pas
  /// la position de lecture.
  Future<void> refreshMuteState() async {
    await _musicPlayer.setVolume(_soundEnabled ? 1.0 : 0.0);
  }

  /// Joue [sfx] avec une hauteur légèrement randomisée, sur un lecteur pris
  /// dans le pool tournant — n'attend pas la fin d'une éventuelle lecture
  /// précédente sur ce même lecteur (elle est simplement coupée), et
  /// n'interrompt jamais les autres lecteurs du pool.
  Future<void> _playSfx(SfxTrack sfx) async {
    if (!_soundEnabled) return;
    final player = _sfxPool[_sfxCursor];
    _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
    final pitch = 1.0 + (_random.nextDouble() * 2 - 1) * _kPitchVariance;
    await player.stop();
    await player.setPlaybackRate(pitch);
    await player.play(AssetSource(sfx.assetPath));
  }

  /// Joue `coin.mp3` une fois par pièce gagnée (plafonné à
  /// [_kMaxCoinSfxRepeats]), légèrement échelonnées pour rester perceptibles
  /// individuellement — chaque occurrence a sa propre variation de hauteur.
  /// N'attend la fin d'aucune lecture précédente : les sons peuvent se
  /// chevaucher.
  Future<void> playCoinsGained(int count) async {
    if (!_soundEnabled) return;
    final n = count.clamp(0, _kMaxCoinSfxRepeats);
    for (var i = 0; i < n; i++) {
      unawaited(_playSfx(SfxTrack.coin));
      if (i < n - 1) {
        await Future<void>.delayed(_kCoinSfxGap);
      }
    }
  }

  /// Départ de l'animation de descente d'une tuile posée.
  Future<void> playTilePlacing() => _playSfx(SfxTrack.tilePlacing);

  /// Arrivée d'une tuile posée à sa position finale (fin du rebond) — joué
  /// sans attendre la fin de [playTilePlacing].
  Future<void> playTilePlaced() => _playSfx(SfxTrack.tilePlaced);

  void _dispose() {
    _musicPlayer.dispose();
    for (final p in _sfxPool) {
      p.dispose();
    }
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(ref);
  ref.onDispose(service._dispose);
  return service;
});
