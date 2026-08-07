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
/// transition de [isGameOverProvider] vers `true`. Cette transition
/// elle-même n'est déclenchée qu'une fois les `coin.mp3` de la toute
/// dernière pose terminés (voir [AudioService.coinSoundsFinishDelay],
/// utilisé dans `placement_commit.dart`, `_checkGameOver`) : popup et son
/// de fin de partie apparaissent donc ensemble plutôt que la popup
/// immédiatement suivie du son en décalé.
///
/// [playUndo] (undo.mp3) pioche dans le pool tournant comme
/// [playCoinsGained] / [playTilePlaced] — déclenché depuis [undoPlacement]
/// (voir `undo_placement.dart`) à chaque annulation du dernier placement.
///
/// Clic de bouton ([playButtonClick], button_click.mp3) : pioche dans le
/// pool tournant comme les autres bruitages ponctuels, avec un volume
/// atténué ([_kButtonClickVolumeScale]) pour rester discret puisqu'il
/// accompagne une simple interaction d'interface plutôt qu'un événement de
/// jeu. Pensé pour être déclenché par [buttonTapFeedback]
/// (voir `haptics_service.dart`) sur tout bouton de l'application qui ne
/// possède pas déjà son propre bruitage dédié.
///
/// Pose de tuile ([playTilePlaced], tile_placed.mp3) : également jouée
/// depuis le pool tournant, avec son propre volume dédié
/// ([_kTilePlacedVolumeScale]) plutôt que celui du clic de bouton, pour
/// rester distincte à l'oreille et cohérente avec l'action de jeu qu'elle
/// accompagne.
///
/// Rotation de tuile ([playTileRotated], tile_rotate.mp3) : pioche elle
/// aussi dans le pool tournant, avec son propre volume dédié
/// ([_kRotationClickVolumeScale]) — un cran de rotation n'est qu'une
/// micro-confirmation répétée jusqu'à 6 fois par tour complet. Déclenché
/// depuis [HexBoardGame._handleRotation] (`hex_board_game.dart`), une fois
/// par cran de 60° franchi — même granularité que le retour haptique
/// [HapticsService.tileRotated].
///
/// Récompense de quête ([playQuestRewardClaimed], quest_reward.mp3) :
/// pioche elle aussi dans le pool tournant, comme [playUndo] /
/// [playCoinsGained] — plusieurs réclamations rapprochées (quêtes
/// permanentes et/ou quotidiennes) doivent se superposer plutôt que se
/// couper l'une l'autre, chacune restant audible individuellement. Un
/// lecteur dédié a été utilisé un temps pour ce bruitage, mais a été
/// abandonné : au-delà de ne pas superposer les lectures (plus voulu), il
/// exposait aussi un bug Android connu (voir le commentaire du
/// constructeur sur `ReleaseMode.stop`) où le lecteur dédié pouvait
/// occasionnellement refuser de rejouer après une première lecture menée à
/// son terme naturel — c'est ce qui causait le son manquant à la toute
/// première quête réclamée. Déclenché depuis `quest_card.dart`
/// (`QuestCardState._handleClaim`) et `daily_quest_card.dart`
/// (`DailyQuestCardState._handleClaim`), aux côtés du retour haptique
/// [HapticsService.questRewardClaimed].
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

/// Bruitages ponctuels disponibles, tous basés sur un fichier audio.
enum SfxTrack {
  coin('audio/coin.mp3'),
  tileGain('audio/tile_gain.mp3'),
  endGame('audio/end_game.mp3'),
  undo('audio/undo.mp3'),
  tilePlaced('audio/tile_placed.mp3'),
  tileRotate('audio/tile_rotate.mp3'),
  buttonClick('audio/button_click.mp3'),
  questReward('audio/quest_reward.mp3');

  const SfxTrack(this.assetPath);

  /// Chemin relatif au dossier `assets/` (voir [AssetSource]).
  final String assetPath;
}

/// Variation de hauteur appliquée à chaque bruitage : ± cette valeur autour
/// de 1.0 (vitesse/hauteur normale), tirée aléatoirement à chaque lecture.
/// Réduite de moitié (0.08 → 0.04) : l'amplitude précédente rendait la
/// variation trop perceptible, en particulier sur des sons brefs et
/// rapprochés comme le clic de rotation (jusqu'à 6 par tour complet).
const double _kPitchVariance = 0.04;

/// Nombre de lecteurs dans le pool de bruitages — permet à plusieurs sons de
/// se superposer (ex. plusieurs `coin.mp3` d'affilée) sans s'interrompre
/// mutuellement.
const int _kSfxPoolSize = 6;

/// Nombre maximal de `coin.mp3` joués pour un même placement — au-delà,
/// un très gros gain (améliorations cumulées) déclencherait une rafale
/// sonore de plusieurs secondes. Même plafond que
/// [HapticsService.playReward] pour rester cohérent avec le retour haptique.
/// Partagé avec `bonus_animations.dart` (estimation de la fin du bruitage).
const int kMaxCoinSfxRepeats = 6;

/// Délai entre deux `coin.mp3` d'un même gain, pour qu'ils restent
/// perceptibles comme des impulsions distinctes plutôt qu'un unique son.
/// Partagé avec `bonus_animations.dart` (estimation de la fin du bruitage).
const Duration kCoinSfxGap = Duration(milliseconds: 250);

/// Délai minimal entre deux lectures de `tile_gain.mp3` (voir
/// [AudioService.playTileGained]) — un gain multi-tuiles peut déclencher
/// [AudioService.playTileGained] plus vite que ça (impacts d'icônes
/// rapprochés), auquel cas les lectures excédentaires sont mises en
/// attente plutôt que de couper net le son précédent trop tôt.
const Duration _kTileGainSfxGap = Duration(milliseconds: 250);

/// Durée de vol d'une pièce vers son compteur avant l'impact — valeur
/// alignée sur [kCoinFlyDurationSec] (`bonus_animations.dart`, source
/// canonique utilisée par [CoinComponent]) — point de départ du calcul de
/// [_coinSoundsFinishDelay].
const Duration _kCoinFlyDuration = Duration(milliseconds: 600);

/// Durée de lecture d'un `coin.mp3` (mesurée ~0.696s, arrondie à 0.7s par
/// prudence) — sert à estimer quand la dernière pièce d'un gain a fini de
/// sonner. Partagé avec `bonus_animations.dart` (estimation de la fin du
/// bruitage).
const Duration kCoinSfxClipDuration = Duration(milliseconds: 700);

/// Durée par défaut du fondu de sortie appliqué par [AudioService.playMusicWithFadeOut]
/// avant de basculer sur la nouvelle piste — assez bref pour rester discret
/// pendant une transition d'écran, assez long pour éviter une coupure nette.
const Duration _kMusicFadeOutDuration = Duration(milliseconds: 500);

/// Nombre de paliers de volume utilisés pour le fondu de
/// [AudioService.playMusicWithFadeOut] — un compromis entre fluidité perçue
/// et nombre d'appels à [AudioPlayer.setVolume].
const int _kMusicFadeSteps = 12;

/// Facteur multiplicatif appliqué au réglage « Bruitages »
/// ([OptionsState.sfxVolume]) pour le clic de bouton — plus discret que les
/// autres bruitages (gain de pièces, pose de tuile) puisqu'il accompagne
/// une simple interaction d'interface plutôt qu'un événement de jeu.
const double _kButtonClickVolumeScale = 0.36;

/// Atténuation appliquée au son de pose de tuile ([AudioService.playTilePlaced])
/// par rapport au réglage « Bruitages » — 10 % plus discret que le volume
/// nominal.
const double _kTilePlacedVolumeScale = 0.9;

/// Facteur multiplicatif appliqué au réglage « Bruitages »
/// ([OptionsState.sfxVolume]) pour le clic de rotation.
const double _kRotationClickVolumeScale = 0.63;

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
    // Lecteurs dédiés (tileGain, endGame, questReward) : ReleaseMode.stop
    // plutôt que le défaut ReleaseMode.release. En mode `release`, le
    // lecteur libère ses ressources natives dès que le son se termine tout
    // seul (sans stop() explicite) ; un stop()+play() ultérieur sur ce même
    // lecteur peut alors échouer silencieusement sur Android (ré-préparation
    // native ratée), ce qui reproduisait un bug où le son ne rejouait plus
    // après une première lecture menée jusqu'à sa fin naturelle — typiquement
    // `quest_reward.mp3` en réclamant une récompense après avoir laissé la
    // précédente se terminer. `stop` garde les ressources allouées et se
    // contente de réinitialiser la position, ce qui rend stop()+play()
    // fiable dans tous les cas.
    unawaited(_tileGainPlayer.setReleaseMode(ReleaseMode.stop));
    unawaited(_endGamePlayer.setReleaseMode(ReleaseMode.stop));
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

  /// Prochain instant auquel [playTileGained] est autorisé à démarrer une
  /// lecture — avance de [_kTileGainSfxGap] à chaque appel (calculé de façon
  /// synchrone, avant tout `await`, pour que des appels concurrents ne lisent
  /// pas la même valeur et se programment correctement les uns après les
  /// autres) plutôt que d'être limité à l'instant présent.
  DateTime? _nextTileGainAllowedAt;

  /// Lecteur dédié pour [SfxTrack.endGame] — comme [_tileGainPlayer], en
  /// dehors du pool : la fin de partie ne peut survenir qu'une fois par
  /// partie, aucun besoin de chevauchement, mais un lecteur dédié évite
  /// aussi qu'un bruitage du pool encore en cours de lecture (pose de
  /// tuile, pièce gagnée) ne coupe le son de fin de partie en réutilisant
  /// le même lecteur (voir [playEndGame]).
  final AudioPlayer _endGamePlayer = AudioPlayer();

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
  Future<void> pauseMusicForBackground() => _pauseMusicPlayer();

  /// Reprend la musique de fond interrompue par [pauseMusicForBackground] au
  /// retour au premier plan ([AppLifecycleState.resumed]). Ne fait rien si
  /// aucune piste n'a jamais été lancée.
  Future<void> resumeMusicFromBackground() => _resumeMusicPlayer();

  /// Met en pause la musique de fond (accueil ou partie) pendant qu'une pub
  /// plein écran est à l'affichage — rewarded (voir `home_screen.dart`,
  /// `_RewardedAdButton`) ou interstitielle (voir `game_screen.dart`,
  /// déclenchement toutes les [kAdInterstitialFrequency] tuiles). Même
  /// mécanique que [pauseMusicForBackground] : conserve la position de
  /// lecture pour une reprise transparente via [resumeMusicFromAd].
  Future<void> pauseMusicForAd() => _pauseMusicPlayer();

  /// Reprend la musique interrompue par [pauseMusicForAd], une fois la pub
  /// fermée (visionnage complet, fermeture anticipée, ou échec
  /// d'affichage — toujours appelé pour ne jamais laisser la musique
  /// coupée).
  Future<void> resumeMusicFromAd() => _resumeMusicPlayer();

  Future<void> _pauseMusicPlayer() async {
    await _musicPlayer.pause();
  }

  Future<void> _resumeMusicPlayer() async {
    if (_currentTrack == null) return;
    await _musicPlayer.resume();
  }

  /// Joue [sfx] avec une hauteur légèrement randomisée, sur un lecteur pris
  /// dans le pool tournant — n'attend pas la fin d'une éventuelle lecture
  /// précédente sur ce même lecteur (elle est simplement coupée), et
  /// n'interrompt jamais les autres lecteurs du pool. [volumeScale] permet
  /// d'atténuer (ou non) certains bruitages par rapport au réglage
  /// « Bruitages » courant — voir [_kButtonClickVolumeScale],
  /// [_kTilePlacedVolumeScale], [_kRotationClickVolumeScale].
  Future<void> _playSfx(SfxTrack sfx, {double volumeScale = 1.0}) async {
    if (!_sfxEnabled) return;
    final player = _sfxPool[_sfxCursor];
    _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
    final pitch = 1.0 + (_random.nextDouble() * 2 - 1) * _kPitchVariance;
    await player.stop();
    await player.setVolume(_sfxVolume * volumeScale);
    await player.setPlaybackRate(pitch);
    await player.play(AssetSource(sfx.assetPath));
  }

  /// Joue `coin.mp3` une fois par pièce gagnée (plafonné à
  /// [kMaxCoinSfxRepeats]), légèrement échelonnées pour rester perceptibles
  /// individuellement — chaque occurrence a sa propre variation de hauteur.
  /// N'attend la fin d'aucune lecture précédente : les sons peuvent se
  /// chevaucher.
  Future<void> playCoinsGained(int count) async {
    if (!_sfxEnabled) return;
    final n = count.clamp(0, kMaxCoinSfxRepeats);
    for (var i = 0; i < n; i++) {
      unawaited(_playSfx(SfxTrack.coin));
      if (i < n - 1) {
        await Future<void>.delayed(kCoinSfxGap);
      }
    }
  }

  /// Arrivée d'une tuile posée à sa position finale (fin du rebond).
  /// `tile_placed.mp3`, avec son propre volume dédié
  /// ([_kTilePlacedVolumeScale]) plutôt que celui du clic de bouton, pour
  /// rester distinct à l'oreille et cohérent avec l'action de jeu qu'il
  /// accompagne. Pioche dans le pool tournant comme [_playSfx] pour
  /// laisser plusieurs poses se chevaucher sans se couper, avec la même
  /// variation de hauteur.
  Future<void> playTilePlaced() =>
      _playSfx(SfxTrack.tilePlaced, volumeScale: _kTilePlacedVolumeScale);

  /// Joue `tile_gain.mp3` à chaque tuile bonus qui arrive sur la pile HUD
  /// (voir `game_screen.dart`, `onBonusImpact` — un appel par icône de
  /// tuile arrivée, échelonné dans le temps pour un gain multi-tuiles).
  ///
  /// Contrairement à [_playSfx], qui pioche dans le pool pour laisser les
  /// sons se chevaucher, cette méthode réutilise toujours le même lecteur
  /// dédié ([_tileGainPlayer]) : si le son de la tuile précédente n'est pas
  /// terminé quand une nouvelle tuile arrive, il est coupé net avant de
  /// démarrer le nouveau, plutôt que superposé.
  ///
  /// Impose aussi un délai minimal de [_kTileGainSfxGap] entre deux lectures
  /// ([_nextTileGainAllowedAt]) : pour un gain multi-tuiles où les icônes
  /// arrivent plus vite que ça, les appels excédentaires patientent au lieu
  /// de couper le son précédent trop tôt.
  Future<void> playTileGained() async {
    if (!_sfxEnabled) return;
    final now = DateTime.now();
    final scheduledAt =
        _nextTileGainAllowedAt != null && _nextTileGainAllowedAt!.isAfter(now)
            ? _nextTileGainAllowedAt!
            : now;
    _nextTileGainAllowedAt = scheduledAt.add(_kTileGainSfxGap);
    final wait = scheduledAt.difference(now);
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
    if (!_sfxEnabled) return;
    // stop() défensif : ne doit jamais empêcher le play() qui suit, même si
    // l'état natif du lecteur est inattendu (ex. déjà relâché après une
    // complétion naturelle sur un appareil où ReleaseMode.stop ne serait pas
    // encore effectif — voir le commentaire dans le constructeur et le même
    // correctif appliqué à [playQuestRewardClaimed]). Sans ce try/catch, une
    // exception ici n'était jamais rattrapée (appel fait via `unawaited`
    // côté appelant) et empêchait silencieusement TOUTE lecture future de
    // `tile_gain.mp3` pour le reste de la session.
    try {
      await _tileGainPlayer.stop();
    } catch (_) {}
    // seek(0) explicite, dans le même try/catch défensif que le stop()
    // ci-dessus : sur Android, stop() seul ne réinitialise pas toujours la
    // position native du lecteur (bug connu du plugin audioplayers avec
    // ReleaseMode.stop) — sans ce seek, chaque nouvelle lecture repart de la
    // position où la précédente s'est arrêtée plutôt que du début, d'où des
    // lectures de plus en plus courtes à chaque déclenchement rapproché.
    try {
      await _tileGainPlayer.seek(Duration.zero);
    } catch (_) {}
    await _tileGainPlayer.setVolume(_sfxVolume);
    await _tileGainPlayer.play(AssetSource(SfxTrack.tileGain.assetPath));
  }

  /// Joue `end_game.mp3` une fois, au moment où l'écran de résultats
  /// apparaît (voir `results_modal.dart`, déclenché sur la transition de
  /// [isGameOverProvider] vers `true`). Lecteur dédié ([_endGamePlayer])
  /// plutôt que le pool tournant : pas de besoin de chevauchement (un seul
  /// déclenchement par partie) et ça évite qu'un bruitage encore actif du
  /// pool ne coupe ce son en réutilisant le même lecteur.
  ///
  /// [isGameOverProvider] n'est lui-même positionné à `true` qu'une fois
  /// les `coin.mp3` de la toute dernière pose terminés (voir
  /// [coinSoundsFinishDelay], utilisé côté appelant dans
  /// `placement_commit.dart`, `_checkGameOver`) : popup de résultats et
  /// bruitage de fin de partie apparaissent donc déjà ensemble, sans qu'un
  /// délai supplémentaire soit nécessaire ici.
  Future<void> playEndGame() async {
    if (!_sfxEnabled) return;
    // stop() et seek(0) défensifs, dans le même try/catch que
    // [playTileGained] : sur certains appareils, le plugin `audioplayers`
    // peut laisser le lecteur natif dans un état où `stop()`/`seek()` ne se
    // résolvent jamais, ce qui déclenche côté plugin un `TimeoutException`
    // après 30s (voir crash Crashlytics `AudioPlayer.seek` /
    // `AudioService.playEndGame`). Sans ce try/catch, cette exception
    // n'était jamais rattrapée et faisait planter l'app plutôt que de
    // simplement empêcher ce bruitage ponctuel.
    try {
      await _endGamePlayer.stop();
    } catch (_) {}
    // seek(0) explicite — voir le commentaire équivalent dans
    // [playTileGained] : sans ça, une lecture répétée sur le même lecteur
    // dédié peut repartir de la position de l'arrêt précédent au lieu du
    // début du fichier.
    try {
      await _endGamePlayer.seek(Duration.zero);
    } catch (_) {}
    await _endGamePlayer.setVolume(_sfxVolume);
    await _endGamePlayer.play(AssetSource(SfxTrack.endGame.assetPath));
  }

  /// Joue `quest_reward.mp3` au moment où le joueur réclame la récompense
  /// d'une quête terminée — quête permanente (voir `quest_card.dart`,
  /// `QuestCardState._handleClaim`) ou quotidienne (voir
  /// `daily_quest_card.dart`, `DailyQuestCardState._handleClaim`),
  /// déclenché aux côtés du retour haptique
  /// [HapticsService.questRewardClaimed]). Pioche dans le pool tournant
  /// comme [_playSfx] (même hauteur légèrement randomisée) : se superpose
  /// librement à la musique (contexte audio global, voir le constructeur)
  /// ainsi qu'à d'éventuelles autres lectures de `quest_reward.mp3` si
  /// plusieurs récompenses sont réclamées coup sur coup, plutôt que de
  /// couper net la précédente.
  Future<void> playQuestRewardClaimed() => _playSfx(SfxTrack.questReward);

  /// Estime le délai à partir duquel le dernier `coin.mp3` d'un gain de
  /// [coinCount] pièces aura fini de sonner : vol de la pièce jusqu'au
  /// compteur ([_kCoinFlyDuration]) puis lectures échelonnées
  /// ([kCoinSfxGap] entre chacune, plafonnées à [kMaxCoinSfxRepeats])
  /// jusqu'à la fin de la dernière ([kCoinSfxClipDuration]). Retourne
  /// [Duration.zero] si [coinCount] est nul (aucune pièce, donc aucun
  /// bruitage à attendre).
  ///
  /// Statique et publique pour être réutilisée par
  /// `placement_commit.dart` (`_checkGameOver`) : la popup de résultats
  /// (voir [isGameOverProvider]) n'est révélée qu'une fois ce délai
  /// écoulé, pour apparaître exactement en même temps que [playEndGame].
  static Duration coinSoundsFinishDelay(int coinCount) {
    if (coinCount <= 0) return Duration.zero;
    final n = coinCount.clamp(0, kMaxCoinSfxRepeats);
    return _kCoinFlyDuration + kCoinSfxGap * (n - 1) + kCoinSfxClipDuration;
  }

  /// Joue `undo.mp3` à chaque annulation du dernier placement (voir
  /// [undoPlacement] dans `undo_placement.dart`, déclenché aussi bien par
  /// le bouton Annuler que par l'annulation automatique du tutoriel).
  /// Pioche dans le pool tournant comme [playCoinsGained] / [playTilePlaced]
  /// plutôt qu'un lecteur dédié : une action ponctuelle déclenchée par
  /// l'utilisateur, sans besoin de couper un déclenchement précédent qui
  /// n'aurait pas eu le temps de se terminer.
  Future<void> playUndo() => _playSfx(SfxTrack.undo);

  /// Joue `button_click.mp3`. Pioche dans le même pool tournant que
  /// [_playSfx] (même hauteur légèrement randomisée) pour se superposer
  /// librement à la musique et aux autres bruitages, avec un volume
  /// atténué ([_kButtonClickVolumeScale]) pour rester discret.
  ///
  /// À appeler via [buttonTapFeedback] (voir `haptics_service.dart`) plutôt
  /// que directement, sur tout bouton qui ne déclenche pas déjà son propre
  /// bruitage dédié.
  Future<void> playButtonClick() =>
      _playSfx(SfxTrack.buttonClick, volumeScale: _kButtonClickVolumeScale);

  /// Joue `tile_rotate.mp3`. Pioche dans le même pool tournant que
  /// [_playSfx]/[playButtonClick] (même hauteur légèrement randomisée),
  /// avec un volume ([_kRotationClickVolumeScale]) en réalité plus élevé
  /// que celui du clic de bouton : un cran de rotation isolé est un
  /// événement plus furtif à l'oreille qu'un tap de bouton, il lui faut
  /// donc plus de présence pour rester perceptible même en rafale (un
  /// clic par cran de 60°, jusqu'à 6 par tour complet).
  ///
  /// À appeler depuis [HexBoardGame._handleRotation] (`hex_board_game.dart`)
  /// à chaque cran de rotation franchi — même déclencheur que
  /// [HapticsService.tileRotated].
  Future<void> playTileRotated() =>
      _playSfx(SfxTrack.tileRotate, volumeScale: _kRotationClickVolumeScale);

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
