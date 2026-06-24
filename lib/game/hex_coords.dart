/// Coordonnées hexagonales axiales (q, r) — référence : redblobgames.com/grids/hexagons
///
/// Orientation : pointy-top (pointe en haut), adapté au portrait mobile.
/// Le troisième axe cubique s : s = -q - r (calculé à la demande).
library;

import 'dart:math';

/// Coordonnées axiales d'une cellule hexagonale.
class HexCoords {
  const HexCoords(this.q, this.r);

  final int q;
  final int r;

  /// Convertit en coordonnées cubiques (q, s, r) où s = -q - r.
  int get s => -q - r;

  /// Les 6 directions voisines en coordonnées axiales (pointy-top, sens horaire
  /// depuis le nord-est).
  static const List<HexCoords> _directions = [
    HexCoords(1, -1), // 0 : nord-est
    HexCoords(1, 0),  // 1 : est
    HexCoords(0, 1),  // 2 : sud-est
    HexCoords(-1, 1), // 3 : sud-ouest
    HexCoords(-1, 0), // 4 : ouest
    HexCoords(0, -1), // 5 : nord-ouest
  ];

  /// Retourne le voisin dans la direction [direction] (0–5, sens horaire
  /// depuis nord-est).
  HexCoords neighbor(int direction) {
    final d = _directions[direction % 6];
    return HexCoords(q + d.q, r + d.r);
  }

  /// Retourne tous les voisins (6 cellules adjacentes).
  List<HexCoords> get neighbors =>
      List.generate(6, (i) => neighbor(i));

  /// Distance entre deux cellules en coordonnées cubiques.
  int distanceTo(HexCoords other) {
    return ((q - other.q).abs() +
            (r - other.r).abs() +
            (s - other.s).abs()) ~/
        2;
  }

  @override
  bool operator ==(Object other) =>
      other is HexCoords && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);

  @override
  String toString() => 'HexCoords($q, $r)';
}

/// Convertisseur entre coordonnées axiales et pixels, pour une grille
/// pointy-top.
///
/// [hexSize] : rayon du cercle circumscrit de l'hexagone (de centre à sommet).
class HexLayout {
  const HexLayout({required this.hexSize, required this.origin});

  final double hexSize;
  final Point<double> origin; // décalage d'origine en pixels

  /// Largeur d'un hexagone pointy-top.
  double get hexWidth => sqrt(3) * hexSize;

  /// Hauteur d'un hexagone pointy-top.
  double get hexHeight => 2 * hexSize;

  /// Convertit des coordonnées axiales (q, r) en position pixel (centre de
  /// l'hexagone), sans l'offset d'origine.
  /// [isoScaleY] : facteur d'écrasement vertical iso (défaut 1.0 = plat).
  Point<double> hexToPixel(HexCoords hex, {double isoScaleY = 1.0}) {
    final x = hexSize * (sqrt(3) * hex.q + sqrt(3) / 2 * hex.r);
    final y = hexSize * (3.0 / 2.0 * hex.r) * isoScaleY;
    return Point(x + origin.x, y + origin.y);
  }

  /// Convertit une position pixel en coordonnées axiales (arrondies à la
  /// cellule la plus proche).
  /// [isoScaleY] : DOIT correspondre exactement à la valeur utilisée pour le
  /// rendu (voir [hexToPixel]) — sinon le hit-testing serait décalé par
  /// rapport à ce que le joueur voit à l'écran (story 1.5a).
  HexCoords pixelToHex(Point<double> point, {double isoScaleY = 1.0}) {
    final px = point.x - origin.x;
    final py = (point.y - origin.y) / isoScaleY;

    final q = (sqrt(3) / 3 * px - 1.0 / 3.0 * py) / hexSize;
    final r = (2.0 / 3.0 * py) / hexSize;

    return _roundHex(q, r);
  }

  /// Arrondit des coordonnées fractionnaires à la cellule entière la plus
  /// proche, en utilisant la contrainte cubique (q + r + s = 0).
  static HexCoords _roundHex(double fq, double fr) {
    final fs = -fq - fr;

    var rq = fq.round();
    var rr = fr.round();
    var rs = fs.round();

    final dq = (rq - fq).abs();
    final dr = (rr - fr).abs();
    final ds = (rs - fs).abs();

    if (dq > dr && dq > ds) {
      rq = -rr - rs;
    } else if (dr > ds) {
      rr = -rq - rs;
    }

    return HexCoords(rq, rr);
  }

  /// Retourne les 6 sommets d'un hexagone pointy-top centré en [center].
  List<Point<double>> hexCorners(Point<double> center) {
    return List.generate(6, (i) {
      // Pointy-top : premier sommet à 30° (= π/6), puis +60° chacun
      final angleDeg = 60.0 * i - 30.0;
      final angleRad = pi / 180.0 * angleDeg;
      return Point(
        center.x + hexSize * cos(angleRad),
        center.y + hexSize * sin(angleRad),
      );
    });
  }
}
