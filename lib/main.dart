import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';

void main() => runApp(
      MaterialApp(
        home: Scaffold(
          body: GameWidget(
            game: HexPuzzleGame(),
          ),
        ),
      ),
    );

class HexPuzzleGame extends FlameGame
    with
        HasCollisionDetection,
        TapCallbacks,
        ScaleCallbacks,
        DragCallbacks {
  late math.Random random;
  late List<HexTile> hexagons;
  late Camera camera;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    random = math.Random();
    camera = Camera();
    hexagons = [];
    _initializeHexagons();
  }

  void _initializeHexagons() {
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 6; j++) {
        final hex = HexTile(
          gridX: i,
          gridY: j,
          size: 40,
        );
        hexagons.add(hex);
        add(hex);
      }
    }
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    camera.zoom *= info.scale.global.y;
    camera.zoom = math.max(0.5, math.min(3.0, camera.zoom));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    camera.position.subtract(event.delta);
  }

  @override
  void onTapDown(TapDownEvent info) {
    final tapPosition = info.localPosition;
    for (final hex in hexagons) {
      if (hex.contains(tapPosition)) {
        hex.toggleSelect();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
  }

  static const List<math.Point<int>> offsetDirections = [
    math.Point(1, 0),
    math.Point(1, -1),
    math.Point(0, -1),
    math.Point(-1, 0),
    math.Point(-1, 1),
    math.Point(0, 1),
  ];
}

class HexTile extends PositionComponent {
  final int gridX;
  final int gridY;
  final double size;
  late List<math.Point<double>> vertices;
  bool isSelected = false;

  HexTile({
    required this.gridX,
    required this.gridY,
    required this.size,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    position = calculateHexPosition();
    _calculateVertices();
  }

  Vector2 calculateHexPosition() {
    const double hexWidth = 2;
    const double hexHeight = math.pi * 2 / 3;

    final double x = size * (hexWidth * (gridX + 0.5 * gridY));
    final double y = size * (hexHeight * gridY);

    return Vector2(x, y);
  }

  void _calculateVertices() {
    vertices = [];
    for (int i = 0; i < 6; i++) {
      final double angle = math.pi / 3 * i;
      final double x = size * math.cos(angle);
      final double y = size * math.sin(angle);
      vertices.add(math.Point(x, y));
    }
  }

  bool contains(Vector2 point) {
    final double relativeX = point.x - position.x;
    final double relativeY = point.y - position.y;
    final double distance = math.sqrt(relativeX * relativeX + relativeY * relativeY);
    return distance <= size;
  }

  void toggleSelect() {
    isSelected = !isSelected;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()
      ..color = isSelected ? Colors.blue : Colors.grey
      ..style = PaintingStyle.fill;

    final path = Path();
    if (vertices.isNotEmpty) {
      path.moveTo(
        position.x + vertices[0].x.toDouble(),
        position.y + vertices[0].y.toDouble(),
      );
      for (int i = 1; i < vertices.length; i++) {
        path.lineTo(
          position.x + vertices[i].x.toDouble(),
          position.y + vertices[i].y.toDouble(),
        );
      }
      path.close();
    }

    canvas.drawPath(path, paint);

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, strokePaint);
  }
}

class HighlightHex extends PositionComponent {
  final int gridX;
  final int gridY;
  final double size;
  late List<math.Point<double>> vertices;

  HighlightHex({
    required this.gridX,
    required this.gridY,
    required this.size,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    position = calculateHighlightPosition();
    _calculateHighlightVertices();
  }

  Vector2 calculateHighlightPosition() {
    final double angle = math.pi / 3 * gridY;

    final double x = size * math.cos(angle);
    final double y = size * math.sin(angle);

    return Vector2(x, y);
  }

  void _calculateHighlightVertices() {
    vertices = [];
    for (int i = 0; i < 6; i++) {
      final double angle = math.pi / 3 * i;
      final double x = size * math.cos(angle);
      final double y = size * math.sin(angle);
      vertices.add(math.Point(x, y));
    }
  }
}

extension Vector2Extensions on Vector2 {
  Vector2 subtract(Vector2 other) {
    x -= other.x;
    y -= other.y;
    return this;
  }
}
