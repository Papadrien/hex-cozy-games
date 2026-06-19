/// Logique de tirage et état de la pile de tuiles — Story 1.4a.
///
/// Le pool de tuiles ([kTilePool]) est mélangé au départ (Fisher-Yates).
/// La pile expose les [kVisibleStackSize] prochaines tuiles ; la tuile
/// active (première de la pile) est celle que le joueur va poser.
///
/// Pas encore d'UI ici (voir story 1.4b).
library;

import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants.dart';
import '../game/hex_tile.dart';

part 'tile_stack_provider.g.dart';

/// État de la pile de tuiles.
///
/// [remaining] : nombre de tuiles restantes dans la pile, EN COMPTANT les
/// tuiles actuellement visibles (donc `remaining >= visible.length`).
/// [visible] : les [kVisibleStackSize] prochaines tuiles, la première
/// (`visible.first`) étant la tuile active.
class TileStackState {
  const TileStackState({required this.remaining, required this.visible});

  final int remaining;
  final List<HexTile> visible;

  /// La tuile que le joueur va poser ensuite, ou null si la pile est vide.
  HexTile? get activeTile => visible.isEmpty ? null : visible.first;
}

@riverpod
class TileStack extends _$TileStack {
  /// File complète des tuiles restant à tirer, dans l'ordre de tirage.
  /// `visible` est toujours égal aux [kVisibleStackSize] premiers éléments
  /// de cette file (ou moins si la pile est presque épuisée).
  final List<HexTile> _queue = [];

  @override
  TileStackState build() {
    _queue
      ..clear()
      ..addAll(_shuffledPool());
    return _buildState();
  }

  /// Mélange une copie du pool fixe via Fisher-Yates.
  List<HexTile> _shuffledPool({Random? random}) {
    final rng = random ?? Random();
    final shuffled = List<HexTile>.of(kTilePool);
    for (var i = shuffled.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = tmp;
    }
    return shuffled;
  }

  TileStackState _buildState() {
    return TileStackState(
      remaining: _queue.length,
      visible: List.unmodifiable(
        _queue.take(kVisibleStackSize),
      ),
    );
  }

  /// Consomme la tuile active (première de la pile) et fait avancer la pile.
  ///
  /// Si la pile sous-jacente est épuisée, elle est ré-alimentée avec un
  /// nouveau pool mélangé pour que le jeu ne soit jamais à court de tuiles.
  /// Ne fait rien si la pile est vide ET ne peut pas être ré-alimentée
  /// (pool vide — ne devrait jamais arriver en pratique).
  void consumeActiveTile() {
    if (_queue.isEmpty) return;
    _queue.removeAt(0);
    if (_queue.isEmpty && kTilePool.isNotEmpty) {
      _queue.addAll(_shuffledPool());
    }
    state = _buildState();
  }

  /// Replace [tile] au sommet de la pile (annulation).
  ///
  /// Utilisé par le bouton Annuler pour remettre la dernière tuile posée
  /// en tête de la file _queue, restaurant la pile à l'état précédent.
  void returnTile(HexTile tile) {
    _queue.insert(0, tile);
    state = _buildState();
  }

  /// Ajoute [count] tuiles bonus en fin de file (prélevées d'un pool
  /// fraîchement mélangé).
  ///
  /// Utilisé par l'attribution de récompense (story 1.6b) : les tuiles
  /// bonus sont insérées après la file actuelle, le joueur les verra
  /// arriver une fois la file courante épuisée.
  void addBonusTiles(int count) {
    if (count <= 0) return;
    _queue.addAll(_shuffledPool().take(count));
    state = _buildState();
  }

  /// Retire les [count] dernières tuiles de la file (inverse de
  /// [addBonusTiles] — utilisé par le bouton Annuler, story 1.6b).
  void removeLastBonusTiles(int count) {
    if (count <= 0 || _queue.length < count) return;
    _queue.removeRange(_queue.length - count, _queue.length);
    state = _buildState();
  }

  /// Remplace la file interne par [queue] (restauration de session).
  void restoreQueue(List<HexTile> queue) {
    _queue
      ..clear()
      ..addAll(queue);
    state = _buildState();
  }

  /// Retourne la file complète (pour sérialisation).
  List<HexTile> get queue => List.unmodifiable(_queue);
}
