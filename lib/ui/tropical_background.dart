import 'package:flutter/material.dart';

/// Fond tropical partagé par tous les écrans de l'application.
///
/// [showVeil] ajoute le voile bleuté caractéristique des écrans secondaires
/// (build, shop, quests, stats, settings). L'écran d'accueil l'utilise
/// sans voile.
class TropicalBackground extends StatelessWidget {
  const TropicalBackground({
    super.key,
    this.showVeil = true,
    required this.child,
  });

  final bool showVeil;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/home_background.png',
          fit: BoxFit.cover,
        ),
        if (showVeil)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D1B3E).withValues(alpha: 0.72),
                  const Color(0xFF0A1628).withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
        child,
      ],
    );
  }
}
