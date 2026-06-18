/// Écran de jeu principal — story 1.2 / 1.3.
///
/// Gestion des gestes :
///  - Pan 1 doigt + Zoom pinch : délégués à Flame via [HexBoardGame]
///    (PanDetector + ScaleDetector). Le [GameWidget] reçoit les gestes
///    directement — pas de GestureDetector Flutter par-dessus pour ne pas
///    interférer avec le multi-touch.
///  - Tap : capturé via [onTapCallback] passé au [HexBoardGame] (Flame
///    TapDetector), pas de GestureDetector Flutter.
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
          // ── Jeu Flame — reçoit TOUS les gestes directement ────────────────
          // Pas de GestureDetector par-dessus : il bloquerait le multi-touch
          // (pan + scale) de Flame. Le tap est géré dans HexBoardGame via
          // TapDetector de Flame.
          GameWidget(game: _game),

          // ── Badge debug ───────────────────────────────────────────────────
          const Positioned(
            top: 48,
            left: 16,
            child: _DebugBadge(label: 'Story 1.3 — Tuiles colorées'),
          ),

          // ── Placeholder HUD pile de tuiles (story 1.4) ────────────────────
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
