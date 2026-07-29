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
/// Clic de bouton ([playButtonClick]) : contrairement aux autres bruitages,
/// il n'est associé à aucun fichier audio — sa forme d'onde est générée
/// procéduralement en mémoire ([_generateClickWaveform], un bref clic dans
/// la tonalité d'une touche de clavier mécanique : transitoire de bruit
/// filtré + corps résonant à deux harmoniques, chacun avec sa propre
/// décroissance exponentielle) puis jouée via [BytesSource].
///
/// Pose de tuile ([playTilePlaced]) : également générée procéduralement
/// ([_generateTileKnockWaveform]), mais avec son propre timbre dédié plutôt
/// que le clic de bouton — un "clac" sec de tuile en plastique épais (style
/// Mahjong) posée sur le plateau : un "clack" d'impact (bruit à peine
/// filtré, net et clair) superposé à un corps résonant aigu à deux partiels
/// non harmoniques (timbre plastique dur plutôt que cloche ou bois) avec un
/// très bref glissando de hauteur descendant au tout début (l'effet de
/// "pli" du matériau dur qui claque puis se stabilise). [playButtonClick]
/// est pensé pour être déclenché par [buttonTapFeedback]
/// (voir `haptics_service.dart`) sur tout bouton de l'application qui ne
/// possède pas déjà son propre bruitage dédié.
///
/// Rotation de tuile ([playTileRotated]) : même générateur que le clic de
/// bouton ([_generateClickWaveform]), réutilisé avec des paramètres dédiés
/// (plus bref, plus aigu, décroissances plus courtes) pour un tic sec et
/// léger — un cran de rotation n'est qu'une micro-confirmation répétée
/// jusqu'à 6 fois par tour complet, donc volontairement plus discret et
/// moins "plein" que le clic de bouton. Déclenché depuis
/// [HexBoardGame._handleRotation] (`hex_board_game.dart`), une fois par
/// cran de 60° franchi — même granularité que le retour haptique
/// [HapticsService.tileRotated].
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

/// Délai minimal entre deux lectures de `tile_gain.mp3` (voir
/// [AudioService.playTileGained]) — un gain multi-tuiles peut déclencher
/// [AudioService.playTileGained] plus vite que ça (impacts d'icônes
/// rapprochés), auquel cas les lectures excédentaires sont mises en
/// attente plutôt que de couper net le son précédent trop tôt.
const Duration _kTileGainSfxGap = Duration(milliseconds: 250);

/// Durée de vol d'une pièce vers son compteur avant l'impact (dupliquée
/// depuis [CoinComponent]/`bonus_animations.dart`, qui ne l'exposent pas
/// sous forme de constante partagée ici) — point de départ du calcul de
/// [_coinSoundsFinishDelay].
const Duration _kCoinFlyDuration = Duration(milliseconds: 600);

/// Durée de lecture d'un `coin.mp3` (mesurée ~0.696s, arrondie à 0.7s par
/// prudence) — sert à estimer quand la dernière pièce d'un gain a fini de
/// sonner. Dupliquée depuis `bonus_animations.dart`
/// ([kCoinSfxClipDurationSec]).
const Duration _kCoinSfxClipDuration = Duration(milliseconds: 700);

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

/// Durée du son de pose de tuile généré, en millisecondes — bref et net,
/// cohérent avec le "clack" sec d'une tuile en plastique épais (style
/// Mahjong) plutôt qu'avec la résonance plus longue d'un impact bois.
/// Légèrement rallongé pour laisser un peu plus de place à la résonance
/// grave du corps ([_kTileWoodFundamentalFreq]).
const double _kTileKnockDurationMs = 55;

/// Constante de temps (secondes) de la décroissance du "clack" d'impact
/// (bruit filtré) du son de pose de tuile — extrêmement rapide, pour un
/// claquement sec et dur plutôt qu'un souffle qui traîne.
const double _kTileThudDecayTauSeconds = 0.0045;

/// Constante de temps (secondes) de la décroissance du corps résonant
/// du son de pose de tuile — légèrement allongée pour laisser sonner un peu
/// plus le grave du corps plutôt que de couper net.
const double _kTileWoodDecayTauSeconds = 0.017;

/// Fréquence fondamentale (Hz) du corps résonant du son de pose de tuile —
/// abaissée par rapport au timbre plastique aigu précédent, pour un
/// claquement plus grave et plus "plein".
const double _kTileWoodFundamentalFreq = 650;

/// Fréquence du second partiel (Hz) du corps résonant — rapport
/// volontairement non harmonique avec [_kTileWoodFundamentalFreq] pour un
/// timbre "plastique dur" plutôt qu'un timbre "cloche" (partiels
/// harmoniques), même ratio que précédemment mais transposé vers le grave.
const double _kTileWoodPartialFreq = 1270;

/// Amplitude du glissando de hauteur (Hz) au tout début de l'impact du son
/// de pose de tuile, qui redescend rapidement vers la fréquence de repos —
/// simule le très bref "pli" de hauteur d'un matériau dur qui claque avant
/// de se stabiliser. Amplitude réduite par rapport à l'ancien timbre bois :
/// le plastique dur a moins de "plop" et plus de "clac".
const double _kTileWoodPitchBendHz = 45;

/// Constante de temps (secondes) de la décroissance du glissando de
/// hauteur ([_kTileWoodPitchBendHz]) — très rapide, quelques millisecondes,
/// pour un effet perceptible seulement sur l'attaque du son.
const double _kTileWoodPitchBendDecayTauSeconds = 0.004;

/// Poids relatif du "clack" d'impact dans le mixage final du son de pose de
/// tuile.
const double _kTileThudMix = 0.55;

/// Poids relatif du corps résonant plastique dans le mixage final du son de
/// pose de tuile.
const double _kTileWoodMix = 0.5;

/// Poids relatif du transitoire « tac » (bruit filtré) dans le mixage
/// final du clic de bouton ([_generateClickWaveform]).
const double _kTickMix = 0.55;

/// Poids relatif du corps résonant « thock » dans le mixage final du clic
/// de bouton ([_generateClickWaveform]).
const double _kKnockMix = 0.35;

/// Facteur multiplicatif appliqué au réglage « Bruitages »
/// ([OptionsState.sfxVolume]) pour le clic de bouton — plus discret que les
/// autres bruitages (gain de pièces, pose de tuile) puisqu'il accompagne
/// une simple interaction d'interface plutôt qu'un événement de jeu.
const double _kClickVolumeScale = 0.45;

/// Atténuation appliquée au son de pose de tuile ([AudioService.playTilePlaced])
/// par rapport au réglage « Bruitages » — 10 % plus discret que le volume
/// nominal.
const double _kTilePlacedVolumeScale = 0.9;

/// Durée du clic de rotation généré, en millisecondes. Deuxième relevé :
/// 18ms → 26ms était déjà un premier correctif, mais restait en pratique
/// inaudible sur haut-parleur de téléphone — la fréquence élevée du corps
/// résonant ([_kRotationKnockFundamentalFreq] ci-dessous, alors à 1800Hz)
/// laissait très peu d'énergie perceptible dans une fenêtre aussi brève.
/// Remonté à 32ms, proche de [_kButtonClickDurationMs] (35ms, dont
/// l'audibilité est éprouvée) : assez pour que le corps résonant sonne
/// réellement, tout en restant net pour un enchaînement rapide (jusqu'à 6
/// clics par tour complet).
const double _kRotationClickDurationMs = 32;

/// Constante de temps (secondes) de la décroissance du transitoire « tac »
/// du clic de rotation — un peu plus longue que le premier réglage (0.0018)
/// pour laisser le tac exister au-delà de la toute première milliseconde.
const double _kRotationTickDecayTauSeconds = 0.0028;

/// Constante de temps (secondes) de la décroissance du corps résonant du
/// clic de rotation — allongée par rapport au premier réglage (0.009) pour
/// laisser sonner la fondamentale plus abaissée ci-dessous.
const double _kRotationKnockDecayTauSeconds = 0.014;

/// Fréquence fondamentale (Hz) du corps résonant du clic de rotation.
/// Légèrement remontée (1300→1450) pour un timbre un peu plus aigu.
/// Reste plus aigu que le clic de bouton ([_kButtonKnockFundamentalFreq],
/// 1100Hz) pour un timbre plus léger, cohérent avec un simple cran de 60°.
const double _kRotationKnockFundamentalFreq = 1450;

/// Fréquence de l'harmonique secondaire (Hz) du clic de rotation — remontée
/// dans la même proportion que la fondamentale ci-dessus (2300→2550).
const double _kRotationKnockHarmonicFreq = 2550;

/// Amplitude du glissando de hauteur (Hz) au tout début de l'impact du clic
/// de rotation, redescendant rapidement vers la fréquence de repos — une
/// paire de sinusoïdes fixes sans variation de hauteur sonnait trop "pure",
/// presque une tonalité de synthétiseur ; ce bref pli casse cette régularité
/// et rapproche le timbre du mini-cran d'un mécanisme réel qui claque puis
/// se stabilise (même principe que [_kTileWoodPitchBendHz] pour la pose de
/// tuile).
const double _kRotationPitchBendHz = 60;

/// Constante de temps (secondes) de la décroissance du glissando de hauteur
/// du clic de rotation — très rapide, perceptible seulement sur l'attaque.
const double _kRotationPitchBendDecayTauSeconds = 0.003;

/// Facteur multiplicatif appliqué au réglage « Bruitages »
/// ([OptionsState.sfxVolume]) pour le clic de rotation. Abaissé de 10 %
/// (0.7 → 0.63) par rapport au réglage précédent.
const double _kRotationClickVolumeScale = 0.63;

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
/// Paramétrée pour être réutilisée avec des fréquences différentes, mais
/// aujourd'hui utilisée uniquement pour le clic de bouton
/// ([AudioService._clickWaveform]) — la pose de tuile a son propre
/// générateur dédié ([_generateTileKnockWaveform]). Encodé en PCM 16 bits
/// mono puis enveloppé dans un en-tête WAV minimal par [_pcm16MonoToWav]
/// pour être jouable directement via [BytesSource]. Calculé une seule fois
/// par forme d'onde, à la construction du service.
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
  // Seed fixe : la forme d'onde n'a besoin d'être calculée qu'une seule
  // fois (voir [AudioService._clickWaveform]), son contenu n'a donc pas
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

/// Génère procéduralement le clic de rotation — timbre dédié plutôt qu'une
/// réutilisation du générateur générique [_generateClickWaveform] (toujours
/// utilisé pour le clic de bouton). Même structure tac/corps résonant, mais
/// le corps résonant reçoit ici un bref glissando de hauteur descendant
/// ([_kRotationPitchBendHz], calculé par accumulation de phase pour rester
/// continu) — la paire de sinusoïdes fixes du générateur générique donnait
/// un timbre trop pur, presque une tonalité de synthétiseur ; ce pli de
/// hauteur rapproche le son du mini-cran d'un mécanisme réel qui claque puis
/// se stabilise, même principe que [_generateTileKnockWaveform] pour la pose
/// de tuile.
Uint8List _generateRotationClickWaveform() {
  final sampleCount =
      (_kClickSampleRate * _kRotationClickDurationMs / 1000).round();
  final samples = Int16List(sampleCount);
  // Seed fixe, comme les autres formes d'onde générées une seule fois à la
  // construction du service.
  final noiseRandom = Random(31);
  final dt = 1 / _kClickSampleRate;
  var prevNoise = 0.0;
  var phaseFundamental = 0.0;
  var phaseHarmonic = 0.0;
  for (var i = 0; i < sampleCount; i++) {
    final t = i / _kClickSampleRate;

    // Transitoire "tac" : identique au générateur générique.
    final rawNoise = noiseRandom.nextDouble() * 2 - 1;
    final filteredNoise = rawNoise - prevNoise * 0.5;
    prevNoise = rawNoise;
    final tick = filteredNoise * exp(-t / _kRotationTickDecayTauSeconds);

    // Corps résonant "thock" : fondamentale + harmonique, toutes deux
    // affectées du même glissando de hauteur descendant au tout début de
    // l'impact, pour un timbre moins figé/synthétique.
    final bend =
        _kRotationPitchBendHz * exp(-t / _kRotationPitchBendDecayTauSeconds);
    phaseFundamental += 2 * pi * (_kRotationKnockFundamentalFreq + bend) * dt;
    phaseHarmonic += 2 * pi * (_kRotationKnockHarmonicFreq + bend) * dt;
    final knockEnvelope = exp(-t / _kRotationKnockDecayTauSeconds);
    final knock =
        (sin(phaseFundamental) + 0.4 * sin(phaseHarmonic)) * knockEnvelope;

    final value = tick * _kTickMix + knock * _kKnockMix;
    samples[i] = (value * 32767).round().clamp(-32768, 32767);
  }
  return _pcm16MonoToWav(samples, _kClickSampleRate);
}

/// Génère procéduralement le son de pose de tuile — sans aucun fichier
/// audio associé — un "clac" sec évoquant une tuile en plastique épais
/// (style Mahjong) posée sur le plateau plutôt qu'un clic d'interface ou
/// un impact bois, en superposant deux composantes :
///  - un "clack" d'impact : bruit blanc légèrement filtré (moyenne mobile
///    à coefficient élevé, donc peu lissée, à l'inverse du "thud" sourd
///    d'origine) à décroissance exponentielle extrêmement rapide
///    ([_kTileThudDecayTauSeconds]), pour un claquement dur et net plutôt
///    qu'un impact sourd ;
///  - un corps résonant "plastique" : deux sinusoïdes aiguës à des
///    fréquences non harmoniques ([_kTileWoodFundamentalFreq] /
///    [_kTileWoodPartialFreq], timbre plastique dur plutôt que cloche ou
///    bois), affectées d'un bref glissando de hauteur descendant
///    ([_kTileWoodPitchBendHz], calculé par accumulation de phase pour
///    rester continu) qui simule le très bref "pli" de hauteur du matériau
///    dur avant que la hauteur ne se stabilise, avec une décroissance
///    courte et nette ([_kTileWoodDecayTauSeconds]).
/// Encodé en PCM 16 bits mono puis enveloppé dans un en-tête WAV minimal
/// par [_pcm16MonoToWav]. Calculé une seule fois, à la construction du
/// service (voir [AudioService._tilePlacedKnockWaveform]).
Uint8List _generateTileKnockWaveform() {
  final sampleCount =
      (_kClickSampleRate * _kTileKnockDurationMs / 1000).round();
  final samples = Int16List(sampleCount);
  // Seed fixe : la forme d'onde n'a besoin d'être calculée qu'une seule
  // fois, son contenu n'a donc pas besoin d'être aléatoire d'un lancement
  // de l'app à l'autre.
  final noiseRandom = Random(29);
  final dt = 1 / _kClickSampleRate;
  var lowPassState = 0.0;
  var phaseFundamental = 0.0;
  var phasePartial = 0.0;
  for (var i = 0; i < sampleCount; i++) {
    final t = i / _kClickSampleRate;

    // Clack d'impact : bruit blanc à peine lissé (coefficient élevé, donc
    // peu de passe-bas) pour un claquement dur et clair plutôt que le
    // "boum" sourd d'un impact bois.
    final rawNoise = noiseRandom.nextDouble() * 2 - 1;
    lowPassState += (rawNoise - lowPassState) * 0.75;
    final thud = lowPassState * exp(-t / _kTileThudDecayTauSeconds);

    // Corps résonant "plastique" : glissando de hauteur descendant au tout
    // début (accumulation de phase pour éviter toute discontinuité),
    // superposant fondamentale et partiel non harmonique, tous deux aigus.
    final bend =
        _kTileWoodPitchBendHz * exp(-t / _kTileWoodPitchBendDecayTauSeconds);
    phaseFundamental += 2 * pi * (_kTileWoodFundamentalFreq + bend) * dt;
    phasePartial += 2 * pi * (_kTileWoodPartialFreq + bend) * dt;
    final woodEnvelope = exp(-t / _kTileWoodDecayTauSeconds);
    final wood =
        (sin(phaseFundamental) + 0.5 * sin(phasePartial)) * woodEnvelope;

    final value = thud * _kTileThudMix + wood * _kTileWoodMix;
    samples[i] = (value * 32767).round().clamp(-32768, 32767);
  }
  return _pcm16MonoToWav(samples, _kClickSampleRate);
}

/// Fréquences (Hz) des trois notes de la mélodie de succès jouée à la
/// réclamation d'une récompense de quête ([playQuestRewardClaimed]) — un
/// arpège ascendant en accord parfait majeur (do5, mi5, sol5), reconnu
/// comme un motif de succès ("ta-da") plutôt qu'une simple gamme.
const List<double> _kQuestRewardNoteFrequencies = [523.25, 659.25, 783.99];

/// Écart de temps (secondes) entre le déclenchement de deux notes
/// consécutives de la mélodie de succès — plus court que la décroissance
/// d'une note ([_kQuestRewardNoteDecayTauSeconds]) pour un léger legato où
/// chaque note chevauche la suivante, plutôt que des notes détachées.
const double _kQuestRewardNoteGapSeconds = 0.1;

/// Constante de temps (secondes) de la décroissance de chaque note de la
/// mélodie de succès — allongée par rapport au premier réglage (0.16) pour
/// laisser sonner davantage le corps de la note : à 0.16s, la mélodie
/// s'éteignait presque aussi vite qu'elle démarrait et se perdait sur un
/// haut-parleur de téléphone, comme le clic de rotation avant son propre
/// correctif d'audibilité.
const double _kQuestRewardNoteDecayTauSeconds = 0.22;

/// Durée de la montée initiale (secondes) de chaque note — quelques
/// millisecondes seulement, pour éviter le "clic" d'une transition brutale
/// de silence à pleine amplitude tout en gardant une attaque nette.
const double _kQuestRewardNoteAttackSeconds = 0.005;

/// Poids relatif de l'harmonique d'octave dans le timbre de chaque note —
/// remonté (0.35 → 0.45) pour un grain "cloche" plus riche et plus présent,
/// sans dominer la fondamentale.
const double _kQuestRewardHarmonicMix = 0.45;

/// Poids relatif du transitoire percussif ("ting", bruit filtré très bref)
/// ajouté à l'attaque de chaque note — les sinusoïdes pures manquaient de
/// contenu large bande, peu audible sur un haut-parleur de téléphone ; ce
/// petit "tic" métallique au tout début de chaque note apporte le grain
/// percussif qui rend une note de carillon repérable, même à volume modéré
/// (même principe que le "clack" d'impact du son de pose de tuile,
/// [_kTileThudMix]).
const double _kQuestRewardTingMix = 0.3;

/// Constante de temps (secondes) de la décroissance du transitoire "ting"
/// ci-dessus — très rapide, pour rester un grain d'attaque et ne pas
/// brouiller le corps tenu de la note.
const double _kQuestRewardTingDecayTauSeconds = 0.012;

/// Marge (secondes) ajoutée après le déclenchement de la dernière note pour
/// laisser sa décroissance ([_kQuestRewardNoteDecayTauSeconds]) s'éteindre
/// complètement avant la fin du buffer, plutôt que de la couper net.
const double _kQuestRewardTailSeconds = 0.5;

/// Génère procéduralement la mélodie de succès jouée à la réclamation
/// d'une récompense de quête ([AudioService.playQuestRewardClaimed]) —
/// trois notes ([_kQuestRewardNoteFrequencies]) déclenchées en léger
/// legato ([_kQuestRewardNoteGapSeconds]). Chaque note superpose :
///  - un corps tenu "cloche" : sinusoïde fondamentale + harmonique d'octave
///    ([_kQuestRewardHarmonicMix]), attaque douce
///    ([_kQuestRewardNoteAttackSeconds]) et décroissance exponentielle
///    ([_kQuestRewardNoteDecayTauSeconds]) ;
///  - un transitoire percussif "ting" ([_kQuestRewardTingMix], bruit filtré
///    à décroissance très rapide [_kQuestRewardTingDecayTauSeconds]), pour
///    la même raison que le "clack" du son de pose de tuile : une paire de
///    sinusoïdes seules manque de présence sur un haut-parleur de
///    téléphone.
/// Les notes se chevauchent légèrement (chaque nouvelle note démarre avant
/// que la précédente ne soit éteinte) plutôt que d'être strictement
/// séquentielles, pour un arpège fluide plutôt que trois bips séparés.
/// Encodé en PCM 16 bits mono via [_pcm16MonoToWav]. Calculé une seule
/// fois, à la construction du service (voir
/// [AudioService._questRewardMelodyWaveform]).
Uint8List _generateQuestRewardMelodyWaveform() {
  final noteCount = _kQuestRewardNoteFrequencies.length;
  final totalDurationSeconds =
      _kQuestRewardNoteGapSeconds * (noteCount - 1) + _kQuestRewardTailSeconds;
  final sampleCount = (_kClickSampleRate * totalDurationSeconds).round();
  final samples = Int16List(sampleCount);
  // Seed fixe : la forme d'onde n'a besoin d'être calculée qu'une seule
  // fois, son contenu n'a donc pas besoin d'être aléatoire d'un lancement
  // de l'app à l'autre.
  final noiseRandom = Random(43);
  var prevNoise = 0.0;
  for (var i = 0; i < sampleCount; i++) {
    final t = i / _kClickSampleRate;
    var value = 0.0;

    // Transitoire "ting" : un seul bruit filtré partagé entre les notes
    // (indépendant de la fréquence de chacune), sommé pour chaque note
    // active avec sa propre décroissance très rapide.
    final rawNoise = noiseRandom.nextDouble() * 2 - 1;
    final filteredNoise = rawNoise - prevNoise * 0.5;
    prevNoise = rawNoise;

    for (var n = 0; n < noteCount; n++) {
      final noteStart = n * _kQuestRewardNoteGapSeconds;
      final localT = t - noteStart;
      if (localT < 0) continue;
      final attack =
          (localT / _kQuestRewardNoteAttackSeconds).clamp(0.0, 1.0);
      final envelope =
          attack * exp(-localT / _kQuestRewardNoteDecayTauSeconds);
      final freq = _kQuestRewardNoteFrequencies[n];
      final body = (sin(2 * pi * freq * localT) +
              _kQuestRewardHarmonicMix * sin(2 * pi * freq * 2 * localT)) *
          envelope;
      final ting = filteredNoise *
          exp(-localT / _kQuestRewardTingDecayTauSeconds) *
          _kQuestRewardTingMix;
      value += body + ting;
    }
    // Trois notes en léger chevauchement peuvent sommer au-delà de [-1, 1] :
    // on divise par un facteur légèrement inférieur au nombre de notes
    // (chevauchement partiel seulement) plutôt que par noteCount, pour ne
    // pas assourdir inutilement les portions où une seule note sonne.
    value /= 1.6;
    samples[i] = (value * 32767).round().clamp(-32768, 32767);
  }
  return _pcm16MonoToWav(samples, _kClickSampleRate);
}


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

  /// Lecteur dédié pour la mélodie de succès de réclamation de récompense
  /// de quête (voir [playQuestRewardClaimed]) — comme [_endGamePlayer], en
  /// dehors du pool : une nouvelle réclamation doit couper net une
  /// éventuelle mélodie encore en cours plutôt que la superposer, et un
  /// lecteur dédié évite qu'un bruitage du pool (pose de tuile, pièce
  /// gagnée) ne l'interrompe en réutilisant le même lecteur.
  final AudioPlayer _questRewardPlayer = AudioPlayer();

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

  /// Forme d'onde du clic de rotation, générée une seule fois — timbre
  /// dédié ([_generateRotationClickWaveform], distinct du générateur
  /// générique [_generateClickWaveform] utilisé pour le clic de bouton) —
  /// puis rejouée à chaque appel de [playTileRotated].
  final Uint8List _rotationClickWaveform = _generateRotationClickWaveform();

  /// Forme d'onde du son de pose de tuile, générée une seule fois (voir
  /// [_generateTileKnockWaveform]) puis rejouée à chaque appel de
  /// [playTilePlaced] — évite de la recalculer à chaque pose. Timbre dédié
  /// ("clac" de tuile en plastique épais) plutôt qu'une réutilisation du clic de
  /// bouton, pour rester distinct à l'oreille et cohérent avec l'action de
  /// jeu qu'il accompagne.
  final Uint8List _tilePlacedKnockWaveform = _generateTileKnockWaveform();

  /// Forme d'onde de la mélodie de succès de réclamation de récompense de
  /// quête, générée une seule fois (voir
  /// [_generateQuestRewardMelodyWaveform]) puis rejouée à chaque appel de
  /// [playQuestRewardClaimed] — évite de la recalculer à chaque
  /// réclamation.
  final Uint8List _questRewardMelodyWaveform =
      _generateQuestRewardMelodyWaveform();

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
  /// [playButtonClick], il s'agit d'un son généré procéduralement
  /// ([_tilePlacedKnockWaveform]) plutôt que d'un fichier audio, mais avec
  /// son propre timbre dédié ("clac" de tuile en plastique épais — voir
  /// [_generateTileKnockWaveform]) plutôt qu'une réutilisation du clic de
  /// bouton d'interface. Pioche dans le même pool tournant que [_playSfx]
  /// pour laisser plusieurs poses se chevaucher sans se couper, avec la
  /// même variation de hauteur.
  Future<void> playTilePlaced() async {
    if (!_sfxEnabled) return;
    final player = _sfxPool[_sfxCursor];
    _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
    final pitch = 1.0 + (_random.nextDouble() * 2 - 1) * _kPitchVariance;
    await player.stop();
    await player.setVolume(_sfxVolume * _kTilePlacedVolumeScale);
    await player.setPlaybackRate(pitch);
    await player.play(BytesSource(_tilePlacedKnockWaveform));
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
  ///
  /// [isGameOverProvider] n'est lui-même positionné à `true` qu'une fois
  /// les `coin.mp3` de la toute dernière pose terminés (voir
  /// [coinSoundsFinishDelay], utilisé côté appelant dans
  /// `placement_commit.dart`, `_checkGameOver`) : popup de résultats et
  /// bruitage de fin de partie apparaissent donc déjà ensemble, sans qu'un
  /// délai supplémentaire soit nécessaire ici.
  Future<void> playEndGame() async {
    if (!_sfxEnabled) return;
    await _endGamePlayer.stop();
    await _endGamePlayer.setVolume(_sfxVolume);
    await _endGamePlayer.play(AssetSource(SfxTrack.endGame.assetPath));
  }

  /// Joue la mélodie de succès générée procéduralement
  /// ([_questRewardMelodyWaveform], voir
  /// [_generateQuestRewardMelodyWaveform]) au moment où le joueur réclame la
  /// récompense d'une quête terminée (voir `quests_screen.dart`,
  /// `_QuestCard._handleClaim`, déclenché aux côtés du retour haptique
  /// [HapticsService.questRewardClaimed]). Lecteur dédié
  /// ([_questRewardPlayer]) plutôt que le pool tournant, pour couper net
  /// une éventuelle mélodie encore en cours si le joueur réclame une autre
  /// récompense très rapidement, plutôt que de superposer deux arpèges.
  Future<void> playQuestRewardClaimed() async {
    if (!_sfxEnabled) return;
    await _questRewardPlayer.stop();
    await _questRewardPlayer.setVolume(_sfxVolume);
    await _questRewardPlayer.play(BytesSource(_questRewardMelodyWaveform));
  }

  /// Estime le délai à partir duquel le dernier `coin.mp3` d'un gain de
  /// [coinCount] pièces aura fini de sonner : vol de la pièce jusqu'au
  /// compteur ([_kCoinFlyDuration]) puis lectures échelonnées
  /// ([_kCoinSfxGap] entre chacune, plafonnées à [_kMaxCoinSfxRepeats])
  /// jusqu'à la fin de la dernière ([_kCoinSfxClipDuration]). Retourne
  /// [Duration.zero] si [coinCount] est nul (aucune pièce, donc aucun
  /// bruitage à attendre).
  ///
  /// Statique et publique pour être réutilisée par
  /// `placement_commit.dart` (`_checkGameOver`) : la popup de résultats
  /// (voir [isGameOverProvider]) n'est révélée qu'une fois ce délai
  /// écoulé, pour apparaître exactement en même temps que [playEndGame].
  static Duration coinSoundsFinishDelay(int coinCount) {
    if (coinCount <= 0) return Duration.zero;
    final n = coinCount.clamp(0, _kMaxCoinSfxRepeats);
    return _kCoinFlyDuration + _kCoinSfxGap * (n - 1) + _kCoinSfxClipDuration;
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

  /// Joue le clic de rotation généré procéduralement ([_rotationClickWaveform],
  /// même générateur que [playButtonClick] mais timbre dédié, plus aigu —
  /// voir [_generateClickWaveform]) — aucun fichier audio associé. Pioche
  /// dans le même pool tournant que [_playSfx]/[playButtonClick] (même
  /// hauteur légèrement randomisée), avec un volume ([_kRotationClickVolumeScale])
  /// en réalité plus élevé que celui du clic de bouton : un cran de rotation
  /// isolé est un événement plus furtif à l'oreille (durée/fréquence plus
  /// discrètes) qu'un tap de bouton, il lui faut donc plus de présence pour
  /// rester perceptible même en rafale (un clic par cran de 60°, jusqu'à 6
  /// par tour complet).
  ///
  /// À appeler depuis [HexBoardGame._handleRotation] (`hex_board_game.dart`)
  /// à chaque cran de rotation franchi — même déclencheur que
  /// [HapticsService.tileRotated].
  Future<void> playTileRotated() async {
    if (!_sfxEnabled) return;
    final player = _sfxPool[_sfxCursor];
    _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
    final pitch = 1.0 + (_random.nextDouble() * 2 - 1) * _kPitchVariance;
    await player.stop();
    await player.setVolume(_sfxVolume * _kRotationClickVolumeScale);
    await player.setPlaybackRate(pitch);
    await player.play(BytesSource(_rotationClickWaveform));
  }

  void _dispose() {
    _musicPlayer.dispose();
    for (final p in _sfxPool) {
      p.dispose();
    }
    _tileGainPlayer.dispose();
    _endGamePlayer.dispose();
    _questRewardPlayer.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(ref);
  ref.onDispose(service._dispose);
  return service;
});
