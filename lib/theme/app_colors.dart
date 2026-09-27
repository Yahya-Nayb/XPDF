import 'package:flutter/material.dart';

/// XPDF design tokens — light and dark palettes.
///
/// Use [colorOf] in widgets for theme-aware colors, or read [AppColorScheme]
/// via [schemeOf] when you need several tokens at once.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Light palette
  // ---------------------------------------------------------------------------

  static const Color background = Color(0xFFF4F3F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color secondarySurface = Color(0xFFF7EEF5);
  static const Color textPrimary = Color(0xFF161516);
  static const Color textSecondary = Color(0xFF8A8781);
  static const Color border = Color(0xFFEDEAE4);
  static const Color accent = Color(0xFFEF3F4B);
  static const Color accentTint = Color(0xFFFCE4E6);

  // ---------------------------------------------------------------------------
  // Dark palette
  // ---------------------------------------------------------------------------

  static const Color darkBackground = Color(0xFF0E0E10);
  static const Color darkSurface = Color(0xFF1C1B1E);
  static const Color darkSecondarySurface = Color(0xFF242226);
  static const Color darkTextPrimary = Color(0xFFF2F0ED);
  static const Color darkTextSecondary = Color(0xFF8E8B87);
  static const Color darkBorder = Color(0xFF2E2C30);
  static const Color darkAccent = Color(0xFFFF4A56);
  static const Color darkAccentTint = Color(0xFF3A1E22);

  // ---------------------------------------------------------------------------
  // Layout radii
  // ---------------------------------------------------------------------------

  static const double radiusCard = 15;
  static const double radiusChip = 9;
  static const double radiusButton = 28;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static AppColorScheme schemeOf(BuildContext context) {
    final dark = isDark(context);
    return AppColorScheme(
      background: dark ? darkBackground : background,
      surface: dark ? darkSurface : surface,
      secondarySurface: dark ? darkSecondarySurface : secondarySurface,
      textPrimary: dark ? darkTextPrimary : textPrimary,
      textSecondary: dark ? darkTextSecondary : textSecondary,
      border: dark ? darkBorder : border,
      accent: dark ? darkAccent : accent,
      accentTint: dark ? darkAccentTint : accentTint,
    );
  }

  /// Returns a theme-appropriate color by logical name.
  ///
  /// Legacy keys (`primary`, `inputFill`, `pdfBadgeBg`, etc.) are kept so
  /// existing call sites keep working during the redesign migration.
  static Color colorOf(BuildContext context, String name) {
    final s = schemeOf(context);
    switch (name) {
      case 'background':
        return s.background;
      case 'surface':
      case 'card':
        return s.surface;
      case 'secondarySurface':
      case 'inputFill':
        return s.secondarySurface;
      case 'textPrimary':
        return s.textPrimary;
      case 'textSecondary':
        return s.textSecondary;
      case 'textMuted':
        return s.textSecondary;
      case 'border':
        return s.border;
      case 'accent':
      case 'primary':
      case 'pdfIcon':
      case 'brandRed':
        return s.accent;
      case 'accentTint':
      case 'pdfBadgeBg':
        return s.accentTint;
      default:
        return s.background;
    }
  }
}

/// Resolved color tokens for the current theme brightness.
class AppColorScheme {
  final Color background;
  final Color surface;
  final Color secondarySurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color accent;
  final Color accentTint;

  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.secondarySurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.accent,
    required this.accentTint,
  });
}
