/// Modale de Pause — Story 1.5bis-a / 1.5bis-b.
///
/// Overlay plein écran semi-transparent affiché lorsque [pauseProvider]
/// signale `isPaused == true`.
///
/// Contenu (écran principal) :
///  1. Bouton **Reprendre**         → ferme la modale, reprend le jeu.
///  2. Bouton **Options**            → affiche/masque les toggles Son &
///                                     Vibrations dans la même modale.
///  3. Bouton **Sauvegarder et quitter** → retour à l'accueil, partie
///                                         reprenable (state gardé en
///                                         mémoire via keepAlive providers).
///  4. Bouton **Abandonner**          → popup de confirmation, puis
///                                      termine la session et retour
///                                      à l'accueil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../providers/grid_state_provider.dart';
import '../providers/options_provider.dart';
import '../providers/pause_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/session_provider.dart';
import '../providers/tile_stack_provider.dart';

class PauseModal extends ConsumerWidget {
  const PauseModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pause = ref.watch(pauseProvider);
    if (!pause.isPaused) return const SizedBox.shrink();

    return Stack(
      children: [
        GestureDetector(
          onTap: () {}, // bloque les taps vers le jeu en dessous
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),
        Center(
          child: SingleChildScrollView(
            child: _PauseCard(showOptions: pause.showOptions),
          ),
        ),
      ],
    );
  }
}

class _PauseCard extends ConsumerWidget {
  const _PauseCard({required this.showOptions});

  final bool showOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 48),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showOptions)
            _OptionsContent()
          else
            _MainContent(),
        ],
      ),
    );
  }
}

class _MainContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _ResumeButton(),
        const SizedBox(height: 12),
        _OptionsButton(),
        const SizedBox(height: 12),
        _SaveAndQuitButton(),
        const SizedBox(height: 12),
        _AbandonButton(),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _OptionsContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(optionsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OptionToggle(
          label: context.tr.options_sound,
          value: options.soundEnabled,
          onToggle: () => ref.read(optionsProvider.notifier).toggleSound(),
        ),
        const SizedBox(height: 16),
        _OptionToggle(
          label: context.tr.options_vibrations,
          value: options.vibrationEnabled,
          onToggle: () => ref.read(optionsProvider.notifier).toggleVibration(),
        ),
        const SizedBox(height: 24),
        _ResumeButton(),
        const SizedBox(height: 12),
        _BackButton(),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _OptionToggle extends StatelessWidget {
  const _OptionToggle({
    required this.label,
    required this.value,
    required this.onToggle,
  });

  final String label;
  final bool value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              color: value
                  ? kBrandBlue
                  : Colors.white.withValues(alpha: 0.35),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: kBrandBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          ref.read(pauseProvider.notifier).resume();
        },
        child: Text(
          context.tr.pause_resume,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _OptionsButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: Colors.white.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
        onPressed: () {
          ref.read(pauseProvider.notifier).toggleOptions();
        },
        child: Text(
          context.tr.pause_options,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _BackButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: Colors.white.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          ref.read(pauseProvider.notifier).toggleOptions();
        },
        child: const Text(
          '← Retour',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

class _SaveAndQuitButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: Colors.white.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
        onPressed: () async {
          await SessionSaver.save(ref);
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        child: Text(
          context.tr.pause_saveAndQuit,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _AbandonButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: kDestructiveRed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () => _showAbandonConfirmDialog(context, ref),
        child: Text(
          context.tr.pause_abandon,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

Future<void> _showAbandonConfirmDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: kBackgroundColor,
      title: Text(
        context.tr.pause_abandonConfirmTitle,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Text(
        context.tr.pause_abandonConfirmBody,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            context.tr.pause_abandonConfirmCancel,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _abandonGame(context, ref);
          },
          child: Text(
            context.tr.pause_abandonConfirmConfirm,
            style: const TextStyle(color: kDestructiveRed),
          ),
        ),
      ],
    ),
  );
}

void _abandonGame(BuildContext context, WidgetRef ref) {
  SessionSaver.endSession(ref);
  ref.read(sessionProvider.notifier).reset();
  ref.read(lastPlacementProvider.notifier).set(null);
  ref.invalidate(gridProvider);
  ref.invalidate(tileStackProvider);
  Navigator.pushReplacementNamed(context, '/');
}
