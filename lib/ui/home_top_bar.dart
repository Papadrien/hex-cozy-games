import 'package:flutter/material.dart';

import '../core/colors.dart';
import '../core/page_transitions.dart';
import '../core/snackbar_utils.dart';
import '../core/strings.dart';
import '../services/haptics_service.dart';
import 'coin_icon.dart';
import 'glass_container.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR  —  badge pièces · icônes settings/shop
// ─────────────────────────────────────────────────────────────────────────────

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.totalCoins});

  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Badge pièces
          _GlassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 18),
                const SizedBox(width: 6),
                Text(
                  '$totalCoins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _GlassIconButton(
            icon: Icons.settings,
            tooltip: context.tr.home_settings,
            onPressed: () {
              buttonTapFeedback(context);
              clearAppSnackBars();
              Navigator.of(context).push(
                BlurFadePageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            icon: Icons.store,
            tooltip: context.tr.home_shop,
            onPressed: () {
              buttonTapFeedback(context);
              clearAppSnackBars();
              Navigator.of(context).push(
                BlurFadePageRoute<void>(builder: (_) => const ShopScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSANTS UTILITAIRES
// ─────────────────────────────────────────────────────────────────────────────

/// Pill glassmorphism (badge pièces)
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      tintColor: kGlassBlue,
      tintAlpha: 0.22,
      borderColor: kGlassBlueBorder,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      blurSigma: 10,
      child: child,
    );
  }
}

/// Bouton icône glassmorphism pour la top bar
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GlassContainer(
        tintColor: kGlassBlue,
        tintAlpha: 0.22,
        borderColor: kGlassBlueBorder,
        borderRadius: 14,
        padding: const EdgeInsets.all(10),
        onTap: onPressed,
        blurSigma: 10,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
