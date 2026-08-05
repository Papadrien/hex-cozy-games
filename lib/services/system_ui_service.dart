/// Application du mode d'affichage système selon la préférence immersive.
///
/// Le mode immersif ([SystemUiMode.immersiveSticky]) masque la barre de
/// statut et la barre de navigation système — un balayage depuis le bord les
/// fait réapparaître brièvement avant qu'elles ne se masquent à nouveau.
/// C'est l'expérience par défaut du jeu (évite tout appui accidentel sur les
/// boutons système). En revanche, il peut frustrer certains joueurs qui
/// veulent voir l'heure ou le niveau de batterie : le réglage
/// [OptionsState.immersiveEnabled] permet de revenir à un affichage
/// classique ("edge-to-edge", barres système visibles).
///
/// Centralise l'appel pour que le démarrage (`main.dart`), le retour au
/// premier plan (`didChangeAppLifecycleState`) et l'écran Réglages partagent
/// exactement le même comportement.
library;

import 'package:flutter/services.dart';

/// Applique le mode d'affichage système correspondant à [immersive].
///
/// `true` masque les barres système (`immersiveSticky`) ; `false` les
/// réaffiche en laissant le rendu "edge-to-edge" (`edgeToEdge`).
Future<void> applySystemUiMode(bool immersive) {
  return SystemChrome.setEnabledSystemUIMode(
    immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
  );
}