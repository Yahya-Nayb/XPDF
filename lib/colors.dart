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

  static const Color background = Color(0xFFF7F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color inputFill = Color(0xFFF0F0F2);
  static const Color primary = Color(0xFF3A7BD5);
  static const Color pdfBadgeBg = Color(0xFFFDECEC);
  static const Color pdfIcon = Color(0xFFE0473C);
  static const Color brandRed = Color(0xFFFC3A34);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF555558);
  static const Color textMuted = Color(0xFF8A8A8E);
  static const Color border = Color(0xFFE8E8EC);

  // ---------------------------------------------------------------------------
  // Dark palette
  // ---------------------------------------------------------------------------

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF252525);
  static const Color darkInputFill = Color(0xFF2C2C2E);
  static const Color darkPrimary = Color(0xFF5B9FE6);
  static const Color darkPdfBadgeBg = Color(0xFF3D2020);
  static const Color darkPdfIcon = Color(0xFFE0605A);
  static const Color darkTextPrimary = Color(0xFFF0F0F0);
  static const Color darkTextSecondary = Color(0xFFA0A0A4);
  static const Color darkTextMuted = Color(0xFF6B6B6F);
  static const Color darkBorder = Color(0xFF3A3A3C);

  /// Returns the theme-appropriate variant of [name].
  ///
  /// Usage in widgets:
  /// ```dart
  /// backgroundColor: AppColors.colorOf(context, 'background'),
  /// ```
  static Color colorOf(BuildContext context, String name) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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

/// Night-mode page rendering: a "comfortable reading" color filter that turns
/// white PDF pages into a warm dark gray (≈#221e16) and black ink into warm
/// off-white (≈#e9e5dd), with colored content kept recognizable (its hue is
/// preserved) but muted — the opposite of the harsh "accessibility invert",
/// which flips every pixel to full-contrast complements.
///
/// The filter is a single affine [ColorFilter.matrix] that composes four
/// linear operations, applied to page pixels on the GPU:
///
/// 1. **Hue-preserving luminance flip** `I` — replaces each pixel's luma
///    `L = 0.299R + 0.587G + 0.114B` (Rec.601/sRGB-ish weights, matching the
///    original flip) with `1 - L` while leaving its chroma untouched:
///    `R' = R + 1 - 2L`, likewise G'/B'. White→black, black→white, but a red
///    logo stays red (just lighter) instead of turning cyan.
/// 2. **Tonal contraction** `C` — leans every channel toward mid-gray,
///    `C(x) = k·x + (1-k)·127.5` with `k = 0.78`. This is what softens the
///    harsh 0↔255 extremes: paper lands at ≈#221e16 and ink at ≈#e9e5dd
///    instead of pure black/white. (A linear stand-in for gamma; true
///    per-pixel s-curves would require a custom shader, which we avoid for
///    performance and because ColorFilter.matrix is linear.)
/// 3. **Desaturation** `S` — mixes each channel toward the pixel's own luma by
///    `s = 0.70` (1.0 = unchanged), so saturated logos/text/chart cells lose
///    the neon edge while keeping their identity.
/// 4. **Warm cast** `W` — adds a small constant offset `(+6, +2, -6)` to R/G/B
///    (a gentle sepia warmth) so near-monochrome reading pages don't feel
///    sterile.
///
/// All four are affine, so they collapse into ONE 4×5 matrix — a single GPU
/// pass and no per-pixel Dart work. The result is deliberately NOT an
/// involution (every involutive affine map must send grays to `c - g`, i.e.
/// a full-contrast inversion — exactly what we are softening). Overlay
/// compensation therefore uses the exact affine INVERSE filter (composed of
/// the same two trivial matrix steps below) rather than applying the same
/// filter twice.
///
/// [wrap] applies the night filter to the whole viewer subtree. Our app-level
/// overlays (annotation highlights, the floating selection toolbar) sit inside
/// that subtree and must be individually pre-compensated with [counterWrap],
/// which applies the inverse matrix `G = F⁻¹` (A_G = A_F⁻¹, b_G = −A_G·b_F).
/// Because F is globally affine and never clips in-range colors, `F(G(c)) ≈ c`
/// returns overlays to their authored colors — exact except where G would push
/// an overlay color outside [0,255] (e.g. pure white pre-distorts below 0 and
/// lands on the nearest representable warm white ≈#e9e5dd, which reads as a
/// soft light surface rather than an error).
class NightMode {
  NightMode._(); // prevent instantiation

  /// 4×5 ColorFilter.matrix for the single-pass night filter `F = W∘S∘C∘I`
  /// above. Linear entries act on 0..1 color components; offsets use Flutter's
  /// 0..255 convention (internally divided by 255). Alpha is untouched.
  static const List<double> nightMatrix = <double>[
    0.1495, -0.7784, -0.1512, 0, 232.950, // R'
    -0.3965, -0.2324, -0.1512, 0, 228.950, // G'
    -0.3965, -0.7784, 0.3948, 0, 220.950, // B'
    0, 0, 0, 1, 0, // A'
  ];

  /// Exact affine inverse of [nightMatrix] (`A_G = A_F⁻¹`, `b_G = −A_G·b_F`)
  /// used to pre-compensate OUR overlay widgets so that, once the viewer-wide
  /// [nightMatrix] is applied over them, they net back to their authored
  /// colors. See the class docs for the (small, bounded) gamut caveats.
  static const List<double> compensationMatrix = <double>[
    0.9005, -1.8277, -0.3549, 0, 287.084, // R'
    -0.9310, 0.0038, -0.3549, 0, 294.410, // G'
    -0.9310, -1.8277, 1.4766, 0, 309.062, // B'
    0, 0, 0, 1, 0, // A'
  ];

  /// The night [ColorFilter], constructed from [nightMatrix].
  static ColorFilter get colorFilter => ColorFilter.matrix(nightMatrix);

  /// The overlay compensation [ColorFilter], constructed from
  /// [compensationMatrix].
  static ColorFilter get compensationColorFilter =>
      ColorFilter.matrix(compensationMatrix);

  /// Wraps the page canvas subtree so every rasterized PDF page pixel is
  /// night-rendered. Our app-level overlays live inside [child] and must be
  /// individually pre-compensated with [counterWrap] so they are not darkened
  /// along with the pages.
  static Widget wrap(Widget child) =>
      ColorFiltered(colorFilter: colorFilter, child: child);

  /// Pre-compensates one of OUR overlay widgets with the inverse of the night
  /// filter. After the outer [wrap] filter is applied, `F(G(c)) ≈ c` restores
  /// the authored color, while the page around it stays night-rendered.
  static Widget counterWrap(Widget child) =>
      ColorFiltered(colorFilter: compensationColorFilter, child: child);
}
