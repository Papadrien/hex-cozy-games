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
///
/// Ambiance du bateau de pêche ([playBoatAmbient]/[stopBoatAmbient],
/// boat_ambient.mp3) : lecteur dédié en boucle ([_boatAmbientPlayer]),
/// démarré/arrêté en fondu (voir [_kBoatAmbientFadeDuration]) plutôt que
/// net, depuis les hooks de cycle de vie de [FishingBoatComponent]
/// (`onLoad`/`onRemove`, `fishing_boat_component.dart`) — présent à
/// l'écran seulement tant que ce composant décoratif l'est.
library;

import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
  questReward('audio/quest_reward.mp3'),
  purchaseSuccess('audio/purchase_success.mp3');

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

/// Chemin (relatif à `assets/`) du son d'ambiance du bateau de pêche — voir
/// [AudioService.playBoatAmbient]/[AudioService.stopBoatAmbient].
const String _kBoatAmbientAssetPath = 'audio/boat_ambient.mp3';

/// Durée des fondus d'entrée/sortie du son d'ambiance du bateau de pêche —
/// même ordre de grandeur que [_kMusicFadeOutDuration], suffisamment long
/// pour que l'apparition/disparition reste discrète plutôt qu'une coupure
/// nette, sans pour autant traîner sur une bonne partie du trajet du bateau
/// (~2.5 à 7s par segment, voir `fishing_boat_component.dart`).
const Duration _kBoatAmbientFadeDuration = Duration(milliseconds: 1200);

/// Nombre de paliers de volume utilisés pour les fondus du son d'ambiance
/// du bateau de pêche — même principe que [_kMusicFadeSteps].
const int _kBoatAmbientFadeSteps = 12;

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

/// Atténuation appliquée au son de gain de pièce ([AudioService.playCoinsGained])
/// par rapport au réglage « Bruitages » — 36 % plus discret que le volume
/// nominal.
const double _kCoinVolumeScale = 0.64;

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
    //
    // IMPORTANT — corrige un bug confirmé en logcat : cet appel était
    // auparavant fait en `unawaited`, sans aucune garantie qu'il ait fini
    // d'être appliqué côté natif avant le tout premier `play()` d'un
    // lecteur. Dans le cas observé, le bateau de pêche jouait ~2s après le
    // lancement de l'app, en pleine concurrence avec l'initialisation du
    // SDK Google Ads — sa toute première lecture partait donc avec le
    // comportement de focus AUDIO PAR DÉFAUT d'Android (pas encore
    // `none`), ce qui lui faisait enregistrer un vrai
    // `AudioFocusChangeListener` natif (`ModernFocusManager` côté plugin
    // `audioplayers`). Quand le SDK Ads réclamait ensuite le focus audio
    // pour charger sa WebView publicitaire, Android envoyait à ce
    // listener un `AUDIOFOCUS_LOSS` (`onAudioFocusChange(-1)`, perte
    // permanente) — que `ModernFocusManager` traduit en mise en pause
    // native du lecteur. Le fondu d'entrée continuait bien côté Flutter
    // (le volume logique montait normalement jusqu'à sa cible), mais le
    // lecteur natif sous-jacent était déjà coupé : silence total malgré
    // des logs indiquant un succès à chaque étape. Le futur est maintenant
    // conservé ([_audioContextReady]) et chaque méthode de lecture
    // l'attend avant son tout premier appel natif, pour qu'aucune lecture
    // ne puisse plus jamais partir avec le focus audio par défaut
    // d'Android.
    _audioContextReady = AudioPlayer.global
        .setAudioContext(
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
    )
        .catchError((Object e, StackTrace stack) {
      debugPrint('[AudioService] setAudioContext() a échoué : $e\n$stack');
    });
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
    // Boucle tant que le bateau de pêche est présent — voir
    // [playBoatAmbient]/[stopBoatAmbient].
    unawaited(_boatAmbientPlayer.setReleaseMode(ReleaseMode.loop));
  }

  /// Résolu une fois le contexte audio global (voir constructeur) réellement
  /// appliqué côté natif — ou après l'échec de cette tentative, pour ne
  /// jamais bloquer indéfiniment un appelant. Chaque méthode de lecture
  /// (musique, bruitages, bateau) l'attend avant son tout premier appel
  /// natif de la partie, pour ne plus jamais risquer de jouer un son avec
  /// le focus audio par défaut d'Android le temps que ce réglage se
  /// propage — voir le commentaire détaillé dans le constructeur.
  late final Future<void> _audioContextReady;

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

  /// Lecteur dédié pour le son d'ambiance du bateau de pêche
  /// ([FishingBoatComponent]) — en boucle ([ReleaseMode.loop]) tant que le
  /// composant est présent à l'écran, avec fondu d'entrée
  /// ([playBoatAmbient]) et de sortie ([stopBoatAmbient]) plutôt que des
  /// coupures nettes. En dehors du pool comme [_tileGainPlayer]/
  /// [_endGamePlayer] : c'est le seul lecteur SFX voué à jouer en continu
  /// sur plusieurs secondes, il ne doit pas pouvoir être réquisitionné par
  /// un bruitage ponctuel entre-temps.
  final AudioPlayer _boatAmbientPlayer = AudioPlayer();

  /// Incrémenté à chaque appel de [playBoatAmbient]/[stopBoatAmbient] —
  /// permet à un fondu de sortie déclenché pendant qu'un fondu d'entrée est
  /// encore en cours (ou vice-versa) d'invalider proprement la boucle de
  /// l'appel précédent plutôt que de laisser les deux se marcher dessus.
  int _boatAmbientFadeGeneration = 0;

  /// Passe à `true` dès que [_boatAmbientPlayer] a effectivement commencé à
  /// jouer au moins une fois. Voir [playBoatAmbient] : sur le tout premier
  /// appel, le lecteur natif vient d'être créé et n'a jamais été préparé —
  /// lui demander `stop()`/`seek()` avant même un premier `play()` est ce
  /// qui provoquait le blocage observé en logcat (l'`await` ne se résolvait
  /// jamais, empêchant d'atteindre `play()`). Ces deux appels défensifs ne
  /// sont donc faits qu'à partir du second déclenchement du bateau, quand
  /// le lecteur a réellement un état à réinitialiser.
  bool _boatAmbientHasPlayedOnce = false;

  /// `true` when the boat player has an audio source prepared natively.
  ///
  /// The previous implementation "primed" the player by actually calling
  /// `play()` at volume 0 during SplashScreen. That still opened a real
  /// Android playback session and could race with the global audio-context
  /// setup / Ads initialization. Preparing the source with `setSource()` and
  /// starting it later with `resume()` avoids that race while still warming
  /// the native player.
  bool _boatAmbientPrepared = false;

  /// Timeout appliqué à chaque appel natif individuel dans
  /// [playBoatAmbient]/[stopBoatAmbient] : sur certains appareils, le
  /// plugin `audioplayers` peut laisser un `await` ne jamais se résoudre
  /// (bug déjà observé en logcat — voir doc de [playBoatAmbient]). Un
  /// `try/catch` seul ne protège pas contre un `Future` qui ne se termine
  /// jamais ; il faut un timeout explicite pour être certain de toujours
  /// atteindre le `play()` (ou la fin du fondu de sortie) en un temps borné,
  /// plutôt que de rester bloqué indéfiniment sur un appel préalable.
  static const Duration _kBoatAmbientCallTimeout = Duration(seconds: 2);

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
    // Voir [_audioContextReady] : garantit que `audioFocus: none` est
    // appliqué avant la toute première lecture de la partie (typiquement
    // la musique d'accueil, jouée dès l'écran de démarrage).
    await _audioContextReady;
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
    // Voir [_audioContextReady].
    await _audioContextReady;
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
      unawaited(_playSfx(SfxTrack.coin, volumeScale: _kCoinVolumeScale));
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
    // Voir [_audioContextReady] : la toute première tuile posée en partie
    // est justement le genre de lecture très précoce exposée à cette
    // course.
    await _audioContextReady;
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
    // Voir [_audioContextReady].
    await _audioContextReady;
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

  /// Démarre `boat_ambient.mp3` en boucle avec un fondu d'entrée sur
  /// [_kBoatAmbientFadeDuration], appelé depuis [FishingBoatComponent.onLoad]
  /// dès l'apparition du bateau de pêche décoratif (encore hors champ à ce
  /// stade). Ne fait rien si les bruitages sont désactivés. Invalide tout
  /// fondu de sortie ([stopBoatAmbient]) encore en cours (voir
  /// [_boatAmbientFadeGeneration]) — ne devrait pas arriver en usage normal
  /// (un seul bateau à la fois par partie), mais reste robuste si jamais.
  Future<void> playBoatAmbient() async {
    // `debugPrint` volontaire (voir aussi celui plus bas, sur l'échec de
    // `play()`) : l'app installe un handler global
    // (`PlatformDispatcher.instance.onError`, voir `analytics_service.dart`)
    // qui capture toute exception non rattrapée d'un Future non-awaité (ce
    // qui est le cas ici, appelé via `unawaited` depuis
    // `FishingBoatComponent.onLoad`) et l'envoie à Crashlytics — SANS
    // jamais l'imprimer en console/logcat. Sans ce `debugPrint` explicite,
    // un échec de lecture natif de `boat_ambient.mp3` serait donc
    // totalement invisible en local (adb logcat / `flutter logs`), y
    // compris en build debug : seul le dashboard Crashlytics (avec un
    // délai de remontée) en garderait la trace.
    debugPrint(
      '[BoatAmbient] playBoatAmbient() appelé — sfxEnabled=$_sfxEnabled '
      'sfxVolume=$_sfxVolume',
    );
    if (!_sfxEnabled) {
      debugPrint('[BoatAmbient] bruitages désactivés — abandon.');
      return;
    }
    // Attend que le contexte audio natif (audioFocus: none, voir
    // constructeur) soit réellement appliqué avant tout `play()` — c'est ce
    // qui manquait et causait le silence confirmé en logcat (voir le
    // commentaire détaillé dans le constructeur de [AudioService]).
    await _audioContextReady;
    final generation = ++_boatAmbientFadeGeneration;
    // stop() et seek(0) défensifs, mais seulement à partir du second
    // déclenchement (voir [_boatAmbientHasPlayedOnce]) : sur le tout
    // premier appel, le lecteur natif vient d'être créé et n'a jamais été
    // préparé. Logcat a confirmé que c'est précisément `stop()` sur ce
    // lecteur "vierge" qui bloquait indéfiniment (l'exécution n'atteignait
    // jamais `play()`, ni même le `catch` — l'`await` ne se résolvait tout
    // simplement jamais). Le `.timeout()` ci-dessous est une seconde
    // protection, pour les appels suivants où stop()/seek() ont
    // effectivement un état à réinitialiser : même défensifs, ils ne
    // doivent plus jamais pouvoir bloquer indéfiniment.
    if (_boatAmbientHasPlayedOnce) {
      try {
        await _boatAmbientPlayer.stop().timeout(_kBoatAmbientCallTimeout);
      } catch (e) {
        debugPrint('[BoatAmbient] stop() ignoré (échec/timeout) : $e');
      }
      try {
        await _boatAmbientPlayer
            .seek(Duration.zero)
            .timeout(_kBoatAmbientCallTimeout);
      } catch (e) {
        debugPrint('[BoatAmbient] seek() ignoré (échec/timeout) : $e');
      }
    }
    // Réaffirmé ici (et pas seulement dans le constructeur) : le constructeur
    // l'appelle via `unawaited`, donc rien ne garantit qu'il ait bien été
    // appliqué nativement avant ce tout premier `play()` si le bateau de
    // pêche apparaît très tôt en partie (dès 2 tuiles posées, voir
    // `HexBoardGame.kFishingBoatTriggerTileCount`). Sans boucle effective, le
    // son s'arrêterait net après sa seule lecture (~40s) au lieu de tourner
    // tant que le bateau est à l'écran.
    try {
      await _boatAmbientPlayer
          .setReleaseMode(ReleaseMode.loop)
          .timeout(_kBoatAmbientCallTimeout);
    } catch (e) {
      debugPrint('[BoatAmbient] setReleaseMode() ignoré (échec/timeout) : $e');
    }
    try {
      await _boatAmbientPlayer.setVolume(0.0).timeout(_kBoatAmbientCallTimeout);
    } catch (e) {
      debugPrint('[BoatAmbient] setVolume(0.0) ignoré (échec/timeout) : $e');
    }
    // Contrairement aux appels ci-dessus (dont l'échec est sans
    // conséquence grave : au pire un fondu repart d'un état non idéal), un
    // échec ICI signifie que le son ne sera jamais audible — c'est donc le
    // seul point de cette méthode où l'erreur est à la fois catchée ET
    // rendue visible localement (voir le commentaire sur `debugPrint`
    // au début de la méthode), plutôt que simplement avalée par le handler
    // global. `return` après l'échec : poursuivre le fondu sur un lecteur
    // qui n'a pas démarré n'aurait aucun effet audible.
    try {
      // If the source was prepared during splash, use `resume()` instead of
      // `play()`: `play()` calls `setSource()` again and unnecessarily
      // re-prepares the Android MediaPlayer. This is especially important for
      // this long looping ambience because the boat is a decorative component
      // created while other Android SDKs may still be initializing.
      if (_boatAmbientPrepared) {
        await _boatAmbientPlayer
            .resume()
            .timeout(_kBoatAmbientCallTimeout);
      } else {
        await _boatAmbientPlayer
            .play(AssetSource(_kBoatAmbientAssetPath))
            .timeout(_kBoatAmbientCallTimeout);
      }
      _boatAmbientHasPlayedOnce = true;
      debugPrint(
        '[BoatAmbient] démarrage réussi, asset=$_kBoatAmbientAssetPath '
        'prepared=$_boatAmbientPrepared',
      );
    } catch (e, stack) {
      debugPrint('[BoatAmbient] ÉCHEC du démarrage : $e\n$stack');
      _boatAmbientPrepared = false;
      return;
    }
    // Diagnostic supplémentaire : `play()` réussi ne garantit pas que le
    // lecteur natif avance réellement dans le fichier — sur certains
    // appareils, l'appel de plateforme peut "réussir" (retourner sans
    // erreur) sans que le rendu audio matériel démarre vraiment derrière.
    // On vérifie ici, 600ms après le lancement, l'état natif réel du
    // lecteur ET sa position de lecture :
    //  - state != playing → le lecteur ne joue pas réellement, malgré le
    //    succès apparent de `play()` ;
    //  - state == playing mais position toujours ~0 → le lecteur est
    //    "démarré" côté plugin mais bloqué en interne (décodage/rendu qui
    //    ne progresse pas) ;
    //  - state == playing ET position qui avance → la lecture est
    //    RÉELLEMENT active côté natif, ce qui déplacerait la cause du
    //    silence hors de ce code (routage audio de l'appareil, sortie
    //    active, volume média système...).
    unawaited(() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      try {
        final state = _boatAmbientPlayer.state;
        final position = await _boatAmbientPlayer
            .getCurrentPosition()
            .timeout(_kBoatAmbientCallTimeout);
        final duration = await _boatAmbientPlayer
            .getDuration()
            .timeout(_kBoatAmbientCallTimeout);
        debugPrint(
          '[BoatAmbient] diagnostic 600ms après play() — state=$state '
          'position=$position duration=$duration volumeLogique=${_boatAmbientPlayer.volume}',
        );
      } catch (e) {
        debugPrint('[BoatAmbient] diagnostic 600ms — échec de lecture d\'état : $e');
      }
    }());
    final targetVolume = _sfxVolume;
    final stepDuration = _kBoatAmbientFadeDuration ~/ _kBoatAmbientFadeSteps;
    for (var i = 1; i <= _kBoatAmbientFadeSteps; i++) {
      if (generation != _boatAmbientFadeGeneration) {
        debugPrint('[BoatAmbient] fondu d\'entrée invalidé (generation $generation).');
        return;
      }
      try {
        await _boatAmbientPlayer
            .setVolume(targetVolume * i / _kBoatAmbientFadeSteps)
            .timeout(_kBoatAmbientCallTimeout);
      } catch (e) {
        debugPrint('[BoatAmbient] setVolume() (fondu d\'entrée) ignoré (échec/timeout) : $e');
      }
      if (stepDuration > Duration.zero) {
        await Future<void>.delayed(stepDuration);
      }
    }
    debugPrint('[BoatAmbient] fondu d\'entrée terminé, volume cible=$targetVolume');
  }

  /// Arrête `boat_ambient.mp3` avec un fondu de sortie sur
  /// [_kBoatAmbientFadeDuration], appelé depuis
  /// [FishingBoatComponent.onRemove] une fois le bateau de pêche
  /// définitivement retiré de l'écran (fin de son trajet de départ). Voir
  /// [playBoatAmbient] pour le principe symétrique (fondu d'entrée) et
  /// [_boatAmbientFadeGeneration] pour l'invalidation croisée.
  Future<void> stopBoatAmbient() async {
    final generation = ++_boatAmbientFadeGeneration;
    final startVolume = _boatAmbientPlayer.volume;
    final stepDuration = _kBoatAmbientFadeDuration ~/ _kBoatAmbientFadeSteps;
    for (var i = _kBoatAmbientFadeSteps - 1; i >= 0; i--) {
      if (generation != _boatAmbientFadeGeneration) return;
      try {
        await _boatAmbientPlayer
            .setVolume(startVolume * i / _kBoatAmbientFadeSteps)
            .timeout(_kBoatAmbientCallTimeout);
      } catch (e) {
        debugPrint('[BoatAmbient] setVolume() (fondu de sortie) ignoré (échec/timeout) : $e');
      }
      if (stepDuration > Duration.zero) {
        await Future<void>.delayed(stepDuration);
      }
    }
    if (generation == _boatAmbientFadeGeneration) {
      // stop() défensif — voir le commentaire équivalent dans
      // [playBoatAmbient]. Ici le lecteur a forcément déjà joué (le fondu
      // de sortie ne se déclenche qu'après un fondu d'entrée réussi), donc
      // ce n'est pas le cas de blocage observé en logcat — mais le
      // `.timeout()` reste une protection peu coûteuse.
      try {
        await _boatAmbientPlayer.stop().timeout(_kBoatAmbientCallTimeout);
      } catch (e) {
        debugPrint('[BoatAmbient] stop() (fondu de sortie) ignoré (échec/timeout) : $e');
      }
    }
  }

  /// Précharge tous les bruitages ([SfxTrack]) — ainsi que
  /// `boat_ambient.mp3` (voir [playBoatAmbient]/[stopBoatAmbient]) — en
  /// cache disque local via [AudioCache] — appelé une seule fois au
  /// lancement de l'app (voir `SplashScreen._load`, en parallèle de
  /// `_precacheImages`), avant même que le joueur n'atteigne l'accueil.
  ///
  /// Sans ça, chaque bruitage encourt un délai perceptible à sa toute
  /// première lecture : le plugin doit encore extraire l'asset du bundle
  /// vers un fichier temporaire avant de pouvoir le jouer. Particulièrement
  /// gênant pour `tile_gain.mp3` et `end_game.mp3` : joués sur des lecteurs
  /// dédiés ([_tileGainPlayer], [_endGamePlayer]) plutôt que le pool
  /// tournant, donc jamais "réchauffés" par une lecture antérieure d'un
  /// autre bruitage — leur toute première lecture en jeu (souvent la
  /// première tuile posée, ou la toute fin de partie) est aussi celle qui
  /// subit ce délai, au pire moment pour le ressenti de la récompense.
  ///
  /// Ne précharge volontairement PAS [MusicTrack] (home.mp3, ambient_1.mp3,
  /// plusieurs Mo chacun) : `playMusic` démarre déjà sans délai perceptible
  /// (voir le commentaire de [playMusic]), et forcer leur extraction
  /// complète sur disque ici ralentirait inutilement le lancement pour un
  /// gain qui ne concerne pas le problème visé.
  Future<void> preloadSfx() async {
    try {
      await AudioCache.instance.loadAll(
        [...SfxTrack.values.map((t) => t.assetPath), _kBoatAmbientAssetPath],
      );
    } catch (_) {
      // Optimisation de confort, pas une nécessité : un échec (stockage
      // plein, permission refusée...) ne doit jamais bloquer le reste du
      // lancement de l'app ni faire planter SplashScreen._load — les sons
      // resteront simplement joignables normalement, juste sans le gain de
      // préchargement.
    }
  }

  /// « Réchauffe » [_boatAmbientPlayer] au lancement en le faisant vraiment
  /// jouer une fraction de seconde (à volume nul) puis pause, plutôt que de
  /// le laisser vierge jusqu'au tout premier passage du bateau de pêche.
  ///
  /// Réplique ce qui rend [_musicPlayer] fiable : ce dernier n'est JAMAIS
  /// utilisé "à froid" — `SplashScreen.initState` appelle déjà
  /// `playMusic(home)` en tout premier, avant même `preloadSfx`/le reste de
  /// `_load` (voir `splash_screen.dart`), si bien que par le temps où
  /// `game_screen.dart` demande `MusicTrack.ambient`, ce lecteur a déjà
  /// traversé un cycle complet play/prepare natif réussi, bien avant que le
  /// SDK Ads ne commence son initialisation. C'est justement cette toute
  /// première préparation native, à froid, de [_boatAmbientPlayer] qui
  /// posait problème (logcat : `stop()` qui ne se résolvait jamais sur un
  /// lecteur jamais préparé, puis, une fois ce point contourné, un silence
  /// total malgré des logs de succès à chaque étape) — et qui survenait
  /// systématiquement dans la fenêtre de quelques secondes après le
  /// lancement où le SDK Ads s'initialise (`DynamiteModule`, chargement de
  /// la bannière...), contrairement à `_musicPlayer` dont le premier
  /// `play()` a lieu plus tôt, avant cette contention.
  ///
  /// Appelée depuis `SplashScreen.initState`, `unawaited`, juste après
  /// `playMusic(home)` — même point d'entrée, même timing — plutôt que
  /// depuis [preloadSfx] (qui ne démarre qu'ensuite, dans `_load`, après
  /// `AudioCache.loadAll` de tous les autres bruitages, ce qui aurait
  /// repoussé ce premier cycle natif un peu plus tard, réduisant l'avance
  /// prise sur le SDK Ads). En avançant ce premier cycle natif ici, le
  /// bateau de pêche ne fait plus jamais sa toute première lecture "à
  /// froid" en pleine partie : quand [playBoatAmbient] s'exécute, le
  /// lecteur est déjà dans le même état "déjà utilisé une fois" que
  /// [_musicPlayer] l'est pour sa propre toute première lecture en jeu.
  Future<void> primeBoatAmbient() async {
    try {
      // Never touch the native player before the global audio context has
      // actually been installed. The old implementation started a real,
      // silent playback here, which could acquire the default Android audio
      // focus while Ads was initializing and then leave the player silent.
      await _audioContextReady;

      await _boatAmbientPlayer
          .setReleaseMode(ReleaseMode.loop)
          .timeout(_kBoatAmbientCallTimeout);
      await _boatAmbientPlayer
          .setVolume(0.0)
          .timeout(_kBoatAmbientCallTimeout);

      // Prepare the asset without starting playback. `resume()` in
      // playBoatAmbient() will start this already-prepared source.
      await _boatAmbientPlayer
          .setSource(AssetSource(_kBoatAmbientAssetPath))
          .timeout(_kBoatAmbientCallTimeout);

      _boatAmbientPrepared = true;
      debugPrint(
        '[BoatAmbient] préchauffage natif réussi (source préparée, '
        'lecture non démarrée).',
      );
    } catch (e, stack) {
      _boatAmbientPrepared = false;
      // A failed warm-up must never prevent the normal playback path from
      // trying again when the boat actually appears.
      debugPrint(
        '[BoatAmbient] préchauffage échoué (sans conséquence) : '
        '$e\n$stack',
      );
    }
  }

  /// Joue `purchase_success.mp3` (fanfare procédurale) lorsqu'un achat
  /// in-app aboutit — pack de pièces ou premium, voir
  /// `purchase_success_popup.dart` — déclenché à l'ouverture de la pop-up
  /// de célébration, aux côtés du retour haptique
  /// [HapticsService.purchaseSuccess]. Pioche dans le pool tournant comme
  /// [_playSfx] : un achat n'arrive jamais coup sur coup avec un autre, mais
  /// autant rester cohérent avec le reste des bruitages ponctuels.
  Future<void> playPurchaseSuccess() => _playSfx(SfxTrack.purchaseSuccess);

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
    _boatAmbientPlayer.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(ref);
  ref.onDispose(service._dispose);
  return service;
});
