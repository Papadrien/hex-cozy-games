import 'package:flutter/material.dart';

import 'glass_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON NAV (Quêtes / Stats)
// ─────────────────────────────────────────────────────────────────────────────

class HomeNavButton extends StatelessWidget {
  const HomeNavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GlassButton(
          onPressed: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (showBadge)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
