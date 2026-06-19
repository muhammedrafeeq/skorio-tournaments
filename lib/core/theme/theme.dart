import 'package:flutter/material.dart';
import 'color_scheme.dart';

class SkorioTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SkorioColors.baseBg,
      primaryColor: SkorioColors.primary,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: SkorioColors.primary,
        onPrimary: SkorioColors.onPrimary,
        primaryContainer: SkorioColors.primaryContainer,
        onPrimaryContainer: SkorioColors.onPrimaryContainer,
        secondary: SkorioColors.secondary,
        onSecondary: SkorioColors.onSecondary,
        secondaryContainer: SkorioColors.secondaryContainer,
        onSecondaryContainer: SkorioColors.onSecondaryContainer,
        tertiary: SkorioColors.tertiary,
        onTertiary: SkorioColors.onTertiary,
        tertiaryContainer: SkorioColors.tertiaryContainer,
        onTertiaryContainer: SkorioColors.onTertiaryContainer,
        error: SkorioColors.error,
        onError: SkorioColors.onError,
        errorContainer: SkorioColors.errorContainer,
        onErrorContainer: SkorioColors.onErrorContainer,
        surface: SkorioColors.surface,
        onSurface: SkorioColors.onSurface,
        onSurfaceVariant: SkorioColors.onSurfaceVariant,
        outline: SkorioColors.outline,
        outlineVariant: SkorioColors.outlineVariant,
      ),
      cardTheme: const CardThemeData(
        color: SkorioColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SkorioColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
