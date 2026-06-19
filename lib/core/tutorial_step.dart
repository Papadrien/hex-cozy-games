/// Modèle générique d'une étape du tutoriel.
///
/// [highlightTargetKey] : identifiant de l'élément UI à mettre en évidence.
/// [textKey]            : clé de traduction du texte d'instruction.
/// [order]              : position séquentielle dans le tutoriel.
class TutorialStep {
  final String highlightTargetKey;
  final String textKey;
  final int order;

  const TutorialStep({
    required this.highlightTargetKey,
    required this.textKey,
    required this.order,
  });
}
