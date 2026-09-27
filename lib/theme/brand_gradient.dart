import 'package:flutter/material.dart';

/// The XPDF brand gradient and the wordmark built from it.
///
/// The four stops reproduce the colour flow of the spiral brand icon
/// (`assets/images/logo.png`) — coral-red, amber, magenta, blue — sampled from
/// that asset. The icon's strokes are thin and heavily antialiased, so its
/// magenta and blue sample at only ~0.28-0.46 saturation; the values below use
/// the intended vivid brand hues rather than the washed-out raster samples.
///
/// The gradient has two stop sets. [stopsFor] returns the vivid set on dark
/// surfaces. On the light surface (`AppColors.background`, `#F4F3F1`) the vivid
/// amber and blue fall to 1.7:1 and 2.4:1 contrast, so [stopsFor] substitutes
/// a slightly darker set that holds 3.0:1 (WCAG AA for large text) on every
/// stop. Both sets are >= 3.9:1 on the opposite surface, so the gradient stays
/// legible whichever theme is active.
class BrandGradient {
  BrandGradient._();

  /// Font family of the bundled Caveat wordmark. Registered in pubspec.yaml
  /// with static Regular and Bold faces, so `fontWeight` alone is enough and
  /// no `fontVariations` (variable font) support is required.
  static const String wordmarkFont = 'Caveat';

  /// Wordmark size. Caveat is a light script face with a small x-height, so it
  /// sits larger than the UI text it replaces to read clearly at header scale.
  static const double wordmarkFontSize = 32;

  /// Vivid brand stops, used on dark surfaces.
  static const List<Color> darkStops = [
    Color(0xFFFF4D5E), // coral red
    Color(0xFFFFA94D), // amber
    Color(0xFFC6469C), // magenta
    Color(0xFF4D9FFF), // azure blue
  ];

  /// Depth-adjusted stops for light surfaces. Same hues and order, lowered just
  /// enough to clear 3.0:1 against `#F4F3F1`.
  static const List<Color> lightStops = [
    Color(0xFFFF4759), // coral red
    Color(0xFFD97000), // amber
    Color(0xFFC6469C), // magenta
    Color(0xFF2A8CFF), // azure blue
  ];

  /// Stops appropriate for [context]'s theme brightness.
  static List<Color> stopsFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkStops : lightStops;

  /// A brand gradient spanning the widget box.
  ///
  /// Defaults to the left-to-right flow used by the wordmark. Round shapes such
  /// as the "Add document" FAB pass a diagonal [begin]/[end] instead, which
  /// measured better against a white glyph than the horizontal flow.
  static LinearGradient linearFor(
    BuildContext context, {
    AlignmentGeometry? begin,
    AlignmentGeometry? end,
  }) => LinearGradient(
    colors: stopsFor(context),
    begin: begin ?? Alignment.centerLeft,
    end: end ?? Alignment.centerRight,
  );

  /// The "XPDF" wordmark filled with the brand gradient.
  ///
  /// [fontSize] and [weight] default to the header-logo treatment.
  static Widget text(
    BuildContext context, {
    double fontSize = wordmarkFontSize,
    FontWeight weight = FontWeight.w700,
    String text = 'XPDF',
  }) {
    return ShaderMask(
      // BlendMode.srcIn keeps only the glyph pixels, recoloured by the shader.
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          linearFor(context).createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
      child: Text(
        text,
        // `height: 1` keeps the script's tall ascenders from inflating the
        // height of the surrounding Row.
        style: TextStyle(
          fontFamily: wordmarkFont,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
