import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_coords.dart';
import 'grid_state_provider.dart';
import 'placement_provider.dart';
import 'second_chance_provider.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';

/// Active ou désactive le mode sélection de Deuxième chance (Story B11).
///
/// Activer le mode annule toute prévisualisation de placement en cours :
/// les deux modes sont mutuellement exclusifs (un tap sur le plateau ne
/// peut pas à la fois valider un placement et retirer une tuile). Ne fait
/// rien à l'activation si aucune utilisation ne reste pour cette partie
/// (Story B9) ; la désactivation, elle, est toujours possible (annulation).
void toggleSecondChanceMode(WidgetRef ref) {
  final notifier = ref.read(secondChanceModeProvider.notifier);
  if (ref.read(secondChanceModeProvider)) {
    notifier.cancel();
    return;
  }
  if (ref.read(sessionProvider).secondChanceRemainingUses <= 0) return;
  ref.read(placementProvider.notifier).clearSelection();
  notifier.activate();
}

/// Active "Couleur détestée" (Story B12x) sur tap du slot dans l'encart des
/// améliorations actives — voir [TileStack.activateHatedColor]. Amélioration
/// à usage unique par partie : le slot n'appelle cette fonction que tant
/// qu'elle n'a pas déjà été activée (voir `active_upgrades_hud.dart`).
void activateHatedColor(WidgetRef ref) {
  ref.read(tileStackProvider.notifier).activateHatedColor();
}

/// Retire la tuile posée en [coords] du plateau et la réinjecte en tête de
/// pile (Story B11 — Deuxième chance).
///
/// [onRemove] : callback pour retirer la tuile du rendu Flame (même
/// signature que le callback [onUndo] de [undoPlacement]).
///
/// Ne fait rien si aucune utilisation ne reste pour cette partie, ou si
/// aucune tuile n'est posée à [coords] (tap dans le vide pendant le mode
/// sélection — le mode reste actif, ce n'est pas une annulation).
///
/// Contrairement à [undoPlacement], les récompenses déjà gagnées pour cette
/// tuile (pièces, tuiles bonus, série de connexions) ne sont PAS reprises :
/// Deuxième chance permet de replacer une tuile existante ailleurs ou
/// autrement tournée, pas d'annuler l'action passée dans son ensemble — à
/// la différence du bouton Annuler, la tuile visée peut avoir été posée il
/// y a plusieurs coups, et ses récompenses peuvent depuis s'être mêlées à
/// celles d'autres tuiles connectées. Défaire cela proprement nécessiterait
/// de rejouer tout l'historique des connexions, ce qui dépasse le
/// périmètre de cette story.
void removePlacedTile(
  WidgetRef ref,
  HexCoords coords, {
  required void Function(HexCoords coords) onRemove,
}) {
  final session = ref.read(sessionProvider);
  if (session.secondChanceRemainingUses <= 0) return;

  final tile = ref.read(gridProvider).tileAt(coords);
  if (tile == null) return;

  // 1. Retirer du provider de grille (logique pure).
  ref.read(gridProvider.notifier).removeTile(coords);

  // 2. Retirer du rendu Flame via le callback.
  onRemove(coords);

  // 3. Remettre la tuile au sommet de la pile.
  ref.read(tileStackProvider.notifier).returnTile(tile);

  // 4. Consommer une utilisation (Story B9).
  ref.read(sessionProvider.notifier).consumeSecondChance();

  // 5. Sortir du mode sélection : le retrait est terminé.
  ref.read(secondChanceModeProvider.notifier).cancel();
}
