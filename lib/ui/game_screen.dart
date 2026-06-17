import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_board_game.dart';
import '../providers/setup_providers.dart';

/// Écran racine de l'app pour la story 1.1 : affiche le `GameWidget` Flame
/// (fond coloré) et un indicateur de statut Riverpod pour valider que les
/// deux systèmes sont bien intégrés ensemble.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riverpodStatus = ref.watch(setupStatusProvider);

    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: HexBoardGame()),
          Positioned(
            top: 48,
            left: 16,
            child: _SetupStatusBadge(label: riverpodStatus),
          ),
        ],
      ),
    );
  }
}

/// Petit badge de debug affichant l'état du setup — sera retiré une fois
/// les premiers vrais écrans (story 1.2+) en place.
class _SetupStatusBadge extends StatelessWidget {
  const _SetupStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
