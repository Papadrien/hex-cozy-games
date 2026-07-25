import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hold_slot_provider.dart';
import 'placement_provider.dart';
import 'session_provider.dart';
import 'tile_stack_provider.dart';

/// Échange la tuile active avec la tuile en réserve de l'Emplacement Joker
/// (Story B10).
///
/// - Aucune tuile en réserve : la tuile active part en réserve, et la
///   suivante de la pile devient la nouvelle tuile active.
/// - Une tuile est déjà en réserve : elle devient la nouvelle tuile active
///   (réinsérée en tête de pile) et l'ancienne tuile active part en réserve
///   à sa place — un échange à double sens.
/// - Pile vide mais tuile en réserve présente : permet de la récupérer même
///   sans tuile active à lui opposer.
///
/// Ne fait rien si aucune utilisation ne reste pour cette partie (Story B9)
/// ou s'il n'y a ni tuile active ni tuile en réserve à échanger.
///
/// Note (limite connue, non bloquante) : si la pile ne contenait plus
/// qu'une seule tuile et qu'aucune tuile n'était en réserve, la mettre en
/// réserve vide la pile (`remaining` passe à 0) sans déclencher la fin de
/// partie — elle attend que le joueur la récupère via un nouvel échange.
/// [_checkGameOver] n'est donc pas appelé ici, à la différence de
/// [confirmPlacement].
///
/// Comportement volontairement asymétrique selon l'état de l'emplacement :
///
///  • Emplacement VIDE (1er clic) : la tuile active est retirée de la pile
///    et mise en réserve — consomme 1 utilisation.
///  • Emplacement PLEIN (2e clic) : la tuile en réserve est remise en tête
///    de la pile (elle devient la nouvelle tuile active, l'ancienne tuile
///    active passant en 2e position) et l'emplacement est vidé — ne
///    consomme AUCUNE utilisation, il ne s'agit pas d'un nouvel échange
///    mais de la simple reprise d'une tuile déjà mise de côté.
void swapHoldSlot(WidgetRef ref) {
  final heldTile = ref.read(holdSlotProvider).heldTile;
  final stackNotifier = ref.read(tileStackProvider.notifier);

  if (heldTile != null) {
    // 2e clic : reprise de la tuile en réserve, gratuite.
    stackNotifier.returnTile(heldTile);
    ref.read(holdSlotProvider.notifier).set(null);
    // La sélection de prévisualisation en cours (le cas échéant) portait
    // sur l'ancienne tuile active : elle n'a plus de sens, la tuile reprise
    // devient la nouvelle tuile active en tête de pile.
    ref.read(placementProvider.notifier).clearSelection();
    return;
  }

  // 1er clic : mise en réserve de la tuile active, coûte 1 utilisation.
  final session = ref.read(sessionProvider);
  if (session.holdSlotRemainingUses <= 0) return;

  final activeTile = ref.read(tileStackProvider).activeTile;
  if (activeTile == null) return;

  stackNotifier.consumeActiveTile();
  ref.read(holdSlotProvider.notifier).set(activeTile);
  ref.read(placementProvider.notifier).clearSelection();
  ref.read(sessionProvider.notifier).consumeHoldSlot();
}
