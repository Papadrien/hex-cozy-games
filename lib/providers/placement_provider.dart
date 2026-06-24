/// État de prévisualisation du placement — Story 1.5a.
///
/// Pilote la sélection d'un emplacement disponible et la rotation de la
/// tuile active en cours de prévisualisation. La validation du placement
/// (second tap) et le calcul des gains sont traités en story 1.5b — ce
/// provider ne fait QUE de la prévisualisation, il ne pose jamais de tuile
/// sur [gridProvider].
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../game/hex_coords.dart';
import '../game/hex_tile.dart';
import 'grid_state_provider.dart';
import 'tile_stack_provider.dart';

part 'placement_provider.g.dart';

/// État de la prévisualisation de placement en cours.
///
/// [selected] : emplacement actuellement prévisualisé, ou null si aucune
/// sélection (aucun tap encore effectué sur un emplacement disponible).
/// [rotationSteps] : nombre de pas de rotation (60° chacun) appliqués à la
/// tuile active pour cette prévisualisation — remis à 0 à chaque nouvelle
/// sélection d'emplacement (la rotation ne "suit" pas le joueur d'une
/// cellule à l'autre, voir critère d'acceptance : seule la position change).
class PlacementState {
  const PlacementState({this.selected, this.rotationSteps = 0});

  final HexCoords? selected;
  final int rotationSteps;

  bool get hasSelection => selected != null;

  static const _sentinel = Object();

  PlacementState copyWith({Object? selected = _sentinel, Object? rotationSteps = _sentinel}) {
    return PlacementState(
      selected: selected == _sentinel ? this.selected : selected as HexCoords?,
      rotationSteps: rotationSteps == _sentinel ? this.rotationSteps : rotationSteps as int,
    );
  }
}

@riverpod
class Placement extends _$Placement {
  @override
  PlacementState build() => const PlacementState();

  /// Les emplacements actuellement disponibles, calculés à partir de l'état
  /// de grille — toute cellule vide adjacente à une tuile posée (sans
  /// contrainte de compatibilité de biome, story 1.6a).
  Set<HexCoords> get availableCells {
    if (ref.read(tileStackProvider).activeTile == null) return const {};
    final grid = ref.read(gridProvider);
    return grid.availableCellsFor();
  }

  /// Tuile active actuellement prévisualisée, avec la rotation en cours
  /// appliquée. Null si aucune tuile active (pile vide) ou aucune sélection.
  HexTile? get previewTile {
    final activeTile = ref.read(tileStackProvider).activeTile;
    if (activeTile == null || !state.hasSelection) return null;
    return activeTile.rotated(state.rotationSteps);
  }

  /// Sélectionne [coords] comme emplacement de prévisualisation.
  ///
  /// - Si [coords] n'est pas dans [availableCells], ne fait rien (tap sur un
  ///   emplacement indisponible est ignoré).
  /// - Si [coords] est déjà la sélection courante, ne fait rien ici — la
  ///   validation du second tap est gérée en story 1.5b par l'appelant (qui
  ///   distingue "nouveau tap" de "second tap sur la même cellule").
  /// - Sélectionner une AUTRE cellule disponible déplace la prévisualisation
  ///   et réinitialise la rotation à 0 (nouvelle tuile/emplacement = nouvelle
  ///   prévisualisation propre).
  void selectCell(HexCoords coords) {
    if (!availableCells.contains(coords)) return;
    if (state.selected == coords) return;
    state = PlacementState(selected: coords, rotationSteps: 0);
  }

  /// Fait pivoter la prévisualisation de [steps] crans de 60° (positif =
  /// sens horaire). Plusieurs crans peuvent être appliqués en un seul appel
  /// (un swipe rapide/long se traduit par plusieurs steps — voir l'appelant
  /// dans [HexBoardGame]). Ne fait rien si aucune sélection en cours.
  void rotate(int steps) {
    if (!state.hasSelection || steps == 0) return;
    final newSteps = ((state.rotationSteps + steps) % 6 + 6) % 6;
    state = state.copyWith(rotationSteps: newSteps);
  }

  /// Annule la sélection en cours (par ex. si la tuile active change sous
  /// le pied de la prévisualisation, ou après validation en 1.5b).
  void clearSelection() {
    if (!state.hasSelection) return;
    state = const PlacementState();
  }
}
