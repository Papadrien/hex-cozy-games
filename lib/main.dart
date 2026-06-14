import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'hex_game.dart';
import 'hex_painter.dart';
import 'hex_tile.dart';

void main() {
  runApp(const HexWorldApp());
}

class HexWorldApp extends StatelessWidget {
  const HexWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HexWorld',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final HexGame _game;

  @override
  void initState() {
    super.initState();
    _game = HexGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Wrap GameWidget with a GestureDetector to intercept 1-finger pan
          GestureDetector(
            onPanStart: (details) {
              _game.externalPanStart(details.globalPosition);
            },
            onPanUpdate: (details) {
              _game.externalPanUpdate(details.globalPosition);
            },
            onPanEnd: (_) {
              _game.externalPanEnd();
            },
            // Let Flame handle the tap (TapDetector). We only suppress tap
            // when we've detected actual movement.
            behavior: HitTestBehavior.translucent,
            child: GameWidget(game: _game),
          ),
          // HUD
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _HudBar(game: _game),
          ),
          // Next tile preview — bottom right
          Positioned(
            bottom: 24,
            right: 24,
            child: _TileDeck(game: _game),
          ),
          // Instructions — bottom left
          Positioned(
            bottom: 24,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '👆 Glisser pour déplacer\n'
                '🤏 Pincer pour zoomer\n'
                'Toucher une case vide pour poser',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- HUD Bar ----

class _HudBar extends StatefulWidget {
  final HexGame game;
  const _HudBar({required this.game});

  @override
  State<_HudBar> createState() => _HudBarState();
}

class _HudBarState extends State<_HudBar> {
  @override
  void initState() {
    super.initState();
    widget.game.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('🌍 HexWorld',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          Text('Score: ${widget.game.score}',
              style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ---- Tile Deck (next tile preview) ----

class _TileDeck extends StatefulWidget {
  final HexGame game;
  const _TileDeck({required this.game});

  @override
  State<_TileDeck> createState() => _TileDeckState();
}

class _TileDeckState extends State<_TileDeck> {
  @override
  void initState() {
    super.initState();
    widget.game.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.game.peekNextTile();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (next != null) ...[
          // Preview hex — large enough to see clearly
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white30, width: 1.5),
            ),
            child: CustomPaint(
              painter: TilePreviewPainter(next),
            ),
          ),
          const SizedBox(height: 6),
          // Edge legend
          _EdgeLegend(tile: next),
          const SizedBox(height: 8),
        ],
        // Deck count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            '${widget.game.deckSize}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _EdgeLegend extends StatelessWidget {
  final HexTile tile;
  const _EdgeLegend({required this.tile});

  static const _icons = {
    Biome.forest: '🌲',
    Biome.grassland: '🌿',
    Biome.water: '💧',
    Biome.village: '🏠',
    Biome.desert: '🏜',
    Biome.mountain: '⛰',
  };

  @override
  Widget build(BuildContext context) {
    final counts = <Biome, int>{};
    for (final e in tile.edges) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    // Also show center if different
    if (!counts.containsKey(tile.center)) {
      counts[tile.center] = 0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tuile suivante',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          ...counts.entries.map((e) {
            final isCenterOnly = e.value == 0;
            return Text(
              isCenterOnly
                  ? '${_icons[e.key]} centre'
                  : '${_icons[e.key]} ×${e.value}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            );
          }),
        ],
      ),
    );
  }
}
