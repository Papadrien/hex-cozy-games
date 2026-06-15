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
    with TapCallbacks, ScaleCallbacks, DragCallbacks {
  late math.Random random;
  late List<HexTile> hexagons;
  double zoom = 1.0;
  late Vector2 cameraOffset;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    random = math.Random();
    cameraOffset = Vector2.zero();
    hexagons = [];
    _initializeHexagons();
  }

  void _initializeHexagons() {
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 6; j++) {
        final hex = HexTile(
          gridX: i,
          gridY: j,
          hexSize: 40,
        );
        hexagons.add(hex);
        add(hex);
      }
    }
  }

  @override
  void onScaleUpdate(ScaleUpdateEvent event) {
    zoom *= event.scale.global.y;
    zoom = math.max(0.5, math.min(3.0, zoom));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    cameraOffset.subtract(event.localDelta);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final tapPosition = event.localPosition;
    for (final hex in hexagons) {
      if (hex.checkHit(tapPosition)) {
        hex.toggleSelect();
      }
    }
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
  final double hexSize;
  late List<math.Point<double>> vertices;
  bool isSelected = false;

  HexTile({
    required this.gridX,
    required this.gridY,
    required this.hexSize,
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

    final double x = hexSize * (hexWidth * (gridX + 0.5 * gridY));
    final double y = hexSize * (hexHeight * gridY);

    return Vector2(x, y);
  }

  void _calculateVertices() {
    vertices = [];
    for (int i = 0; i < 6; i++) {
      final double angle = math.pi / 3 * i;
      final double x = hexSize * math.cos(angle);
      final double y = hexSize * math.sin(angle);
      vertices.add(math.Point(x, y));
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final double relativeX = point.x;
    final double relativeY = point.y;
    final double distance = math.sqrt(relativeX * relativeX + relativeY * relativeY);
    return distance <= hexSize;
  }

  bool checkHit(Vector2 globalPoint) {
    final localPoint = globalPoint - position;
    return containsLocalPoint(localPoint);
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
        vertices[0].x.toDouble(),
        vertices[0].y.toDouble(),
      );
      for (int i = 1; i < vertices.length; i++) {
        path.lineTo(
          vertices[i].x.toDouble(),
          vertices[i].y.toDouble(),
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
  final double hexSize;
  late List<math.Point<double>> vertices;

  HighlightHex({
    required this.gridX,
    required this.gridY,
    required this.hexSize,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    position = calculateHighlightPosition();
    _calculateHighlightVertices();
  }

  Vector2 calculateHighlightPosition() {
    final double angle = math.pi / 3 * gridY;

    final double x = hexSize * math.cos(angle);
    final double y = hexSize * math.sin(angle);

    return Vector2(x, y);
  }

  void _calculateHighlightVertices() {
    vertices = [];
    for (int i = 0; i < 6; i++) {
      final double angle = math.pi / 3 * i;
      final double x = hexSize * math.cos(angle);
      final double y = hexSize * math.sin(angle);
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
