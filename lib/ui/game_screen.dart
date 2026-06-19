/// Écran de jeu principal — story 1.2 / 1.3 / 1.5a / 1.5b / 1.6b / 1.7g.
///
/// Gestion des gestes :
///  - Pan 1 doigt + Zoom pinch : délégués à Flame via [HexBoardGame]
///    (PanDetector + ScaleDetector). Le [GameWidget] reçoit les gestes
///    directement — pas de GestureDetector Flutter par-dessus pour ne pas
///    interférer avec le multi-touch. Pendant une prévisualisation (story
///    1.5a), le pan vertical sert à la rotation plutôt qu'au déplacement
///    caméra — voir [HexBoardGame].
///  - Tap : capturé via [TapDetector] dans [HexBoardGame] — sélectionne ou
///    déplace la prévisualisation sur un emplacement disponible (1.5a),
///    valide le placement au second tap sur la même cellule (1.5b).
library;

import 'dart:async';

import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../game/hex_board_game.dart';
import '../providers/pause_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/session_provider.dart';
import 'pause_button.dart';
import 'pause_modal.dart';
import 'tile_stack_hud.dart';

/// Durée d'affichage de l'animation de confirmation de récompense (story 1.6b).
const Duration _kConfirmationDuration = Duration(milliseconds: 1500);

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final HexBoardGame _game;
  Timer? _clearRewardTimer;

  @override
  void initState() {
    super.initState();
    _game = HexBoardGame(ref: ref);
  }

  @override
  void dispose() {
    _clearRewardTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PauseState>(pauseProvider, (prev, next) {
      if (prev?.isPaused != next.isPaused) {
        _game.paused = next.isPaused;
      }
    });

    // Auto-effacement de la dernière récompense affichée après le délai.
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next.lastReward != null && prev?.lastReward != next.lastReward) {
        _clearRewardTimer?.cancel();
        _clearRewardTimer = Timer(_kConfirmationDuration, () {
          if (mounted) {
            ref.read(sessionProvider.notifier).clearLastReward();
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      body: Stack(
        children: [
          // ── Jeu Flame — reçoit TOUS les gestes directement ────────────────
          GameWidget(game: _game),

          // ── Badge debug ───────────────────────────────────────────────────
          const Positioned(
            top: 48,
            left: 16,
            child: _DebugBadge(label: 'Story 1.7g — ajout tag bonus'),
          ),

          // ── Compteur de pièces (story 1.6b) ───────────────────────────────
          Positioned(
            top: 80,
            left: 16,
            child: Consumer(builder: (context, ref, _) {
              final session = ref.watch(sessionProvider);
              return Row(children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${session.coins}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]);
            }),
          ),

          // ── Bouton Annuler ──────────────────────────────────────────────
          Consumer(builder: (context, ref, _) {
            final canUndo = ref.watch(lastPlacementProvider) != null;

            return Stack(children: [
              Positioned(
                bottom: 24,
                left: 16,
                child: FloatingActionButton.small(
                  heroTag: 'undo',
                  onPressed: canUndo
                      ? () => undoPlacement(
                            ref,
                            onUndo: _game.removeTileFromFlame,
                          )
                      : null,
                  child: const Icon(Icons.undo),
                ),
              ),
            ]);
          }),

          // ── Bouton Pause ──────────────────────────────────────────────────
          const Positioned(
            top: 48,
            right: 12,
            child: PauseButton(),
          ),

          // ── HUD pile de tuiles + récompenses (story 1.7g) ────────────────
          const Positioned(
            top: 96,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TileStackHud(),
                SizedBox(height: 8),
                _RewardTag(),
              ],
            ),
          ),

          // ── Modale Pause ──────────────────────────────────────────────────
          const PauseModal(),
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

/// Message de récompense affiché sous la pile de tuiles après chaque placement
/// (story 1.7g). Disparaît automatiquement via le timer dans [GameScreen].
class _RewardTag extends ConsumerWidget {
  const _RewardTag();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final reward = session.lastReward;
    if (reward == null) return const SizedBox.shrink();

    final coins = reward.connectedSides.length + reward.bonusTiles;
    final hasBonusTiles = reward.bonusTiles > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                '+$coins${Str.reward_coins}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (hasBonusTiles) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hexagon, color: Colors.lightBlue, size: 14),
                const SizedBox(width: 4),
                Text(
                  '+${reward.bonusTiles}${Str.reward_bonusTiles}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
