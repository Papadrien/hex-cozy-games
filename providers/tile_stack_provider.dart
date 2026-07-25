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
import '../game/hex_cell.dart';
import '../game/hex_tile.dart';
import 'build_provider.dart';
import 'grid_state_provider.dart';

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
    this.visibleCount = kVisibleStackSize,
    this.seed,
    this.excludeBiome,
    this.hatedDuration = 0,
    this.hatedStartCount,
    this.hatedActivated = false,
  });

  final int remaining;
  final List<HexTile> visible;
  final int visibleCount;
  final int? seed;

  /// Biome actuellement exclu du pool par l'amélioration "Couleur détestée"
  /// (Story B12b/B12x) — `null` tant que l'amélioration n'a pas été activée
  /// par le joueur (voir [TileStack.activateHatedColor]). Reste inchangé une
  /// fois tiré : seule [hatedDuration] (comparée au nombre de tuiles posées
  /// depuis [hatedStartCount]) détermine si l'exclusion est encore active.
  final BiomeType? excludeBiome;

  /// Nombre de tuiles posées, à partir de l'activation, pendant lesquelles
  /// [excludeBiome] est exclu du pool — 0 si l'amélioration n'est pas
  /// possédée pour cette partie.
  final int hatedDuration;

  /// Nombre de tuiles posées au moment de l'activation de "Couleur
  /// détestée" — `null` tant que l'amélioration n'a pas été activée. Sert
  /// de référence pour calculer combien de tuiles il reste avant la fin de
  /// l'exclusion (voir [upgradeCounterFor]).
  final int? hatedStartCount;

  /// Vrai dès que le joueur a activé "Couleur détestée" pour cette partie
  /// (amélioration à usage unique par partie) — reste vrai même une fois
  /// l'exclusion terminée, pour indiquer que le slot ne peut plus être
  /// réactivé.
  final bool hatedActivated;

  /// La tuile que le joueur va poser ensuite, ou null si la pile est vide.
  HexTile? get activeTile => visible.isEmpty ? null : visible.first;
}

// keepAlive: indispensable — sans ça, ce provider autoDispose se
// réinitialise (build() par défaut, pile "max") entre le moment où
// startNewGame()/restoreSession() le modifient via ref.read (juste avant la
// navigation vers /game) et le moment où GameScreen le watch réellement :
// aucun listener actif entre les deux, Riverpod le dispose et le reconstruit
// depuis zéro, ce qui effaçait le bonus de tuiles de départ et la pile
// restaurée à la reprise. Même traitement que gridProvider/sessionProvider,
// qui partagent le même cycle de vie explicite (invalidate/reset).
@Riverpod(keepAlive: true)
class TileStack extends _$TileStack {
  /// File complète des tuiles restant à tirer, dans l'ordre de tirage.
  /// `visible` est toujours égal aux [kVisibleStackSize] premiers éléments
  /// de cette file (ou moins si la pile est presque épuisée).
  final ListQueue<HexTile> _queue = ListQueue();

  // Biome exclu et durée associés à "Couleur détestée" (Story B12b/B12x) —
  // conservés en champs d'instance (comme _queue) car fixés une seule fois
  // par partie (à l'activation, plus au tirage) mais doivent survivre aux
  // reconstructions de [state] via [_buildState] (consommation de tuiles,
  // Annuler, etc.). NOTE : non restaurés par [restoreQueue] (reprise de
  // partie après redémarrage de l'app) — limitation acceptable pour un
  // badge cosmétique sur une amélioration à usage unique et durée courte
  // (5/8/10 tuiles).
  BiomeType? _excludeBiome;
  int _hatedDuration = 0;
  int? _hatedStartCount;
  bool _hatedActivated = false;

  @override
  TileStackState build() {
    final seed = Random().nextInt(1 << 31);
    final rng = Random(seed);
    final effects = ref.read(activeUpgradeEffectsProvider);
    final visibleCount = max(kVisibleStackSize, effects.extendedPreviewCount);
    // "Couleur détestée" (Story B12x) n'est plus active dès le lancement de
    // la partie : elle démarre inactive et n'est déclenchée que par un tap
    // du joueur en cours de partie, voir [activateHatedColor].
    _excludeBiome = null;
    _hatedDuration = 0;
    _hatedStartCount = null;
    _hatedActivated = false;
    final poolSize = effects.warehouseStartingTiles > 0
        ? effects.warehouseStartingTiles
        : kStartingTiles;
    // Nombre de tuiles déjà posées dans la partie en cours (0 au tout début) —
    // détermine à partir de quelle position les couleurs bonus progressives
    // (Story couleurs déblocables) peuvent apparaître dans le pool généré.
    final placedCount = ref.read(gridProvider).placedTiles.length;
    final pool = generateTilePool(
      poolSize,
      rng,
      startPosition: placedCount + 1,
    );
    _shuffle(pool, rng);
    _queue
      ..clear()
      ..addAll(pool);
    return _buildState(seed: seed, visibleCount: visibleCount);
  }

  /// Active "Couleur détestée" (Story B12x) : tire une couleur au hasard
  /// parmi les couleurs disponibles dès le lancement de la partie (les
  /// couleurs bonus soumises à un palier de tuiles posées, voir
  /// [kBiomeUnlockThresholds], ne peuvent pas être tirées) et l'exclut du
  /// pool pour les [ActiveUpgradeEffects.hatedColorExclusionDuration]
  /// prochaines tuiles à partir de maintenant.
  ///
  /// Amélioration à usage unique par partie : ne fait rien si elle n'est
  /// pas possédée pour ce build ou si elle a déjà été activée.
  void activateHatedColor() {
    if (_hatedActivated) return;
    final effects = ref.read(activeUpgradeEffectsProvider);
    final duration = effects.hatedColorExclusionDuration;
    if (duration <= 0) return;

    final rng = Random();
    final launchBiomes = unlockedBiomesAt(1);
    final biome = launchBiomes[rng.nextInt(launchBiomes.length)];
    final placedCount = ref.read(gridProvider).placedTiles.length;

    // Régénère les prochaines tuiles de la file (pas encore posées) en
    // excluant [biome], pour que l'exclusion s'applique bien à partir de
    // maintenant plutôt que depuis le début de la partie.
    final count = min(duration, _queue.length);
    if (count > 0) {
      final replacementRng =
          Random((state.seed ?? 0) + placedCount + 1);
      final replacement = generateTilePool(
        count,
        replacementRng,
        excludeBiome: biome,
        excludeDuration: count,
        startPosition: placedCount + 1,
      );
      final rest = _queue.skip(count).toList();
      _queue
        ..clear()
        ..addAll(replacement)
        ..addAll(rest);
    }

    _excludeBiome = biome;
    _hatedDuration = duration;
    _hatedStartCount = placedCount;
    _hatedActivated = true;
    state = _buildState();
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
  ///
  /// [startPosition] est la position (1-indexée, dans l'ordre de pose) que
  /// la première tuile de ce pool occupera une fois posée — nécessaire pour
  /// déterminer quelles couleurs bonus progressives sont déjà débloquées.
  List<HexTile> _bonusPool(int count, {required int startPosition}) {
    final bonusSeed = (state.seed ?? 0) + _queue.length + 1;
    final rng = Random(bonusSeed);
    return generateTilePool(count, rng, startPosition: startPosition);
  }

  TileStackState _buildState({int? seed, int? visibleCount}) {
    final vc = visibleCount ?? state.visibleCount;
    return TileStackState(
      remaining: _queue.length,
      visible: List.unmodifiable(_queue.take(vc).toList()),
      visibleCount: vc,
      seed: seed ?? state.seed,
      excludeBiome: _excludeBiome,
      hatedDuration: _hatedDuration,
      hatedStartCount: _hatedStartCount,
      hatedActivated: _hatedActivated,
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
    // Ces tuiles sont insérées en tête de file : elles seront posées juste
    // après les tuiles déjà posées, avant le reste de la pile actuelle.
    final placedCount = ref.read(gridProvider).placedTiles.length;
    final pool = _bonusPool(count, startPosition: placedCount + 1);
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
    // Ces tuiles sont ajoutées en fin de file : elles ne seront posées
    // qu'après les tuiles déjà posées ET le reste de la pile actuelle.
    final placedCount = ref.read(gridProvider).placedTiles.length;
    final startPosition = placedCount + _queue.length + 1;
    final pool = _bonusPool(count, startPosition: startPosition)
        .map((t) => t.copyWith(isBonus: true));
    _queue.addAll(pool);
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
  void restoreQueue(
    List<HexTile> queue, {
    int? seed,
    BiomeType? excludeBiome,
    int hatedDuration = 0,
    int? hatedStartCount,
    bool hatedActivated = false,
  }) {
    _queue
      ..clear()
      ..addAll(queue);
    _excludeBiome = excludeBiome;
    _hatedDuration = hatedDuration;
    _hatedStartCount = hatedStartCount;
    _hatedActivated = hatedActivated;
    final effects = ref.read(activeUpgradeEffectsProvider);
    final visibleCount = max(kVisibleStackSize, effects.extendedPreviewCount);
    state = _buildState(seed: seed ?? state.seed, visibleCount: visibleCount);
  }

  /// Retourne la file complète (pour sérialisation).
  List<HexTile> get queue => List.unmodifiable(_queue.toList());

  /// Réinitialise complètement la pile : efface la file interne et en génère
  /// une nouvelle via [build] (appel explicite pour servir de « reset »
  /// depuis [startNewGame] sans passer par [invalidate] qui ne force pas la
  /// reconstruction immédiate d'un provider [keepAlive]).
  void reset() {
    _queue.clear();
    state = build();
  }
}
