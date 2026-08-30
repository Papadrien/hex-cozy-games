import 'package:flutter/material.dart';

import 'glass_container.dart';

/// Barre d'app bar glassmorphism partagée des écrans secondaires (bouton
/// fermer + titre), avec un éventuel widget de fin de ligne (badge…).
class ScreenAppBar extends StatelessWidget {
  const ScreenAppBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Bouton fermer glassmorphism
          GlassIconButton(
            icon: Icons.close,
            size: 20,
            padding: const EdgeInsets.all(10),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
                    ?trailing,
        ],
      ),
    );
  }
}