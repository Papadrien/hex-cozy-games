import 'dart:ui' show Offset;

/// Type de geste doigt à mimer pour illustrer l'action attendue à une étape
/// du tutoriel (Story 1.10c).
enum TutorialGesture {
  /// Pas de geste (aucune icône affichée).
  none,

  /// Tap simple : le doigt "appuie" avec un anneau qui pulse, en boucle.
  tap,

  /// Swipe vertical (rotation de la tuile) : le doigt oscille de haut en
  /// bas, avec de petites flèches indiquant la direction.
  swipeVertical,

  /// Simple mise en évidence informative (léger rebond), sans geste précis.
  point,
}

/// Modèle générique d'une étape du tutoriel.
///
/// [highlightTargetKey] : identifiant de l'élément UI à mettre en évidence.
/// [textKey]            : clé de traduction du texte d'instruction.
/// [order]              : position séquentielle dans le tutoriel.
/// [gesture]             : geste doigt animé illustrant l'action à faire.
/// [anchorFraction]      : position (fraction 0..1 de l'écran) où afficher
///                         le geste quand aucune zone en évidence précise
///                         n'est disponible (ex. plateau plein écran) — si
///                         `null`, le centre de la zone en évidence est
///                         utilisé quand elle existe.
class TutorialStep {
  final String highlightTargetKey;
  final String textKey;
  final int order;
  final TutorialGesture gesture;
  final Offset? anchorFraction;

  const TutorialStep({
    required this.highlightTargetKey,
    required this.textKey,
    required this.order,
    this.gesture = TutorialGesture.none,
    this.anchorFraction,
  });
}
