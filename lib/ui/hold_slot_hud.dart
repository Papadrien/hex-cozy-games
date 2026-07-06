/// Encart HUD de l'Emplacement Joker (Hold) — Story B10.
///
/// Affiche un emplacement dédié permettant d'échanger la tuile active avec
/// une tuile en réserve (voir [swapHoldSlot]). N'apparaît que si
/// l'amélioration "Emplacement Joker" est débloquée (niveau ≥ 1).
library;

import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../game/hex_tile.dart';
import '../game/tile_component.dart' show BiomeColor;
import '../providers/build_provider.dart';
import '../providers/hold_slot_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/session_provider.dart';
import '../providers/tile_stack_provider.dart';
import '../services/haptics_service.dart';

const double _kSlotSize = 48.0;
const double _kTileRadius = 18.0;

// Même teinte glassmorphism teal que le reste du HUD de jeu.
const Color _kHudGlass = kTropicalTeal;
const Color _kHudGlassBorder = Color(0xFF3DBFAF);

class HoldSlotHud extends ConsumerWidget {
  const HoldSlotHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(activeUpgradeEffectsProvider);
    if (effects.holdSlotUses <= 0) return const SizedBox.shrink();

    final remainingUses =
        ref.watch(sessionProvider.select((s) => s.holdSlotRemainingUses));
    final heldTile =
        ref.watch(holdSlotProvider.select((s) => s.heldTile));
    final hasActiveTile =
        ref.watch(tileStackProvider.select((s) => s.activeTile != null));

    final canSwap =
        remainingUses > 0 && (hasActiveTile || heldTile != null);

    return Tooltip(
      message: context.tr.game_holdSlot_tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: _kHudGlass.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: canSwap
                  ? () {
                      buttonHapticTap(context);
                      swapHoldSlot(ref);
                    }
                  : null,
              child: Container(
                width: _kSlotSize,
                height: _kSlotSize,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _kHudGlassBorder.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: canSwap ? 1.0 : 0.4,
                      child: heldTile != null
                          ? _HeldTilePreview(tile: heldTile)
                          : const Icon(
                              Icons.swap_horiz,
                              color: Colors.white70,
                              size: 24,
                            ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: _UsesBadge(remaining: remainingUses),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aperçu miniature de la tuile en réserve — même logique de rendu que la
/// pile de tuiles (`tile_stack_hud.dart`), volontairement dupliquée en plus
/// petit pour éviter de coupler les deux HUDs.
class _HeldTilePreview extends StatelessWidget {
  const _HeldTilePreview({required this.tile});

  final HexTile tile;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(_kTileRadius * sqrt(3), _kTileRadius * 2),
      painter: _HeldTilePainter(tile: tile),
    );
  }
}

class _HeldTilePainter extends CustomPainter {
  const _HeldTilePainter({required this.tile});

  final HexTile tile;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2;
    final corners = List.generate(6, (i) {
      final angleRad = (60.0 * i - 90.0) * pi / 180.0;
      return Offset(
        center.dx + radius * cos(angleRad),
        center.dy + radius * sin(angleRad),
      );
    });

    for (var i = 0; i < 6; i++) {
      final c0 = corners[i];
      final c1 = corners[(i + 1) % 6];
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = tile.sides[i].color);
    }

    final outline = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (var i = 1; i < 6; i++) {
      outline.lineTo(corners[i].dx, corners[i].dy);
    }
    outline.close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HeldTilePainter old) => old.tile != tile;
}

class _UsesBadge extends StatelessWidget {
  const _UsesBadge({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: remaining > 0
            ? _kHudGlass.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        '$remaining',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
