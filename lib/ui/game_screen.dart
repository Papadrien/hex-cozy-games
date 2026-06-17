/// Écran de jeu principal — story 1.2.
///
/// Architecture des gestes :
///  - Pan / Zoom : gérés par Flame (PanDetector + ScaleDetector dans HexBoardGame)
///  - Tap : GestureDetector Flutter par-dessus le GameWidget, délégué au Game
///    via [HexBoardGame.onTap] pour éviter les conflits de routing Flame.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_board_game.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final HexBoardGame _game = HexBoardGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      body: Stack(
        children: [
          // ── Jeu Flame avec GestureDetector pour les taps ───────────────
          GestureDetector(
            // Le tap est capturé ici et transmis au Game.
            // Les gestes Pan/Scale sont gérés nativement par Flame.
            onTapDown: (details) =>
                _game.onTap(details.localPosition),
            // behavior = translucent pour ne pas bloquer les events Flame
            behavior: HitTestBehavior.translucent,
            child: GameWidget(game: _game),
          ),

          // ── Badge debug story 1.2 ───────────────────────────────────────
          const Positioned(
            top: 48,
            left: 16,
            child: _DebugBadge(label: 'Story 1.2 — Grille hexagonale'),
          ),

          // ── Placeholder HUD pile de tuiles (story 1.4) ─────────────────
          const Positioned(
            top: 48,
            right: 16,
            child: _HudPlaceholder(),
          ),
        ],
      ),
    );
  }
}

class _DebugBadge extends StatelessWidget {
  const _DebugBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// Placeholder visuel pour la zone réservée au HUD pile de tuiles (story 1.4).
/// Sert à valider que le plateau n'est pas masqué par cet espace.
class _HudPlaceholder extends StatelessWidget {
  const _HudPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: const Center(
        child: Text(
          'Pile\n1.4',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 10),
        ),
      ),
    );
  }
}
