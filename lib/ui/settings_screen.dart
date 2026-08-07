/// Écran des Réglages — accessible depuis l'icône settings de l'accueil.
///
/// Regroupe les options son/vibrations (déjà persistées via
/// [optionsProvider]) et le lien "Laisser un avis" (Story rate-us),
/// disponible ici en plus de la bottom sheet automatique proposée après
/// [kReviewPromptGamesThreshold] parties.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/strings.dart';
import '../providers/options_provider.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/review_service.dart';
import '../services/system_ui_service.dart';
import 'glass_container.dart';
import 'screen_app_bar.dart';
import 'tropical_background.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(optionsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: TropicalBackground(
        child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenAppBar(title: context.tr.settings_title),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _SectionLabel(context.tr.settings_sectionAudio),
                      const SizedBox(height: 8),
                      _ToggleTile(
                        icon: Icons.music_note,
                        label: context.tr.options_music,
                        value: options.musicEnabled,
                        onToggle: () {
                          buttonTapFeedback(context);
                          ref.read(optionsProvider.notifier).toggleMusic();
                          ref.read(audioServiceProvider).refreshMusicVolume();
                        },
                      ),
                      _VolumeSliderTile(
                        icon: Icons.music_note,
                        label: context.tr.options_musicVolume,
                        volume: options.musicVolume,
                        onChanged: (value) {
                          ref
                              .read(optionsProvider.notifier)
                              .setMusicVolume(value);
                          ref.read(audioServiceProvider).refreshMusicVolume();
                        },
                        onChangeEnd: (_) => buttonTapFeedback(context),
                      ),
                      _ToggleTile(
                        icon: Icons.graphic_eq,
                        label: context.tr.options_sfx,
                        value: options.sfxEnabled,
                        onToggle: () {
                          buttonTapFeedback(context);
                          ref.read(optionsProvider.notifier).toggleSfx();
                        },
                      ),
                      _VolumeSliderTile(
                        icon: Icons.graphic_eq,
                        label: context.tr.options_sfxVolume,
                        volume: options.sfxVolume,
                        onChanged: (value) {
                          ref
                              .read(optionsProvider.notifier)
                              .setSfxVolume(value);
                        },
                        onChangeEnd: (_) => buttonTapFeedback(context),
                      ),
                      _ToggleTile(
                        icon: Icons.vibration,
                        label: context.tr.options_vibrations,
                        value: options.vibrationEnabled,
                        onToggle: () {
                          buttonTapFeedback(context);
                          ref.read(optionsProvider.notifier).toggleVibration();
                        },
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(context.tr.settings_sectionGeneral),
                      const SizedBox(height: 8),
                      _ToggleTile(
                        icon: Icons.fullscreen,
                        label: context.tr.options_immersiveMode,
                        value: options.immersiveEnabled,
                        onToggle: () {
                          buttonTapFeedback(context);
                          ref.read(optionsProvider.notifier).toggleImmersive();
                          // Applique immédiatement le nouveau mode : le
                          // joueur voit les barres système réapparaître
                          // (ou se masquer) sans redémarrer l'app.
                          applySystemUiMode(!options.immersiveEnabled);
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
                          buttonTapFeedback(context);
                          ref.read(reviewServiceProvider).openStoreListing();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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

/// Ligne réglage avec curseur de volume — module le niveau sonore d'une
/// catégorie (musique ou bruitages), indépendamment de sa bascule on/off.
/// Même esthétique [GlassContainer] que [_ToggleTile] pour rester cohérente
/// avec le reste de l'écran.
class _VolumeSliderTile extends StatelessWidget {
  const _VolumeSliderTile({
    required this.icon,
    required this.label,
    required this.volume,
    required this.onChanged,
    this.onChangeEnd,
  });

  final IconData icon;
  final String label;
  final double volume;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        tintColor: kGlassBlue,
        borderColor: kGlassBlueBorder,
        padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: kTropicalTeal,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                      thumbColor: kTropicalTeal,
                      overlayColor: kTropicalTeal.withValues(alpha: 0.2),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                    ),
                    child: Slider(
                      value: volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: onChanged,
                      onChangeEnd: onChangeEnd,
                    ),
                  ),
                ],
              ),
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
