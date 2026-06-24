/// Logique de tirage et état de la pile de tuiles — Story 1.4a / 1.9a.
///
/// Le pool de tuiles est généré aléatoirement (Story 1.9a) avec un seed
/// stocké dans l'état pour reproductibilité. La pile expose les
/// [kVisibleStackSize] prochaines tuiles ; la tuile active (première de
/// la pile) est celle que le joueur va poser.
library;

import 'dart:collection';
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
/// [seed] : seed aléatoire utilisé pour générer le pool (reproductibilité).
class TileStackState {
  const TileStackState({
    required this.remaining,
    required this.visible,
    this.seed,
  });

  final int remaining;
  final List<HexTile> visible;
  final int? seed;

  /// La tuile que le joueur va poser ensuite, ou null si la pile est vide.
  HexTile? get activeTile => visible.isEmpty ? null : visible.first;
}

@riverpod
class TileStack extends _$TileStack {
  /// File complète des tuiles restant à tirer, dans l'ordre de tirage.
  /// `visible` est toujours égal aux [kVisibleStackSize] premiers éléments
  /// de cette file (ou moins si la pile est presque épuisée).
  final ListQueue<HexTile> _queue = ListQueue();

  @override
  TileStackState build() {
    final seed = Random().nextInt(1 << 31);
    final rng = Random(seed);
    final pool = generateTilePool(kStartingTiles, rng);
    _shuffle(pool, rng);
    _queue
      ..clear()
      ..addAll(pool);
    return _buildState(seed: seed);
  }

  /// Mélange la file avec Fisher-Yates.
  void _shuffle(List<HexTile> list, [Random? random]) {
    final rng = random ?? Random();
    for (var i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// Génère un petit pool frais pour les tuiles bonus en dérivant le seed.
  List<HexTile> _bonusPool(int count) {
    final bonusSeed = (state.seed ?? 0) + _queue.length + 1;
    final rng = Random(bonusSeed);
    return generateTilePool(count, rng);
  }

  TileStackState _buildState({int? seed}) {
    return TileStackState(
      remaining: _queue.length,
      visible: List.unmodifiable(
        _queue.take(kVisibleStackSize).toList(),
      ),
      seed: seed ?? state.seed,
    );
  }

  /// Consomme et retourne la première tuile de la pile (sans avancer la
  /// pile "visible" pour le joueur — utilisé une seule fois en tout début
  /// de partie pour poser automatiquement la tuile centrale, story du
  /// démarrage avec tuile initiale).
  HexTile? drawInitialTile() {
    if (_queue.isEmpty) return null;
    final tile = _queue.removeFirst();
    state = _buildState();
    return tile;
  }

  /// Consomme la tuile active (première de la pile) et fait avancer la pile.
  ///
  /// Si la pile est épuisée après consommation, le jeu s'arrête
  /// (fin de partie — Story 1.8a). Ne fait plus de ré-alimentation
  /// automatique.
  void consumeActiveTile() {
    if (_queue.isEmpty) return;
    _queue.removeFirst();
    state = _buildState();
  }

  /// Replace [tile] au sommet de la pile (annulation).
  ///
  /// Utilisé par le bouton Annuler pour remettre la dernière tuile posée
  /// en tête de la file _queue, restaurant la pile à l'état précédent.
  void returnTile(HexTile tile) {
    _queue.addFirst(tile);
    state = _buildState();
  }

  /// Ajoute [count] tuiles bonus au début de la file (générées depuis un seed
  /// dérivé).
  ///
  /// Utilisé par le bonus de tuiles de départ de l'amélioration "Tuiles de
  /// départ+" (story 2.8a) : les tuiles sont insérées en tête de file pour
  /// que le joueur les voie immédiatement.
  void addStartingBonusTiles(int count) {
    if (count <= 0) return;
    final pool = _bonusPool(count);
    for (final tile in pool.reversed) {
      _queue.addFirst(tile);
    }
    state = _buildState();
  }

  /// Ajoute [count] tuiles bonus en fin de file (générées depuis un seed
  /// dérivé).
  ///
  /// Utilisé par l'attribution de récompense (story 1.6b) : les tuiles
  /// bonus sont insérées après la file actuelle, le joueur les verra
  /// arriver une fois la file courante épuisée.
  void addBonusTiles(int count) {
    if (count <= 0) return;
    _queue.addAll(_bonusPool(count));
    state = _buildState();
  }

  /// Retire les [count] dernières tuiles de la file (inverse de
  /// [addBonusTiles] — utilisé par le bouton Annuler, story 1.6b).
  void removeLastBonusTiles(int count) {
    if (count <= 0 || _queue.length < count) return;
    for (var i = 0; i < count; i++) {
      _queue.removeLast();
    }
    state = _buildState();
  }

  /// Remplace la file interne par [queue] et restaure le [seed]
  /// (restauration de session).
  void restoreQueue(List<HexTile> queue, {int? seed}) {
    _queue
      ..clear()
      ..addAll(queue);
    state = _buildState(seed: seed ?? state.seed);
  }

  /// Retourne la file complète (pour sérialisation).
  List<HexTile> get queue => List.unmodifiable(_queue.toList());
}
