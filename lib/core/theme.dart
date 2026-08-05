import 'package:flutter/material.dart';

import 'colors.dart';

/// Thème global de l'application.
///
/// Déclare une palette complète issue des design tokens de [colors.dart] au
/// lieu du seed bleu générique par défaut : [kBrandBlue] pour les accents
/// principaux, [kTropicalTeal] pour les actions secondaires et [kCoinAmber]
/// pour les éléments de valeur (pièces). Les surfaces sombres reprennent le
/// bleu nuit de [kBackgroundColor] pour rester cohérentes avec les fonds
/// glassmorphism des écrans — les composants Material qui n'ont pas de style
/// propre (SnackBars, dialogues, sliders, switches…) héritent ainsi de
/// l'identité visuelle du jeu au lieu du style Material par défaut.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kBrandBlue,
      brightness: brightness,
      primary: kBrandBlue,
      secondary: kTropicalTeal,
      tertiary: kCoinAmber,
      surface: isDark ? kBackgroundColor : const Color(0xFFF7F9FC),
    );

    final rounded12 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? kBackgroundColor : const Color(0xFFF2F6FB),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? kDialogNavy : const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: kTropicalTeal,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
        thumbColor: kTropicalTeal,
        overlayColor: kTropicalTeal.withValues(alpha: 0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: kBrandBlue,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? kTropicalTeal : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? kTropicalTeal.withValues(alpha: 0.5)
              : null,
        ),
        trackOutlineColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.3),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? kBrandBlue
              : Colors.transparent,
        ),
        shape: rounded12,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? kBrandBlue
              : Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}