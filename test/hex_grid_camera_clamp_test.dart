/// Test pour [HexGridComponent.clampCameraOffset] — empêche le centre du
/// plateau (0, 0) de sortir de l'écran pendant le pan, qui faisait perdre
/// le joueur.
///
/// Le centre (0, 0) est projeté à l'écran en
/// `cameraOffset + screenSize * (0.5, 0.5)` (voir [HexGridComponent._layout]
/// / [HexLayout.hexToPixel]) : ces tests vérifient que cette position reste
/// toujours à l'intérieur de l'écran (avec la marge de confort) quel que
/// soit le pan appliqué.
library;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hex_haven/game/hex_coords.dart';
import 'package:hex_haven/game/hex_grid_component.dart';

/// Reproduit la projection écran du centre (0, 0), telle que définie par
/// [HexGridComponent._layout] (origin = cameraOffset + screenSize * (0.5, 0.5)).
Vector2 _centerScreenPos(HexGridComponent grid) => Vector2(
      grid.cameraOffset.x + grid.screenSize.x * 0.5,
      grid.cameraOffset.y + grid.screenSize.y * 0.5,
    );

void main() {
  group('HexGridComponent.clampCameraOffset', () {
    test('un pan modeste, resté dans les limites, n\'est pas altéré', () {
      final grid = HexGridComponent(screenSize: Vector2(400, 800));
      grid.cameraOffset = Vector2(20, -15);

      grid.clampCameraOffset();

      expect(grid.cameraOffset.x, 20);
      expect(grid.cameraOffset.y, -15);
      final center = _centerScreenPos(grid);
      expect(center.x, inInclusiveRange(0, 400));
      expect(center.y, inInclusiveRange(0, 800));
    });

    test('un pan très large vers la droite/bas est clampé : le centre '
        'reste visible à l\'écran', () {
      final grid = HexGridComponent(screenSize: Vector2(400, 800));
      grid.cameraOffset = Vector2(5000, 5000);

      grid.clampCameraOffset();

      final center = _centerScreenPos(grid);
      expect(center.x, inInclusiveRange(0, 400));
      expect(center.y, inInclusiveRange(0, 800));
    });

    test('un pan très large vers la gauche/haut (offsets négatifs) est '
        'clampé : le centre reste visible à l\'écran', () {
      final grid = HexGridComponent(screenSize: Vector2(400, 800));
      grid.cameraOffset = Vector2(-5000, -5000);

      grid.clampCameraOffset();

      final center = _centerScreenPos(grid);
      expect(center.x, inInclusiveRange(0, 400));
      expect(center.y, inInclusiveRange(0, 800));
    });

    test('le clamp s\'applique après un zoom arrière (marge plus grande)',
        () {
      final grid = HexGridComponent(screenSize: Vector2(400, 800));
      grid.zoom = HexGridComponent.minZoom;
      // Juste dans les limites au zoom précédent (1.0), potentiellement
      // hors limites une fois la marge mise à l'échelle du nouveau zoom.
      grid.cameraOffset = Vector2(150, 470);

      grid.clampCameraOffset();

      final center = _centerScreenPos(grid);
      expect(center.x, inInclusiveRange(0, 400));
      expect(center.y, inInclusiveRange(0, 800));
    });

    test('un écran minuscule (marge > taille écran) ne plante pas', () {
      final grid = HexGridComponent(screenSize: Vector2(10, 10));
      grid.cameraOffset = Vector2(500, 500);

      expect(() => grid.clampCameraOffset(), returnsNormally);
    });

    test('des pans répétés dans la même direction convergent vers la '
        'limite au lieu de continuer à s\'éloigner', () {
      final grid = HexGridComponent(screenSize: Vector2(400, 800));

      for (var i = 0; i < 20; i++) {
        grid.cameraOffset.add(Vector2(200, 200));
        grid.clampCameraOffset();
      }

      final center = _centerScreenPos(grid);
      expect(center.x, inInclusiveRange(0, 400));
      expect(center.y, inInclusiveRange(0, 800));
    });
  });

  group(
      'HexGridComponent.previewScreenCenter '
      '(ancre de la rotation circulaire)', () {
    test('null si aucune tuile en prévisualisation', () {
      final grid = HexGridComponent(screenSize: Vector2(400, 800));
      expect(grid.previewScreenCenter, isNull);
    });

    test('renvoie le centre écran de la tuile prévisualisée en (0,0)', () {
      final grid = HexGridComponent(screenSize: Vector2(400, 800));
      grid.previewCoords = const HexCoords(0, 0);

      // Le centre (0,0) est projeté à l'origine de la grille, elle-même au
      // centre de l'écran (voir HexGridComponent._layout), inchangée tant
      // que cameraOffset == 0.
      final center = grid.previewScreenCenter;
      expect(center, isNotNull);
      expect(center!.x, closeTo(400 * 0.5, 0.01));
      expect(center.y, closeTo(800 * 0.5, 0.01));
    });

    test('suit le pan (cameraOffset) de la grille', () {
      final grid = HexGridComponent(screenSize: Vector2(400, 800));
      grid.previewCoords = const HexCoords(0, 0);
      grid.cameraOffset = Vector2(50, -30);

      final center = grid.previewScreenCenter!;
      expect(center.x, closeTo(400 * 0.5 + 50, 0.01));
      expect(center.y, closeTo(800 * 0.5 - 30, 0.01));
    });

    test('redevient null une fois la sélection annulée', () {
      final grid = HexGridComponent(screenSize: Vector2(400, 800));
      grid.previewCoords = const HexCoords(1, -1);
      expect(grid.previewScreenCenter, isNotNull);

      grid.previewCoords = null;
      expect(grid.previewScreenCenter, isNull);
    });
  });
}
