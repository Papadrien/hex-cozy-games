import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../providers/grid_state_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/session_provider.dart';
import '../providers/tile_stack_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hex Cozy Games',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF6FA8DC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  activeSession.whenData((hasSession) {
                    if (hasSession) {
                      _resumeGame(context, ref);
                    } else {
                      _startNewGame(context, ref);
                    }
                  });
                },
                child: activeSession.when(
                  loading: () => const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  data: (hasSession) => Text(
                    hasSession ? Str.home_resume : Str.home_play,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  error: (_, _) => Text(
                    Str.home_play,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startNewGame(BuildContext context, WidgetRef ref) {
    SessionSaver.endSession(ref);
    ref.invalidate(gridProvider);
    ref.invalidate(tileStackProvider);
    ref.read(sessionProvider.notifier).reset();
    Navigator.pushReplacementNamed(context, '/game');
  }

  void _resumeGame(BuildContext context, WidgetRef ref) async {
    await restoreSession(ref);
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/game');
    }
  }
}
