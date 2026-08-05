import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/game_enums.dart';
import '../core/page_transitions.dart';
import '../core/snackbar_utils.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/progression_provider.dart';
import '../services/haptics_service.dart';
import 'build_screen.dart';
import 'coin_icon.dart';
import 'glass_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON BUILD
// ─────────────────────────────────────────────────────────────────────────────

class HomeBuildButton extends StatelessWidget {
  const HomeBuildButton({
    super.key,
    required this.selected,
    required this.activeSession,
  });

  final List<UpgradeRow> selected;
  final AsyncValue<bool> activeSession;

  @override
  Widget build(BuildContext context) {
    // Tant qu'une partie est à reprendre, on empêche l'accès à la sélection
    // d'améliorations : le choix d'améliorations ne s'applique qu'à une
    // nouvelle partie et ne doit pas pouvoir être modifié pendant qu'une
    // partie en cours attend d'être reprise.
    final hasResumableGame =
        activeSession.maybeWhen(data: (active) => active, orElse: () => false);

    return SizedBox(
      width: double.infinity,
      child: GlassButton(
        // Pas de surcouche — le bleu de base suffit pour ce bouton
        tint: hasResumableGame ? Colors.grey : Colors.transparent,
        onPressed: hasResumableGame
            ? () {
                buttonTapFeedback(context);
                showAppSnackBar(
                  SnackBar(
                    content: Text(context.tr.home_buildSelectionLockedResume),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : () {
                buttonTapFeedback(context);
                clearAppSnackBars();
                Navigator.of(context).push(
                  BlurFadePageRoute<void>(builder: (_) => const BuildScreen()),
                );
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected.isEmpty)
              Icon(
                Icons.build_outlined,
                size: 18,
                color: hasResumableGame
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
              )
            else
              ...selected.map((u) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Opacity(
                      opacity: hasResumableGame ? 0.4 : 1,
                      child: _BuildMiniIcon(
                        effectType: UpgradeEffectType.fromDb(u.effectType),
                        upgradeId: u.id,
                      ),
                    ),
                  )),
            const SizedBox(width: 8),
            if (hasResumableGame)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.lock,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            Flexible(
              child: Text(
                selected.isEmpty
                    ? context.tr.home_buildSelection
                    : '${selected.length} / $kMaxSelectedUpgrades ${context.tr.home_buildSelection}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  color: hasResumableGame
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini icône d'amélioration dans le bouton Build
class _BuildMiniIcon extends StatelessWidget {
  const _BuildMiniIcon({required this.effectType, this.upgradeId});

  final UpgradeEffectType effectType;
  final String? upgradeId;

  @override
  Widget build(BuildContext context) {
    final tintOverride = upgradeIconColor(effectType);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: UpgradeEffectIcon(
        effectType: effectType,
        upgradeId: upgradeId,
        color: tintOverride ?? Colors.white,
        size: 14,
      ),
    );
  }
}
