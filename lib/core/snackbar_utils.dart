import 'package:flutter/material.dart';

/// Clé globale du [ScaffoldMessenger] racine, à passer à
/// `MaterialApp(scaffoldMessengerKey: rootScaffoldMessengerKey, ...)`.
///
/// C'est l'approche recommandée par la documentation officielle Flutter
/// (https://docs.flutter.dev/release/breaking-changes/scaffold-messenger)
/// pour piloter les SnackBars sans dépendre d'un `BuildContext` précis :
/// un seul point d'accès, utilisable même en dehors de l'arbre de widgets
/// (services, callbacks réseau, etc.), qui ne peut pas se retrouver "lié" au
/// mauvais écran par erreur.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Affiche une SnackBar en évitant les deux bugs classiques de
/// `ScaffoldMessenger` :
///
/// 1. **Réapparition après fermeture** : `showSnackBar` met en file
///    d'attente les SnackBars si une autre est déjà affichée ou en attente.
///    Si cette fonction est appelée plusieurs fois de suite (double tap,
///    plusieurs sources de message), chaque appel s'empile et se ré-affiche
///    l'un après l'autre — donnant l'impression que la SnackBar
///    "réapparaît" alors qu'elle est censée avoir disparu. On appelle donc
///    `clearSnackBars()` avant d'en montrer une nouvelle pour ne jamais
///    avoir plus d'une SnackBar en vol.
///
/// 2. **Apparition sur un autre écran** : le `ScaffoldMessenger` racine
///    (fourni par `MaterialApp`) est partagé par tous les écrans et persiste
///    volontairement à travers les changements de route (comportement
///    documenté de Flutter, pas un bug de librairie). Si une SnackBar est
///    encore visible ou en file au moment où l'on change d'écran, elle
///    continue de s'afficher sur le nouvel écran. D'où [clearAppSnackBars],
///    à appeler juste avant chaque navigation.
void showAppSnackBar(SnackBar snackBar) {
  final messenger = rootScaffoldMessengerKey.currentState;
  // `currentState` peut renvoyer un State encore attaché à la GlobalKey mais
  // momentanément désactivé (ex. rebuild qui déplace/replace le widget dans
  // l'arbre au même frame que cet appel) — `showSnackBar` déclenche alors une
  // recherche d'ancêtre sur un élément désactivé, qui lève une exception non
  // rattrapable ("Looking up a deactivated widget's ancestor is unsafe").
  // Le getter `mounted` (hérité de State) permet de s'en prémunir.
  if (messenger == null || !messenger.mounted) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(snackBar);
}

/// À appeler juste avant toute navigation (push, pushReplacementNamed, etc.)
/// pour empêcher qu'une SnackBar affichée sur l'écran courant "fuite" vers
/// le nouvel écran.
void clearAppSnackBars() {
  rootScaffoldMessengerKey.currentState?.clearSnackBars();
}
