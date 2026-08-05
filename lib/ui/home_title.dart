import 'package:flutter/material.dart';

import '../core/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TITRE HEX HAVEN  —  maintenant dans la TopBar
// ─────────────────────────────────────────────────────────────────────────────

class HomeTitle extends StatelessWidget {
  const HomeTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "hex" + fleur
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'hex',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
                  child: Image.asset(
                    'assets/images/hibiscus.png',
                    width: 64,
                    height: 64,
                  ),
                ),
              ],
            ),
            // "Haven" en cursif teal
            Text(
              'Haven',
              style: TextStyle(
                fontFamily: 'Pacifico',
                fontSize: 48,
                color: kTropicalTeal,
                height: 0.9,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
