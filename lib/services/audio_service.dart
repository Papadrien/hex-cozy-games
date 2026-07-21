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
/// chevaucher sans se couper les uns les autres. La hauteur de chaque son
/// est légèrement randomisée à chaque lecture
/// ([_kPitchVariance]) pour un rendu organique en cas de répétitions
/// rapprochées (ex. plusieurs poses de tuiles, ou plusieurs pièces gagnées
/// d'affilée via [playCoinsGained]).
///
/// [playTileGained] (tuile bonus gagnée arrivant sur la pile HUD) fait
/// exception à cette logique de chevauchement : elle utilise un lecteur
/// dédié unique ([_tileGainPlayer]) plutôt que le pool, pour qu'un gain
/// multi-tuiles coupe net le son de la tuile précédente à chaque nouvelle
/// arrivée au lieu de les superposer.
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
  tilePlaced('audio/tile_placed.mp3'),
  tileGain('audio/tile_gain.mp3');

  const SfxTrack(this.assetPath);

  /// Chemin relatif au dossier `assets/` (voir [AssetSource]).
  final String assetPath;
}

/// Variation de hauteur appliquée à chaque bruitage : ± cette valeur autour
/// de 1.0 (vitesse/hauteur normale), tirée aléatoirement à chaque lecture.
const double _kPitchVariance = 0.08;

/// Nombre de lecteurs dans le pool de bruitages — permet à plusieurs sons de
/// se superposer (ex. plusieurs `coin.mp3` d'affilée) sans s'interrompre
/// mutuellement.
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
    // Contexte audio global : `mixWithOthers` sur iOS/Android garantit que
    // la musique de fond et les bruitages (pool SFX, tile gain) se
    // superposent toujours au lieu de s'interrompre mutuellement — sans
    // cette configuration, la plateforme peut couper le lecteur en cours
    // (ou le mettre en pause) dès qu'un autre lecteur démarre.
    try {
      unawaited(AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      ));
    } catch (_) {
      // Ignorer les erreurs de configuration audio sur les plateformes qui ne
      // supportent pas ces options (ex. Linux en test).
    }
    unawaited(_musicPlayer.setReleaseMode(ReleaseMode.loop));
  }

  final Ref _ref;
  final Random _random = Random();

  final AudioPlayer _musicPlayer = AudioPlayer();
  MusicTrack? _currentTrack;

  final List<AudioPlayer> _sfxPool =
      List.generate(_kSfxPoolSize, (_) => AudioPlayer());
  int _sfxCursor = 0;

  /// Lecteur dédié pour [SfxTrack.tileGain] — volontairement en dehors du
  /// pool : contrairement aux autres bruitages, une nouvelle tuile gagnée
  /// doit couper net le son de la précédente si elle n'est pas terminée,
  /// jamais les superposer (voir [playTileGained]).
  final AudioPlayer _tileGainPlayer = AudioPlayer();

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

  /// Met en pause la musique de fond quand l'app passe en arrière-plan (voir
  /// `main.dart`, `didChangeAppLifecycleState` — [AppLifecycleState.paused]).
  /// Conserve la position de lecture pour une reprise transparente via
  /// [resumeMusicFromBackground]. Sans effet sur les bruitages ponctuels
  /// (pool SFX, tile gain), qui n'ont pas vocation à continuer en tâche de
  /// fond de toute façon.
  Future<void> pauseMusicForBackground() async {
    await _musicPlayer.pause();
  }

  /// Reprend la musique de fond interrompue par [pauseMusicForBackground] au
  /// retour au premier plan ([AppLifecycleState.resumed]). Ne fait rien si
  /// aucune piste n'a jamais été lancée.
  Future<void> resumeMusicFromBackground() async {
    if (_currentTrack == null) return;
    await _musicPlayer.resume();
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

  /// Arrivée d'une tuile posée à sa position finale (fin du rebond).
  Future<void> playTilePlaced() => _playSfx(SfxTrack.tilePlaced);

  /// Joue `tile_gain.mp3` à chaque tuile bonus qui arrive sur la pile HUD
  /// (voir `game_screen.dart`, `onBonusImpact` — un appel par icône de
  /// tuile arrivée, échelonné dans le temps pour un gain multi-tuiles).
  ///
  /// Contrairement à [_playSfx], qui pioche dans le pool pour laisser les
  /// sons se chevaucher, cette méthode réutilise toujours le même lecteur
  /// dédié ([_tileGainPlayer]) : si le son de la tuile précédente n'est pas
  /// terminé quand une nouvelle tuile arrive, il est coupé net avant de
  /// démarrer le nouveau, plutôt que superposé.
  Future<void> playTileGained() async {
    if (!_soundEnabled) return;
    await _tileGainPlayer.stop();
    await _tileGainPlayer.play(AssetSource(SfxTrack.tileGain.assetPath));
  }

  void _dispose() {
    _musicPlayer.dispose();
    for (final p in _sfxPool) {
      p.dispose();
    }
    _tileGainPlayer.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(ref);
  ref.onDispose(service._dispose);
  return service;
});
