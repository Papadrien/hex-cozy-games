import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/snackbar_utils.dart';
import '../providers/progression_provider.dart';

/// Bouton DEBUG (mode debug uniquement)
class HomeDebugButton extends StatelessWidget {
  const HomeDebugButton({super.key, required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 8),
      child: TextButton.icon(
        icon: const Icon(Icons.build, color: Colors.amber, size: 18),
        style: TextButton.styleFrom(
          foregroundColor: Colors.amber.withValues(alpha: 0.6),
        ),
        label: const Text('DEBUG : tout débloquer'),
        onPressed: () async {
          await ref.read(progressionServiceProvider).unlockAllUpgrades();
          if (context.mounted) {
            showAppSnackBar(
              const SnackBar(
                  content: Text('Toutes les améliorations débloquées')),
            );
          }
        },
      ),
    );
  }
}