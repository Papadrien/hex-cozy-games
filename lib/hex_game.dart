import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'hex_tile.dart';
import 'hex_painter.dart';

const double kHexSize = 52.0;

class HexGame extends FlameGame
    with PanDetector, ScaleDetector, TapDetector {
  final Map<HexCoord, HexTile> placedTiles = {};
  final List<HexTile> deck = [];
  final Random _rng = Random(42);

  int score = 0;
  VoidCallback? onStateChanged;

  // Camera pan state
  double _zoom = 1.0;
  double _scaleStart = 1.0;
  Vector2 _panStart = Vector2.zero();
  Vector2 _cameraAtPanStart = Vector2.zero();

  @override
  Color backgroundColor() => const Color(0xFFB8D4DC);

  @override
  Future<void> onLoad() async {
    _generateInitialMap();
    _generateDeck();

    camera.viewfinder.zoom = _zoom;
    camera.viewfinder.position = Vector2.zero();

    add(_HexMapComponent(this));
  }

  void _generateInitialMap() {
    final biomeWeights = <Biome, int>{
      Biome.forest: 5,
      Biome.grassland: 4,
      Biome.water: 3,
      Biome.village: 2,
      Biome.desert: 2,
      Biome.mountain: 2,
    };
    final biomePool = <Biome>[];
    biomeWeights.forEach((b, w) {
      for (int i = 0; i < w; i++) biomePool.add(b);
    });

    final frontier = <HexCoord>[const HexCoord(0, 0)];
    final visited = <HexCoord>{};
    Biome currentBiome = Biome.grassland;
    int runLength = 0;

    while (visited.length < 55 && frontier.isNotEmpty) {
      final idx = _rng.nextInt(frontier.length);
      final coord = frontier.removeAt(idx);
      if (visited.contains(coord)) continue;
      visited.add(coord);

      if (runLength <= 0) {
        currentBiome = biomePool[_rng.nextInt(biomePool.length)];
        runLength = 2 + _rng.nextInt(5);
      }
      runLength--;

      placedTiles[coord] = HexTile.uniform(currentBiome);

      for (final n in coord.neighbors) {
        if (!visited.contains(n) && !frontier.contains(n)) {
          frontier.add(n);
        }
      }
    }
  }

  void _generateDeck() {
    final biomes = Biome.values;
    for (int i = 0; i < 30; i++) {
      deck.add(HexTile.uniform(biomes[_rng.nextInt(biomes.length)]));
    }
    deck.shuffle(_rng);
  }

  HexTile? peekNextTile() => deck.isNotEmpty ? deck.last : null;
  int get deckSize => deck.length;

  Set<HexCoord> get emptyNeighbors {
    final result = <HexCoord>{};
    for (final coord in placedTiles.keys) {
      for (final n in coord.neighbors) {
        if (!placedTiles.containsKey(n)) result.add(n);
      }
    }
    return result;
  }

  void placeTile(HexCoord coord) {
    if (deck.isEmpty) return;
    if (placedTiles.containsKey(coord)) return;
    if (!emptyNeighbors.contains(coord)) return;

    final tile = deck.removeLast();
    placedTiles[coord] = tile;

    int matches = 0;
    for (final n in coord.neighbors) {
      final neighbor = placedTiles[n];
      if (neighbor != null && neighbor.biome == tile.biome) matches++;
    }
    score += matches * 10 + 5;

    onStateChanged?.call();
  }

  // --- Pan & Zoom ---

  @override
  void onPanStart(DragStartInfo info) {
    _panStart = info.eventPosition.global.clone();
    _cameraAtPanStart = camera.viewfinder.position.clone();
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    final delta = info.eventPosition.global - _panStart;
    camera.viewfinder.position =
        _cameraAtPanStart - delta / camera.viewfinder.zoom;
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _scaleStart = camera.viewfinder.zoom;
    _panStart = Vector2(
      info.raw.focalPoint.dx,
      info.raw.focalPoint.dy,
    );
    _cameraAtPanStart = camera.viewfinder.position.clone();
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final newZoom = (_scaleStart * info.raw.scale).clamp(0.3, 2.5);
    camera.viewfinder.zoom = newZoom;

    final focal = Vector2(
      info.raw.focalPoint.dx,
      info.raw.focalPoint.dy,
    );
    final delta = focal - _panStart;
    camera.viewfinder.position =
        _cameraAtPanStart - delta / camera.viewfinder.zoom;
  }

  @override
  void onTapUp(TapUpInfo info) {
    final globalPos = info.eventPosition.global;
    final worldPos = camera.viewfinder.position +
        (globalPos - size / 2) / camera.viewfinder.zoom;
    final coord = _pixelToHex(Offset(worldPos.x, worldPos.y));

    if (!placedTiles.containsKey(coord) && emptyNeighbors.contains(coord)) {
      placeTile(coord);
    }
  }

  HexCoord _pixelToHex(Offset pixel) {
    final q = (2 / 3 * pixel.dx) / kHexSize;
    final r = (-1 / 3 * pixel.dx + sqrt(3) / 3 * pixel.dy) / kHexSize;
    return _roundHex(q, r);
  }

  HexCoord _roundHex(double q, double r) {
    double s = -q - r;
    int rq = q.round();
    int rr = r.round();
    int rs = s.round();
    final dq = (rq - q).abs();
    final dr = (rr - r).abs();
    final ds = (rs - s).abs();
    if (dq > dr && dq > ds) {
      rq = -rr - rs;
    } else if (dr > ds) {
      rr = -rq - rs;
    }
    return HexCoord(rq, rr);
  }

  Offset hexToPixel(HexCoord coord) => coord.toPixel(kHexSize);
}

class _HexMapComponent extends Component with HasGameRef<HexGame> {
  _HexMapComponent(HexGame game) : _game = game;
  final HexGame _game;

  @override
  void render(Canvas canvas) {
    final sorted = _game.placedTiles.entries.toList()
      ..sort((a, b) {
        final ya = _game.hexToPixel(a.key).dy;
        final yb = _game.hexToPixel(b.key).dy;
        return ya.compareTo(yb);
      });

    for (final entry in sorted) {
      final pixel = _game.hexToPixel(entry.key);
      HexTilePainter.paint(canvas, entry.value, pixel, kHexSize);
    }

    for (final emptyCoord in _game.emptyNeighbors) {
      final pixel = _game.hexToPixel(emptyCoord);
      _paintEmptyHex(canvas, pixel);
    }
  }

  void _paintEmptyHex(Canvas canvas, Offset center) {
    final path = _hexPath(center, kHexSize);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.15)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
  }

  Path _hexPath(Offset center, double size) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = pi / 180 * (60 * i);
      final x = center.dx + size * cos(angle);
      final y = center.dy + size * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}
