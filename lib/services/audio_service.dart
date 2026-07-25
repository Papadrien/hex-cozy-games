/// Service centralisé pour l'audio du jeu : musique de fond et bruitages.
///
/// Activables/désactivables séparément via les paramètres « Musique » et
/// « Bruitages » des options (voir [optionsProvider] /
/// [OptionsState.musicEnabled] / [OptionsState.sfxEnabled]), chacun modulé
/// en intensité par son propre curseur — [OptionsState.musicVolume] pour la
/// musique, [OptionsState.sfxVolume] pour les bruitages :
///  - la musique est coupée/rétablie et son volume ajusté en direct via
///    [refreshMusicVolume] (appelé depuis l'écran des réglages juste après
///    [OptionsStateNotifier.toggleMusic] ou
///    [OptionsStateNotifier.setMusicVolume]) — sans relancer la piste ni
///    perdre la position de lecture ;
///  - chaque bruitage vérifie le réglage et applique son propre volume
///    courant à son propre déclenchement, comme [HapticsService] pour les
///    vibrations — les appelants n'ont pas besoin de tester le réglage
///    eux-mêmes.
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
///
/// [playEndGame] (end_game.mp3) suit le même principe de lecteur dédié
/// ([_endGamePlayer]) — déclenché une seule fois par [ResultsModal] (voir
/// `results_modal.dart`) à l'apparition de la pop-up de résultats, sur la
/// transition de [isGameOverProvider] vers `true`.
///
/// [playUndo] (undo.mp3) pioche dans le pool tournant comme
/// [playCoinsGained] / [playTilePlaced] — déclenché depuis [undoPlacement]
/// (voir `undo_placement.dart`) à chaque annulation du dernier placement.
///
/// Clic de bouton ([playButtonClick]) et clic de pose de tuile
/// ([playTilePlaced]) : contrairement aux autres bruitages, ils ne sont
/// associés à aucun fichier audio — leur forme d'onde est générée
/// procéduralement en mémoire ([_generateClickWaveform], un bref clic dans
/// la tonalité d'une touche de clavier mécanique : transitoire de bruit
/// filtré + corps résonant à deux harmoniques, chacun avec sa propre
/// décroissance exponentielle) puis jouée via [BytesSource]. Le clic de
/// pose de tuile réutilise le même générateur avec des fréquences plus
/// aiguës ([_kTileKnockFundamentalFreq]/[_kTileKnockHarmonicFreq]) que le
/// clic de bouton, pour rester distinct à l'oreille. [playButtonClick] est
/// pensé pour être déclenché par [buttonTapFeedback]
/// (voir `haptics_service.dart`) sur tout bouton de l'application qui ne
/// possède pas déjà son propre bruitage dédié.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

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

/// Bruitages ponctuels disponibles, basés sur un fichier audio. Le clic de
/// pose de tuile n'en fait pas partie : il est généré procéduralement (voir
/// [AudioService.playTilePlaced]).
enum SfxTrack {
  coin('audio/coin.mp3'),
  tileGain('audio/tile_gain.mp3'),
  endGame('audio/end_game.mp3'),
  undo('audio/undo.mp3');

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
const Duration _kCoinSfxGap = Duration(milliseconds: 250);

/// Durée par défaut du fondu de sortie appliqué par [AudioService.playMusicWithFadeOut]
/// avant de basculer sur la nouvelle piste — assez bref pour rester discret
/// pendant une transition d'écran, assez long pour éviter une coupure nette.
const Duration _kMusicFadeOutDuration = Duration(milliseconds: 500);

/// Nombre de paliers de volume utilisés pour le fondu de
/// [AudioService.playMusicWithFadeOut] — un compromis entre fluidité perçue
/// et nombre d'appels à [AudioPlayer.setVolume].
const int _kMusicFadeSteps = 12;

/// Fréquence d'échantillonnage du clic de bouton généré procéduralement
/// (voir [_generateClickWaveform]). 44,1 kHz suffit largement pour un son
/// aussi bref et évite tout souci de compatibilité de lecture.
const int _kClickSampleRate = 44100;

/// Durée du clic de bouton généré, en millisecondes — volontairement bref
/// pour rester discret même en cas de taps rapprochés (navigation rapide
/// entre plusieurs boutons), tout en laissant le temps au « corps »
/// résonant du clic ([_kButtonKnockDecayTauSeconds]) de s'éteindre
/// naturellement.
const double _kButtonClickDurationMs = 35;

/// Constante de temps (secondes) de la décroissance exponentielle du
/// transitoire « tac » du clic de bouton ([_generateClickWaveform]) — très
/// courte pour un claquement sec de switch mécanique plutôt qu'un souffle
/// qui traîne.
const double _kButtonTickDecayTauSeconds = 0.0022;

/// Constante de temps (secondes) de la décroissance du « corps » résonant
/// qui suit le tac du clic de bouton — plus longue, pour évoquer la caisse
/// d'une touche de clavier mécanique qui continue de vibrer brièvement
/// après l'impact.
const double _kButtonKnockDecayTauSeconds = 0.011;

/// Fréquence fondamentale (Hz) du corps résonant du clic de bouton.
const double _kButtonKnockFundamentalFreq = 1100;

/// Fréquence de l'harmonique secondaire (Hz) du clic de bouton, qui donne
/// au corps résonant son timbre plastique plutôt qu'un simple ton pur.
const double _kButtonKnockHarmonicFreq = 2600;

/// Durée du clic de pose de tuile généré, en millisecondes — un peu plus
/// court que le clic de bouton ([_kButtonClickDurationMs]), cohérent avec
/// sa tonalité plus aiguë et son corps résonant plus bref.
const double _kTileClickDurationMs = 28;

/// Constante de temps (secondes) de la décroissance du transitoire « tac »
/// du clic de pose de tuile.
const double _kTileTickDecayTauSeconds = 0.0018;

/// Constante de temps (secondes) de la décroissance du corps résonant du
/// clic de pose de tuile.
const double _kTileKnockDecayTauSeconds = 0.008;

/// Fréquence fondamentale (Hz) du corps résonant du clic de pose de
/// tuile — plus aiguë que celle du clic de bouton
/// ([_kButtonKnockFundamentalFreq]) pour rester distincte à l'oreille.
const double _kTileKnockFundamentalFreq = 1550;

/// Fréquence de l'harmonique secondaire (Hz) du clic de pose de tuile.
const double _kTileKnockHarmonicFreq = 3500;

/// Poids relatif du transitoire « tac » (bruit filtré) dans le mixage
/// final — commun aux deux clics (bouton et pose de tuile).
const double _kTickMix = 0.55;

/// Poids relatif du corps résonant « thock » dans le mixage final — commun
/// aux deux clics (bouton et pose de tuile).
const double _kKnockMix = 0.35;

/// Facteur multiplicatif appliqué au réglage « Bruitages »
/// ([OptionsState.sfxVolume]) pour le clic de bouton — plus discret que les
/// autres bruitages (gain de pièces, pose de tuile) puisqu'il accompagne
/// une simple interaction d'interface plutôt qu'un événement de jeu.
const double _kClickVolumeScale = 0.5;

/// Génère procéduralement un bref clic — sans aucun fichier audio associé —
/// dans la tonalité d'une touche de clavier mécanique, en superposant deux
/// composantes :
///  - un transitoire « tac » : bruit filtré (léger passe-haut par
///    différenciation d'un bruit blanc) à décroissance exponentielle très
///    rapide ([tickDecayTauSeconds]), pour le claquement sec du switch ;
///  - un corps résonant « thock » : deux sinusoïdes amorties
///    ([knockFundamentalFreq] + [knockHarmonicFreq]) à décroissance un peu
///    plus longue ([knockDecayTauSeconds]), pour la caisse qui vibre
///    brièvement après l'impact.
/// Paramétrée pour être réutilisée avec des fréquences différentes : le
/// clic de bouton ([AudioService._clickWaveform]) et le clic de pose de
/// tuile ([AudioService._tilePlacedClickWaveform], plus aigu) partagent ce
/// même générateur. Encodé en PCM 16 bits mono puis enveloppé dans un
/// en-tête WAV minimal par [_pcm16MonoToWav] pour être jouable directement
/// via [BytesSource]. Calculé une seule fois par forme d'onde, à la
/// construction du service.
Uint8List _generateClickWaveform({
  required double durationMs,
  required double tickDecayTauSeconds,
  required double knockDecayTauSeconds,
  required double knockFundamentalFreq,
  required double knockHarmonicFreq,
  required int noiseSeed,
}) {
  final sampleCount = (_kClickSampleRate * durationMs / 1000).round();
  final samples = Int16List(sampleCount);
  // Seed fixe : chaque forme d'onde n'a besoin d'être calculée qu'une seule
  // fois (voir [AudioService._clickWaveform] /
  // [AudioService._tilePlacedClickWaveform]), son contenu n'a donc pas
  // besoin d'être aléatoire d'un lancement de l'app à l'autre.
  final noiseRandom = Random(noiseSeed);
  var prevNoise = 0.0;
  for (var i = 0; i < sampleCount; i++) {
    final t = i / _kClickSampleRate;

    // Transitoire "tac" : bruit blanc légèrement filtré (différenciation
    // simple, effet passe-haut) pour un claquement plus sec qu'un bruit
    // brut, enveloppé d'une décroissance très rapide.
    final rawNoise = noiseRandom.nextDouble() * 2 - 1;
    final filteredNoise = rawNoise - prevNoise * 0.5;
    prevNoise = rawNoise;
    final tick = filteredNoise * exp(-t / tickDecayTauSeconds);

    // Corps résonant "thock" : fondamentale + harmonique, décroissance
    // un peu plus longue que le tac pour simuler la caisse de la touche.
    final knockEnvelope = exp(-t / knockDecayTauSeconds);
    final knock = (sin(2 * pi * knockFundamentalFreq * t) +
            0.4 * sin(2 * pi * knockHarmonicFreq * t)) *
        knockEnvelope;

    final value = tick * _kTickMix + knock * _kKnockMix;
    samples[i] = (value * 32767).round().clamp(-32768, 32767);
  }
  return _pcm16MonoToWav(samples, _kClickSampleRate);
}

/// Enveloppe un buffer PCM 16 bits mono dans un en-tête RIFF/WAV minimal,
/// pour lecture directe en mémoire (aucune écriture sur disque nécessaire).
Uint8List _pcm16MonoToWav(Int16List samples, int sampleRate) {
  final dataBytes = samples.buffer.asUint8List(
    samples.offsetInBytes,
    samples.lengthInBytes,
  );
  final byteRate = sampleRate * 2; // mono, 16 bits => 2 octets/échantillon
  final buffer = BytesBuilder();

  void writeAscii(String s) => buffer.add(s.codeUnits);
  void writeUint32(int v) => buffer.add([
        v & 0xFF,
        (v >> 8) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 24) & 0xFF,
      ]);
  void writeUint16(int v) => buffer.add([v & 0xFF, (v >> 8) & 0xFF]);

  writeAscii('RIFF');
  writeUint32(36 + dataBytes.length);
  writeAscii('WAVE');
  writeAscii('fmt ');
  writeUint32(16); // taille du sous-bloc fmt
  writeUint16(1); // format PCM
  writeUint16(1); // mono
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(2); // block align (octets par trame)
  writeUint16(16); // bits par échantillon
  writeAscii('data');
  writeUint32(dataBytes.length);
  buffer.add(dataBytes);

  return buffer.toBytes();
}

class AudioService {
  AudioService(this._ref) {
    // Contexte audio global : `mixWithOthers` sur iOS et `audioFocus: none`
    // sur Android garantissent que la musique de fond et les bruitages
    // (pool SFX, tile gain) se superposent toujours au lieu de s'interrompre
    // mutuellement.
    //
    // Sur Android, `AndroidAudioFocus.gainTransientMayDuck` (valeur
    // précédente) fait que CHAQUE lecture d'un bruitage demande le focus
    // audio transitoire auprès du système : ça déclenche un événement de
    // perte de focus ("duck") sur le lecteur déjà actif — ici la musique —
    // que la plateforme/le plugin traduit en pause plutôt qu'en simple
    // baisse de volume, sans jamais la relancer une fois le bruitage
    // terminé (aucun listener de reprise de focus n'est câblé). D'où la
    // musique qui se coupe au premier bruitage et ne reprend plus.
    // `none` supprime toute demande de focus : aucun lecteur n'interrompt
    // plus jamais les autres, ils se superposent librement.
    unawaited(AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    ));
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

  /// Lecteur dédié pour [SfxTrack.endGame] — comme [_tileGainPlayer], en
  /// dehors du pool : la fin de partie ne peut survenir qu'une fois par
  /// partie, aucun besoin de chevauchement, mais un lecteur dédié évite
  /// aussi qu'un bruitage du pool encore en cours de lecture (pose de
  /// tuile, pièce gagnée) ne coupe le son de fin de partie en réutilisant
  /// le même lecteur (voir [playEndGame]).
  final AudioPlayer _endGamePlayer = AudioPlayer();

  /// Forme d'onde du clic de bouton, générée une seule fois (voir
  /// [_generateClickWaveform]) puis rejouée à chaque appel de
  /// [playButtonClick] — évite de la recalculer à chaque tap.
  final Uint8List _clickWaveform = _generateClickWaveform(
    durationMs: _kButtonClickDurationMs,
    tickDecayTauSeconds: _kButtonTickDecayTauSeconds,
    knockDecayTauSeconds: _kButtonKnockDecayTauSeconds,
    knockFundamentalFreq: _kButtonKnockFundamentalFreq,
    knockHarmonicFreq: _kButtonKnockHarmonicFreq,
    noiseSeed: 7,
  );

  /// Forme d'onde du clic de pose de tuile, générée une seule fois — mêmes
  /// composantes que [_clickWaveform] (transitoire + corps résonant) mais
  /// avec des fréquences plus aiguës ([_kTileKnockFundamentalFreq] /
  /// [_kTileKnockHarmonicFreq]), pour rester distincte à l'oreille du clic
  /// de bouton. Voir [playTilePlaced].
  final Uint8List _tilePlacedClickWaveform = _generateClickWaveform(
    durationMs: _kTileClickDurationMs,
    tickDecayTauSeconds: _kTileTickDecayTauSeconds,
    knockDecayTauSeconds: _kTileKnockDecayTauSeconds,
    knockFundamentalFreq: _kTileKnockFundamentalFreq,
    knockHarmonicFreq: _kTileKnockHarmonicFreq,
    noiseSeed: 13,
  );

  bool get _musicEnabled => _ref.read(optionsProvider).musicEnabled;
  bool get _sfxEnabled => _ref.read(optionsProvider).sfxEnabled;
  double get _musicVolume => _ref.read(optionsProvider).musicVolume;
  double get _sfxVolume => _ref.read(optionsProvider).sfxVolume;

  /// Joue [track] en boucle, en remplaçant la piste en cours. Ne fait rien
  /// si [track] est déjà la piste active — évite un redémarrage audible en
  /// naviguant entre deux écrans qui partagent la même musique.
  ///
  /// Le volume suit immédiatement le réglage « Musique » et son curseur de
  /// volume courants (silencieux mais lancé si désactivé, pour que
  /// [refreshMusicVolume] puisse rétablir le son instantanément sans avoir
  /// à relancer la piste).
  Future<void> playMusic(MusicTrack track) async {
    if (_currentTrack == track) return;
    _currentTrack = track;
    await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
    await _musicPlayer.play(AssetSource(track.assetPath));
  }

  /// Change de piste comme [playMusic], mais fait d'abord fondre la piste en
  /// cours jusqu'au silence sur [fadeDuration] plutôt que de la couper net —
  /// utilisé pour la sortie de l'accueil vers la partie (voir
  /// `game_screen.dart`), où la coupure instantanée de la musique d'accueil
  /// serait perceptible pendant le wipe hexagonal. Ne fait rien si [track]
  /// est déjà la piste active (même comportement que [playMusic]).
  Future<void> playMusicWithFadeOut(
    MusicTrack track, {
    Duration fadeDuration = _kMusicFadeOutDuration,
  }) async {
    if (_currentTrack == track) return;
    if (_currentTrack != null && _musicEnabled && _musicVolume > 0) {
      final startVolume = _musicVolume;
      final stepDuration = fadeDuration ~/ _kMusicFadeSteps;
      for (var i = _kMusicFadeSteps - 1; i >= 0; i--) {
        await _musicPlayer.setVolume(startVolume * i / _kMusicFadeSteps);
        if (stepDuration > Duration.zero) {
          await Future<void>.delayed(stepDuration);
        }
      }
    }
    await _musicPlayer.stop();
    await playMusic(track);
  }

  /// Coupe/rétablit instantanément le volume de la musique en cours selon
  /// le réglage « Musique » et son curseur de volume courants — à appeler
  /// juste après bascule du réglage ou déplacement du curseur (voir
  /// `settings_screen.dart`). Ne relance pas la piste et ne perd pas la
  /// position de lecture.
  Future<void> refreshMusicVolume() async {
    await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
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
    if (!_sfxEnabled) return;
    final player = _sfxPool[_sfxCursor];
    _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
    final pitch = 1.0 + (_random.nextDouble() * 2 - 1) * _kPitchVariance;
    await player.stop();
    await player.setVolume(_sfxVolume);
    await player.setPlaybackRate(pitch);
    await player.play(AssetSource(sfx.assetPath));
  }

  /// Joue `coin.mp3` une fois par pièce gagnée (plafonné à
  /// [_kMaxCoinSfxRepeats]), légèrement échelonnées pour rester perceptibles
  /// individuellement — chaque occurrence a sa propre variation de hauteur.
  /// N'attend la fin d'aucune lecture précédente : les sons peuvent se
  /// chevaucher.
  Future<void> playCoinsGained(int count) async {
    if (!_sfxEnabled) return;
    final n = count.clamp(0, _kMaxCoinSfxRepeats);
    for (var i = 0; i < n; i++) {
      unawaited(_playSfx(SfxTrack.coin));
      if (i < n - 1) {
        await Future<void>.delayed(_kCoinSfxGap);
      }
    }
  }

  /// Arrivée d'une tuile posée à sa position finale (fin du rebond). Comme
  /// [playButtonClick], il s'agit d'un clic généré procéduralement
  /// ([_tilePlacedClickWaveform]) plutôt que d'un fichier audio — même
  /// principe (transitoire + corps résonant) mais dans une tonalité plus
  /// aiguë, pour rester distinct du clic de bouton d'interface. Pioche dans
  /// le même pool tournant que [_playSfx] pour laisser plusieurs poses se
  /// chevaucher sans se couper, avec la même variation de hauteur.
  Future<void> playTilePlaced() async {
    if (!_sfxEnabled) return;
    final player = _sfxPool[_sfxCursor];
    _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
    final pitch = 1.0 + (_random.nextDouble() * 2 - 1) * _kPitchVariance;
    await player.stop();
    await player.setVolume(_sfxVolume);
    await player.setPlaybackRate(pitch);
    await player.play(BytesSource(_tilePlacedClickWaveform));
  }

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
    if (!_sfxEnabled) return;
    await _tileGainPlayer.stop();
    await _tileGainPlayer.setVolume(_sfxVolume);
    await _tileGainPlayer.play(AssetSource(SfxTrack.tileGain.assetPath));
  }

  /// Joue `end_game.mp3` une fois, au moment où l'écran de résultats
  /// apparaît (voir `results_modal.dart`, déclenché sur la transition de
  /// [isGameOverProvider] vers `true`). Lecteur dédié ([_endGamePlayer])
  /// plutôt que le pool tournant : pas de besoin de chevauchement (un seul
  /// déclenchement par partie) et ça évite qu'un bruitage encore actif du
  /// pool ne coupe ce son en réutilisant le même lecteur.
  Future<void> playEndGame() async {
    if (!_sfxEnabled) return;
    await _endGamePlayer.stop();
    await _endGamePlayer.setVolume(_sfxVolume);
    await _endGamePlayer.play(AssetSource(SfxTrack.endGame.assetPath));
  }

  /// Joue `undo.mp3` à chaque annulation du dernier placement (voir
  /// [undoPlacement] dans `undo_placement.dart`, déclenché aussi bien par
  /// le bouton Annuler que par l'annulation automatique du tutoriel).
  /// Pioche dans le pool tournant comme [playCoinsGained] / [playTilePlaced]
  /// plutôt qu'un lecteur dédié : une action ponctuelle déclenchée par
  /// l'utilisateur, sans besoin de couper un déclenchement précédent qui
  /// n'aurait pas eu le temps de se terminer.
  Future<void> playUndo() => _playSfx(SfxTrack.undo);

  /// Joue le clic de bouton généré procéduralement ([_clickWaveform], voir
  /// [_generateClickWaveform]) — aucun fichier audio associé. Pioche dans le
  /// même pool tournant que [_playSfx] (même hauteur légèrement randomisée)
  /// pour se superposer librement à la musique et aux autres bruitages, avec
  /// un volume atténué ([_kClickVolumeScale]) pour rester discret.
  ///
  /// À appeler via [buttonTapFeedback] (voir `haptics_service.dart`) plutôt
  /// que directement, sur tout bouton qui ne déclenche pas déjà son propre
  /// bruitage dédié.
  Future<void> playButtonClick() async {
    if (!_sfxEnabled) return;
    final player = _sfxPool[_sfxCursor];
    _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
    final pitch = 1.0 + (_random.nextDouble() * 2 - 1) * _kPitchVariance;
    await player.stop();
    await player.setVolume(_sfxVolume * _kClickVolumeScale);
    await player.setPlaybackRate(pitch);
    await player.play(BytesSource(_clickWaveform));
  }

  void _dispose() {
    _musicPlayer.dispose();
    for (final p in _sfxPool) {
      p.dispose();
    }
    _tileGainPlayer.dispose();
    _endGamePlayer.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(ref);
  ref.onDispose(service._dispose);
  return service;
});
