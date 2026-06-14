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
          GameWidget(game: _game),
          // HUD overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _HudBar(game: _game),
          ),
          // Tile deck bottom right
          Positioned(
            bottom: 24,
            right: 24,
            child: _TileDeck(game: _game),
          ),
          // Instructions bottom left
          Positioned(
            bottom: 24,
            left: 24,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '👆 Glisser pour déplacer\n'
                '🤏 Pincer pour zoomer\n'
                'Appuyer sur une case vide pour poser',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      children: [
        if (next != null) ...[
          // Legend for next tile
          _buildEdgeLegend(next),
          const SizedBox(height: 6),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: CustomPaint(
              painter: TilePreviewPainter(next),
            ),
          ),
        ],
        const SizedBox(height: 8),
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
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// Small legend showing how many edges of each biome are on the next tile
  Widget _buildEdgeLegend(HexTile tile) {
    final counts = <Biome, int>{};
    for (final e in tile.edges) {
      counts[e] = (counts[e] ?? 0) + 1;
    }

    final biomeNames = {
      Biome.forest: ('🌲', 'Forêt'),
      Biome.grassland: ('🌿', 'Prairie'),
      Biome.water: ('💧', 'Eau'),
      Biome.village: ('🏠', 'Village'),
      Biome.desert: ('🏜', 'Désert'),
      Biome.mountain: ('⛰', 'Montagne'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: counts.entries.map((e) {
          final info = biomeNames[e.key]!;
          return Text(
            '${info.$1} ×${e.value}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          );
        }).toList(),
      ),
    );
  }
}
