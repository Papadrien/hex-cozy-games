// Tests unitaires pour les coordonnées hexagonales et le layout — Story 1.2.
//
// Vérifie :
//  - HexCoords.neighbors retourne les 6 voisins avec des coordonnées valides
//  - distanceTo est symétrique et cohérente avec l'hex central
//  - == et hashCode fonctionnent pour l'utilisation en clé de Map/Set
//  - HexLayout.hexToPixel / pixelToHex roundtrip (précision à la cellule près)
//  - hexCorners produit exactement 6 sommets fermant un polygone

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:hex_cozy_games/game/hex_coords.dart';

void main() {
  group('HexCoords', () {
    test('neighbors retourne 6 voisins distincts centrés sur (0,0)', () {
      final center = HexCoords(0, 0);
      final neighbors = center.neighbors;

      expect(neighbors.length, 6);
      // Chaque voisin doit être à distance 1 du centre
      for (final n in neighbors) {
        expect(center.distanceTo(n), 1);
      }
      // Tous distincts
      expect(neighbors.toSet().length, 6);
    });

    test('neighbors sont cohérents : chaque voisin a (0,0) comme voisin', () {
      final center = HexCoords(0, 0);
      for (final n in center.neighbors) {
        expect(n.neighbors.contains(center), isTrue);
      }
    });

    test('distanceTo est symétrique', () {
      final a = HexCoords(2, -3);
      final b = HexCoords(-1, 4);
      expect(a.distanceTo(b), b.distanceTo(a));
    });

    test('distanceTo (0,0) → (2, -1) vaut 2', () {
      expect(HexCoords(0, 0).distanceTo(HexCoords(2, -1)), 2);
    });

    test('distanceTo (0,0) → (3, -3) vaut 3', () {
      expect(HexCoords(0, 0).distanceTo(HexCoords(3, -3)), 3);
    });

    test('== et hashCode permettent l\'utilisation en clé de Set', () {
      final set = <HexCoords>{HexCoords(1, 2)};
      expect(set.contains(HexCoords(1, 2)), isTrue);
      expect(set.contains(HexCoords(2, 1)), isFalse);
    });

    test('s = -q - r pour tous les voisins de (0,0)', () {
      for (final n in HexCoords(0, 0).neighbors) {
        expect(n.s, -n.q - n.r);
      }
    });
  });

  group('HexLayout', () {
    const hexSize = 44.0;
    const origin = Point<double>(200.0, 300.0);
    final layout = HexLayout(hexSize: hexSize, origin: origin);

    test('hexToPixel / pixelToHex roundtrip sur plusieurs cellules', () {
      final testCells = [
        HexCoords(0, 0),
        HexCoords(3, -1),
        HexCoords(-2, 4),
        HexCoords(5, -5),
        HexCoords(-3, 0),
      ];
      for (final cell in testCells) {
        final pixel = layout.hexToPixel(cell);
        final roundtripped = layout.pixelToHex(pixel);
        expect(roundtripped, cell);
      }
    });

    test('hexCorners retourne exactement 6 sommets', () {
      final center = Point<double>(100.0, 100.0);
      final corners = layout.hexCorners(center);

      expect(corners.length, 6);
      // Chaque sommet doit être à distance hexSize du centre
      for (final c in corners) {
        final dx = c.x - center.x;
        final dy = c.y - center.y;
        final dist = (dx * dx + dy * dy);
        // Tolérance pour les erreurs flottantes
        expect(dist, closeTo(hexSize * hexSize, 0.01));
      }
    });
  });
}

