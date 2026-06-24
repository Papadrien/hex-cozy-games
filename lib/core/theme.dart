import 'package:flutter/material.dart';

/// Thème global de l'application.
///
/// Placeholder MVP — sera enrichi avec les design tokens (AppColors,
/// AppSpacing, AppShadows) lors de la passe de direction artistique
/// (Phase 4, voir 01_contexte_architecture.md section 10).
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6FA8DC),
        brightness: Brightness.light,
      );
}
