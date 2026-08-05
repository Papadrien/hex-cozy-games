import 'package:flutter/material.dart';

/// Thème global de l'application.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6FA8DC),
        brightness: Brightness.light,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6FA8DC),
        brightness: Brightness.dark,
      );
}
