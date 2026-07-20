import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_coords.dart';
import 'grid_state_provider.dart';
import 'placement_commit.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';
import 'upgrade_feedback_provider.dart';

/// Annule le dernier placement.
///
/// [onUndo] : callback pour retirer la tuile du rendu Flame.
void undoPlacement(
  WidgetRef ref, {
  required void Function(HexCoords coords) onUndo,
}) {
  final last = ref.read(lastPlacementProvider);
  if (last == null) return;

  // 1. Retirer du provider de grille (logique pure).
  ref.read(gridProvider.notifier).removeTile(last.coords);

  // 2. Retirer du rendu Flame via le callback.
  onUndo(last.coords);

  // 3. Remettre la tuile au sommet de la pile.
  ref.read(tileStackProvider.notifier).returnTile(last.tile);

  // 4. Annuler les récompenses ET les effets des améliorations (story 1.6b /
  // 1.7c, puis complété pour couvrir Combo+ et la série de connexions) : on
  // restaure directement le snapshot de session pris avant ce placement,
  // plutôt que de soustraire pièces/tuiles bonus un par un — cette
  // soustraction manuelle ne remettait pas à jour currentDoubleStreak
  // (Combo+ se déclenche tous les N doubles connexions cumulées : annuler
  // sans décrémenter ce compteur pouvait donc redéclencher le bonus une
  // tuile trop tôt) ni currentStreak/bestStreak.
  ref.read(sessionProvider.notifier).restore(last.previousSession);
  if (last.bonusTiles > 0) {
    ref.read(tileStackProvider.notifier).removeLastBonusTiles(last.bonusTiles);
  }

  // 5. Effacer le feedback visuel de déclenchement d'amélioration (pulsation
  // sur l'encart des améliorations actives) : il concernait la pose qu'on
  // vient d'annuler et n'a plus lieu d'être affiché.
  ref.read(upgradeFeedbackProvider.notifier).reset();

  // 6. Effacer la mémoire d'annulation (1 seul niveau).
  ref.read(lastPlacementProvider.notifier).set(null);
}
