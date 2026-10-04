import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_gradients.dart';

/// The translucent "glass" surface the compact tool tiles are made of.
///
/// Kept here rather than in the widgets so every tile that shares the surface —
/// and the Scan tile above them — is painted from one set of values. White over
/// a dark page at 6% reads as a pane of glass; on light mode the glass *is* the
/// page's own white, so only its border and shadow have to do any work.
const Color _glassFillDark = Color(0x0FFFFFFF); // white 6%
const Color _glassBorderDark = Color(0x14FFFFFF); // white 8%
const Color _glassHighlightDark = Color(0x14FFFFFF); // white 8%
const Color _glassShadowLight = Color(0x0F000000); // black 6%
const Color _glassBorderStrongDark = Color(0x24FFFFFF); // white 14%
const Color _glassBorderStrongLight = Color(0x1A000000); // black 10%
const Color _glassFillLight = Color(0xFFFFFFFF);
const Color _glassBorderLight = Color(0x0D000000); // black 5%
const Color _glassHighlightLight = Color(0x00FFFFFF); // unused on light
const Color _glassShadowDark = Color(0x00000000); // no shadow in dark

// The floating pill navigation's own palette, identical in both themes: the bar
// is always the same dark object, so which tab you are on — not the theme — is
// what the bar's colours are for.
const Color _navBarBg = Color(0xFF1F2123); // dark charcoal
const Color _navIndicator = Color(0xFFFFFFFF); // pure white
const Color _navIconInactive = Color(0xD9FFFFFF); // white 85%

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  /// The page background — the surface level *below* `colorScheme.surface`.
  ///
  /// Together they make three levels, `surfaceBase` < `surface` < [surfaceHigh],
  /// so depth in dark mode comes from the fill rather than from borders. A
  /// screen's own background is `surfaceBase`; secondary fills such as list
  /// items are `surface`; only the single most prominent tile on a screen is
  /// allowed `surfaceHigh`.
  final Color surfaceBase;

  final Color surfaceHigh;
  final Color border;
  final Color textSecondary;
  final Color primaryContainer;
  final LinearGradient signatureGradient;
  final Color scan;
  final Color split;
  final Color merge;
  final Color images;

  /// The glass surface: see the constants above. [glassFill] is the tile's own
  /// fill, [glassBorder] its hairline, [glassHighlight] the diagonal sheen laid
  /// over it, [glassShadow] what it casts on light pages.
  final Color glassFill;
  final Color glassBorder;

  /// One step stronger than [glassBorder]: the hairline around a tile's icon,
  /// which has no fill of its own to give it any presence.
  final Color glassBorderStrong;

  final Color glassHighlight;
  final Color glassShadow;

  /// The pill navigation bar's fill, the white circle behind the live icon, the
  /// dark colour that icon takes against it, and the muted colour the other
  /// three icons wear. See the constants above.
  final Color navBarBg;
  final Color navIndicator;
  final Color navIconActive;
  final Color navIconInactive;

  const AppThemeExtension({
    required this.surfaceBase,
    required this.surfaceHigh,
    required this.border,
    required this.textSecondary,
    required this.primaryContainer,
    required this.signatureGradient,
    required this.scan,
    required this.split,
    required this.merge,
    required this.images,
    required this.glassFill,
    required this.glassBorder,
    required this.glassBorderStrong,
    required this.glassHighlight,
    required this.glassShadow,
    required this.navBarBg,
    required this.navIndicator,
    required this.navIconActive,
    required this.navIconInactive,
  });

  static const AppThemeExtension light = AppThemeExtension(
    surfaceBase: AppColors.lightBg,
    surfaceHigh: AppColors.lightSurfaceHigh,
    border: AppColors.lightBorder,
    textSecondary: AppColors.lightTextSecondary,
    primaryContainer: AppColors.lightPrimaryContainer,
    signatureGradient: AppGradients.signature,
    scan: AppColors.scan,
    split: AppColors.split,
    merge: AppColors.merge,
    images: AppColors.images,
    glassFill: _glassFillLight,
    glassBorder: _glassBorderLight,
    glassBorderStrong: _glassBorderStrongLight,
    glassHighlight: _glassHighlightLight,
    glassShadow: _glassShadowLight,
    navBarBg: _navBarBg,
    navIndicator: _navIndicator,
    navIconActive: _navBarBg,
    navIconInactive: _navIconInactive,
  );

  static const AppThemeExtension dark = AppThemeExtension(
    surfaceBase: AppColors.darkBg,
    surfaceHigh: AppColors.darkSurfaceHigh,
    border: AppColors.darkBorder,
    textSecondary: AppColors.darkTextSecondary,
    primaryContainer: AppColors.darkPrimaryContainer,
    signatureGradient: AppGradients.signature,
    scan: AppColors.scan,
    split: AppColors.split,
    merge: AppColors.merge,
    images: AppColors.images,
    glassFill: _glassFillDark,
    glassBorder: _glassBorderDark,
    glassBorderStrong: _glassBorderStrongDark,
    glassHighlight: _glassHighlightDark,
    glassShadow: _glassShadowDark,
    navBarBg: _navBarBg,
    navIndicator: _navIndicator,
    navIconActive: _navBarBg,
    navIconInactive: _navIconInactive,
  );

  @override
  AppThemeExtension copyWith({
    Color? surfaceBase,
    Color? surfaceHigh,
    Color? border,
    Color? textSecondary,
    Color? primaryContainer,
    LinearGradient? signatureGradient,
    Color? scan,
    Color? split,
    Color? merge,
    Color? images,
    Color? glassFill,
    Color? glassBorder,
    Color? glassBorderStrong,
    Color? glassHighlight,
    Color? glassShadow,
    Color? navBarBg,
    Color? navIndicator,
    Color? navIconActive,
    Color? navIconInactive,
  }) {
    return AppThemeExtension(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      border: border ?? this.border,
      textSecondary: textSecondary ?? this.textSecondary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      signatureGradient: signatureGradient ?? this.signatureGradient,
      scan: scan ?? this.scan,
      split: split ?? this.split,
      merge: merge ?? this.merge,
      images: images ?? this.images,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBorderStrong: glassBorderStrong ?? this.glassBorderStrong,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassShadow: glassShadow ?? this.glassShadow,
      navBarBg: navBarBg ?? this.navBarBg,
      navIndicator: navIndicator ?? this.navIndicator,
      navIconActive: navIconActive ?? this.navIconActive,
      navIconInactive: navIconInactive ?? this.navIconInactive,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t) ?? surfaceBase,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t) ?? surfaceHigh,
      border: Color.lerp(border, other.border, t) ?? border,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t) ?? primaryContainer,
      signatureGradient: t < 0.5 ? signatureGradient : other.signatureGradient,
      scan: Color.lerp(scan, other.scan, t) ?? scan,
      split: Color.lerp(split, other.split, t) ?? split,
      merge: Color.lerp(merge, other.merge, t) ?? merge,
      images: Color.lerp(images, other.images, t) ?? images,
      glassFill: Color.lerp(glassFill, other.glassFill, t) ?? glassFill,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassBorderStrong:
          Color.lerp(glassBorderStrong, other.glassBorderStrong, t) ??
              glassBorderStrong,
      glassHighlight:
          Color.lerp(glassHighlight, other.glassHighlight, t) ?? glassHighlight,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t) ?? glassShadow,
      navBarBg: Color.lerp(navBarBg, other.navBarBg, t) ?? navBarBg,
      navIndicator:
          Color.lerp(navIndicator, other.navIndicator, t) ?? navIndicator,
      navIconActive:
          Color.lerp(navIconActive, other.navIconActive, t) ?? navIconActive,
      navIconInactive:
          Color.lerp(navIconInactive, other.navIconInactive, t) ??
              navIconInactive,
    );
  }
}