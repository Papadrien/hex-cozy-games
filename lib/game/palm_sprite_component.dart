/// Composant Flame pour afficher un sprite de palmier sur une tuile — Story 1.10a.
///
/// Utilise les PNG pré-rendus depuis Blender (fond orange retiré) chargés
/// comme [Sprite] Flame. Deux variantes (palm_tree_1.png, palm_tree_2.png)
/// sont disponibles, choisies aléatoirement à la création via [PalmPlacement.variantIndex].
///
/// Le composant est ajouté comme enfant de [TileComponent] pour hériter de
/// la priorité de rendu et de la gestion caméra du plateau.
library;

import 'package:flame/components.dart';

/// Cache statique des sprites chargés — partagé entre tous les palmiers
/// pour ne charger les PNG qu'une seule fois par session.
class PalmSpriteCache {
  PalmSpriteCache._();
  static final PalmSpriteCache instance = PalmSpriteCache._();

  Sprite? _sprite1;
  Sprite? _sprite2;
  bool _loading = false;
  bool _loaded = false;

  /// Précharge les deux sprites palmier. À appeler dans [FlameGame.onLoad].
  Future<void> preload() async {
    if (_loaded || _loading) return;
    _loading = true;
    _sprite1 = await Sprite.load('palm_tree_1.png');
    _sprite2 = await Sprite.load('palm_tree_2.png');
    _loaded = true;
    _loading = false;
  }

  /// Retourne le sprite selon l'index de variante (0 ou 1).
  Sprite? get(int variantIndex) {
    if (!_loaded) return null;
    return variantIndex == 0 ? _sprite1 : _sprite2;
  }
}

/// Un sprite de palmier positionné sur une tuile.
///
/// [worldOffset] : offset en pixels logiques depuis le centre de la tuile,
///                 calculé par [TileComponent] à partir du [PalmPlacement].
/// [displaySize] : taille d'affichage du sprite en px logiques (adapté au zoom).
/// [variantIndex] : 0 → palm_tree_1.png, 1 → palm_tree_2.png.
/// [alphaValue]   : opacité (0.0–1.0), pour la prévisualisation.
class PalmSpriteComponent extends SpriteComponent {
  PalmSpriteComponent({
    required Vector2 worldOffset,
    required Vector2 displaySize,
    required int variantIndex,
    double alphaValue = 1.0,
  })  : _variantIndex = variantIndex,
        _alphaValue = alphaValue,
        super(
          position: worldOffset,
          size: displaySize,
          anchor: Anchor.bottomCenter,
        );

  final int _variantIndex;
  final double _alphaValue;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final s = PalmSpriteCache.instance.get(_variantIndex);
    if (s != null) {
      sprite = s;
    }
    // Opacité via la couleur de paint du SpriteComponent.
    paint.color = paint.color.withValues(alpha: _alphaValue);
  }

  /// Met à jour la taille et la position (lors d'un zoom).
  void updateTransform(Vector2 newOffset, Vector2 newSize) {
    position = newOffset;
    size = newSize;
  }
}
