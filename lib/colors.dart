import 'package:flutter/material.dart';

/// Folia's exact color palette.
///
/// Light and dark palettes are exposed via [light] and [dark] getters.
/// Every widget should read colors through `AppColors.light.xxx` or
/// `AppColors.dark.xxx` (or via the theme helper) instead of using
/// a single hardcoded set.
class AppColors {
  AppColors._(); // prevent instantiation

  // ---------------------------------------------------------------------------
  // Light palette (the original Folia colors)
  // ---------------------------------------------------------------------------

  static const Color background   = Color(0xFFF7F7F8);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color card         = Color(0xFFFFFFFF);
  static const Color inputFill    = Color(0xFFF0F0F2);
  static const Color primary      = Color(0xFF3A7BD5);
  static const Color pdfBadgeBg   = Color(0xFFFDECEC);
  static const Color pdfIcon      = Color(0xFFE0473C);
  static const Color brandRed     = Color(0xFFFC3A34);
  static const Color textPrimary  = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF555558);
  static const Color textMuted    = Color(0xFF8A8A8E);
  static const Color border       = Color(0xFFE8E8EC);

  // ---------------------------------------------------------------------------
  // Dark palette
  // ---------------------------------------------------------------------------

  static const Color darkBackground   = Color(0xFF121212);
  static const Color darkSurface      = Color(0xFF1E1E1E);
  static const Color darkCard         = Color(0xFF252525);
  static const Color darkInputFill    = Color(0xFF2C2C2E);
  static const Color darkPrimary      = Color(0xFF5B9FE6);
  static const Color darkPdfBadgeBg   = Color(0xFF3D2020);
  static const Color darkPdfIcon      = Color(0xFFE0605A);
  static const Color darkTextPrimary  = Color(0xFFF0F0F0);
  static const Color darkTextSecondary = Color(0xFFA0A0A4);
  static const Color darkTextMuted    = Color(0xFF6B6B6F);
  static const Color darkBorder       = Color(0xFF3A3A3C);

  /// Returns the theme-appropriate variant of [name].
  ///
  /// Usage in widgets:
  /// ```dart
  /// backgroundColor: AppColors.colorOf(context, 'background'),
  /// ```
  static Color colorOf(BuildContext context, String name) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;
    switch (name) {
      case 'background':
        return isDark ? darkBackground : background;
      case 'surface':
        return isDark ? darkSurface : surface;
      case 'card':
        return isDark ? darkCard : card;
      case 'inputFill':
        return isDark ? darkInputFill : inputFill;
      case 'primary':
        return isDark ? darkPrimary : primary;
      case 'pdfBadgeBg':
        return isDark ? darkPdfBadgeBg : pdfBadgeBg;
      case 'pdfIcon':
        return isDark ? darkPdfIcon : pdfIcon;
      case 'brandRed':
        return brandRed;
      case 'textPrimary':
        return isDark ? darkTextPrimary : textPrimary;
      case 'textSecondary':
        return isDark ? darkTextSecondary : textSecondary;
      case 'textMuted':
        return isDark ? darkTextMuted : textMuted;
      case 'border':
        return isDark ? darkBorder : border;
      default:
        return isDark ? darkBackground : background;
    }
  }
}
