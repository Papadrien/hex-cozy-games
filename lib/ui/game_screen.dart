/// Écran de jeu principal — story 1.2 / 1.3 / 1.5a.
///
/// Gestion des gestes :
///  - Pan 1 doigt + Zoom pinch : délégués à Flame via [HexBoardGame]
///    (PanDetector + ScaleDetector). Le [GameWidget] reçoit les gestes
///    directement — pas de GestureDetector Flutter par-dessus pour ne pas
///    interférer avec le multi-touch. Pendant une prévisualisation (story
///    1.5a), le pan vertical sert à la rotation plutôt qu'au déplacement
///    caméra — voir [HexBoardGame].
///  - Tap : capturé via [TapDetector] dans [HexBoardGame] — sélectionne ou
///    déplace la prévisualisation sur un emplacement disponible.
library;

import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hex_board_game.dart';
import 'tile_stack_hud.dart';

import '../providers/placement_commit.dart';


class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final HexBoardGame _game;

  @override
  void initState() {
    super.initState();
    // [HexBoardGame] a besoin du Ref pour lire/écrire les providers de
    // placement (story 1.5a) — créé ici plutôt qu'en field initializer,
    // `ref` n'étant disponible qu'à partir de `initState`.
    _game = HexBoardGame(ref: ref);
  }

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
            child: _DebugBadge(label: 'Story 1.5a — Sélection & rotation'),
          ),

          // ── HUD pile de tuiles (story 1.4b) ───────────────────────────────
          // Positionné sous l'emplacement réservé au futur bouton Pause
          // (story 1.5bis-a, pas encore implémenté) — top offset suffisant
          // pour qu'il s'insère au-dessus sans recouvrement.
          
          Consumer(builder:(context,ref,_){
            final reward=ref.watch(previewRewardProvider);
            final canUndo=ref.watch(lastPlacementProvider)!=null;
            return Stack(children:[
              Positioned(bottom:24,left:16,child:FloatingActionButton.small(
                heroTag:'undo',
                onPressed: canUndo?()=>undoPlacement(ref):null,
                child: const Icon(Icons.undo),
              )),
              if(reward.connectedSides.isNotEmpty)
              Positioned(top:180,left:24,child:Row(children:[
                for(final _ in reward.connectedSides)
                  TweenAnimationBuilder(duration: const Duration(milliseconds:350),
                  tween: Tween(begin:1.57,end:0.0),
                  builder:(c,v,ch)=>Transform(transform: Matrix4.identity()..setEntry(3,2,0.001)..rotateX(v),alignment:Alignment.center,child: ch),
                  child: const CircleAvatar(radius:10,child:Icon(Icons.monetization_on,size:12)))
              ])),
              if(reward.bonusTiles>0)
              Positioned(top:220,left:60,child:Row(children:[
                for(int i=0;i<reward.bonusTiles;i++)
                TweenAnimationBuilder(duration: const Duration(milliseconds:350),
                tween: Tween(begin:1.57,end:0.0),
                builder:(c,v,ch)=>Transform(transform: Matrix4.identity()..setEntry(3,2,0.001)..rotateX(v),child:ch),
                child: const Icon(Icons.hexagon,size:18))
              ]))
            ]);
          }),
const Positioned(
            top: 88,
            right: 12,
            child: TileStackHud(),
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

