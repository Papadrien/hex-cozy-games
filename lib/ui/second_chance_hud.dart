/// Bouton HUD de Deuxième chance — Story B11.
///
/// Bascule le mode sélection ([toggleSecondChanceMode]) : une fois actif,
/// le prochain tap sur une tuile posée du plateau la retire et la réinjecte
/// en tête de pile (interception faite dans [HexBoardGame.onTapUp]).
/// N'apparaît que si l'amélioration "Deuxième chance" est débloquée
/// (niveau ≥ 1).
library;

import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../providers/build_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/second_chance_provider.dart';
import '../providers/session_provider.dart';
import '../services/haptics_service.dart';

const double _kButtonSize = 48.0;

// Même teinte glassmorphism teal que le reste du HUD de jeu ; le mode actif
// bascule vers un accent ambre pour bien signaler l'état spécial.
const Color _kHudGlass = kTropicalTeal;
const Color _kHudGlassBorder = Color(0xFF3DBFAF);
const Color _kActiveGlass = Color(0xFFFFB300);
const Color _kActiveBorder = Color(0xFFFFD54F);

class SecondChanceHud extends ConsumerWidget {
  const SecondChanceHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(activeUpgradeEffectsProvider);
    if (effects.secondChanceUses <= 0) return const SizedBox.shrink();

    final remainingUses =
        ref.watch(sessionProvider.select((s) => s.secondChanceRemainingUses));
    final isActive = ref.watch(secondChanceModeProvider);

    // Bouton toujours cliquable si actif (pour pouvoir annuler), sinon
    // seulement s'il reste des utilisations.
    final canTap = isActive || remainingUses > 0;

    return Tooltip(
      message: isActive
          ? context.tr.game_secondChance_tooltipActive
          : context.tr.game_secondChance_tooltip,
        child: GlassContainer(
          tintColor: isActive ? _kActiveGlass : _kHudGlass,
          tintAlpha: 0.28,
          borderColor: (isActive ? _kActiveBorder : _kHudGlassBorder)
              .withValues(alpha: 0.6),
          borderWidth: isActive ? 1.5 : 1,
          width: _kButtonSize,
          height: _kButtonSize,
          padding: const EdgeInsets.all(4),
          onTap: canTap
              ? () {
                  buttonHapticTap(context);
                  toggleSecondChanceMode(ref);
                }
              : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
                    Opacity(
                      opacity: canTap ? 1.0 : 0.4,
                      child: Icon(
                        isActive ? Icons.close : Icons.replay,
                        color: Colors.white,
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
    );
  }
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
