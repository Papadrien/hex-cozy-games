
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: HexPuzzleGame()));
}

class HexPuzzleGame extends FlameGame with ScaleDetector, DragCallbacks, TapDetector {
  final Random rng = Random();
  final double hexSize = 55;

  final Map<Point<int>, HexTile> tiles = {};
  Point<int>? highlighted;
  late HexTile nextTile;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.zoom = 1.0;

    for (int q = -1; q <= 1; q++) {
      for (int r = -1; r <= 1; r++) {
        tiles[Point(q, r)] = randomTile(q, r);
      }
    }

    nextTile = randomTile(0, 0);
    rebuild();
  }

  HexTile randomTile(int q, int r) {
    final colors = [
      Colors.blue,
      Colors.yellow,
      Colors.green,
      Colors.red,
      Colors.black,
    ];

    final sides = List.generate(6, (_) => colors[rng.nextInt(colors.length)]);
    return HexTile(q, r, hexSize, sides);
  }

  void rebuild() {
    children.whereType<HexTile>().forEach(remove);
    children.whereType<HighlightHex>().forEach(remove);

    for (final t in tiles.values) {
      add(t);
    }

    if (highlighted != null) {
      add(HighlightHex(highlighted!.x, highlighted!.y, hexSize));
    }
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    camera.viewfinder.zoom *= info.scale.global.y;
    camera.viewfinder.zoom =
        camera.viewfinder.zoom.clamp(0.4, 3.0);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    camera.viewfinder.position -= event.localDelta;
  }

  @override
  void update(double dt) {
    super.update(dt);

    highlighted ??= firstFreeSpot();
  }

  Point<int>? firstFreeSpot() {
    const dirs = [
      Point(1, 0),
      Point(1, -1),
      Point(0, -1),
      Point(-1, 0),
      Point(-1, 1),
      Point(0, 1),
    ];

    for (final p in tiles.keys) {
      for (final d in dirs) {
        final n = Point(p.x + d.x, p.y + d.y);
        if (!tiles.containsKey(n)) return n;
      }
    }
    return null;
  }

  @override
  Color backgroundColor() => const Color(0xFF202020);

  @override
  void onTapDown(TapDownInfo info) {
    if (highlighted != null) {
      tiles[highlighted!] = HexTile(
        highlighted!.x,
        highlighted!.y,
        hexSize,
        nextTile.sides,
      );
      nextTile = randomTile(0, 0);
      highlighted = firstFreeSpot();
      rebuild();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    nextTile.position = Vector2(size.x - 120, size.y - 120);
    nextTile.render(canvas);
  }
}

class HexTile extends PositionComponent {
  final int q;
  final int r;
  final double sizeHex;
  final List<Color> sides;

  HexTile(this.q, this.r, this.sizeHex, this.sides);

  @override
  Future<void> onLoad() async {
    position = axialToPixel(q, r, sizeHex);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(position.x, position.y);

    for (int i = 0; i < 6; i++) {
      final a1 = pi / 3 * i - pi / 6;
      final a2 = pi / 3 * (i + 1) - pi / 6;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + cos(a1) * sizeHex, center.dy + sin(a1) * sizeHex)
        ..lineTo(center.dx + cos(a2) * sizeHex, center.dy + sin(a2) * sizeHex)
        ..close();

      canvas.drawPath(path, Paint()..color = sides[i]);
    }

    final border = Path();
    for (int i = 0; i < 6; i++) {
      final a = pi / 3 * i - pi / 6;
      final p = Offset(
        center.dx + cos(a) * sizeHex,
        center.dy + sin(a) * sizeHex,
      );
      if (i == 0) {
        border.moveTo(p.dx, p.dy);
      } else {
        border.lineTo(p.dx, p.dy);
      }
    }
    border.close();
    canvas.drawPath(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

class HighlightHex extends PositionComponent {
  final int q;
  final int r;
  final double sizeHex;

  HighlightHex(this.q, this.r, this.sizeHex);

  @override
  Future<void> onLoad() async {
    position = axialToPixel(q, r, sizeHex);
  }

  @override
  void render(Canvas canvas) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = pi / 3 * i - pi / 6;
      final p = Offset(
        position.x + cos(a) * sizeHex,
        position.y + sin(a) * sizeHex,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white,
    );
  }
}

Vector2 axialToPixel(int q, int r, double size) {
  return Vector2(
    size * sqrt(3) * (q + r / 2),
    size * 1.5 * r,
  );
}
