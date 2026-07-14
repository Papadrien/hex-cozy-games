/// Écran des Réglages — accessible depuis l'icône settings de l'accueil.
///
/// Regroupe les options son/vibrations (déjà persistées via
/// [optionsProvider]) et le lien "Laisser un avis" (Story rate-us),
/// disponible ici en plus de la bottom sheet automatique proposée après
/// [kReviewPromptGamesThreshold] parties.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../providers/options_provider.dart';
import '../services/haptics_service.dart';
import '../services/review_service.dart';
import 'glass_container.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(optionsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/home_background.png',
            fit: BoxFit.cover,
          ),
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
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsAppBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _SectionLabel(context.tr.settings_sectionAudio),
                      const SizedBox(height: 8),
                      _ToggleTile(
                        icon: Icons.volume_up,
                        label: context.tr.options_sound,
                        value: options.soundEnabled,
                        onToggle: () {
                          buttonHapticTap(context);
                          ref.read(optionsProvider.notifier).toggleSound();
                        },
                      ),
                      _ToggleTile(
                        icon: Icons.vibration,
                        label: context.tr.options_vibrations,
                        value: options.vibrationEnabled,
                        onToggle: () {
                          buttonHapticTap(context);
                          ref.read(optionsProvider.notifier).toggleVibration();
                        },
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(context.tr.settings_sectionAbout),
                      const SizedBox(height: 8),
                      _ActionTile(
                        icon: Icons.star_rate_rounded,
                        iconColor: kCoinAmber,
                        label: context.tr.settings_rateApp,
                        subtitle: context.tr.settings_rateAppSubtitle,
                        onTap: () {
                          buttonHapticTap(context);
                          ref.read(reviewServiceProvider).openStoreListing();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SettingsGlassIconButton(
            icon: Icons.close,
            onPressed: () {
              buttonHapticTap(context);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 14),
          Text(
            context.tr.settings_title,
            style: GoogleFonts.nunito(
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
        ],
      ),
    );
  }
}

class _SettingsGlassIconButton extends StatelessWidget {
  const _SettingsGlassIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      blurSigma: 10,
      tintColor: kGlassBlue,
      tintAlpha: 0.22,
      borderColor: kGlassBlueBorder,
      padding: const EdgeInsets.all(10),
      onTap: onPressed,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: kBrandBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne réglage avec bascule on/off — même esthétique que
/// `pause_modal.dart`'s `_OptionToggle` (icône de coche pleine/vide), mais
/// intégrée dans une [GlassContainer] pour rester cohérente avec le reste
/// de l'écran (cartes `stats_screen.dart`).
class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onToggle,
  });

  final IconData icon;
  final String label;
  final bool value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        tintColor: kGlassBlue,
        borderColor: kGlassBlueBorder,
        padding: const EdgeInsets.all(14),
        onTap: onToggle,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kBrandBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: kBrandBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              color: value ? kTropicalTeal : Colors.white.withValues(alpha: 0.35),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne d'action tappable (ex. "Laisser un avis") avec sous-titre optionnel
/// et chevron indiquant qu'elle mène vers une action externe.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.subtitle,
  });

  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? kBrandBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        tintColor: kGlassBlue,
        borderColor: kGlassBlueBorder,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.35),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
