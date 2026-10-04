import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../theme/app_tokens.dart';
import '../theme/context_extension.dart';

/// Draws a stroke of the signature gradient around a shape.
///
/// Flutter has no gradient border: [ShapeDecoration] takes a gradient for the
/// *fill* and a [Border] takes a single colour for the edge, so the gradient
/// ring is painted by filling the outer shape with the gradient and laying the
/// real surface back on top, inset by [stroke].
///
/// Keep it to one element per screen — it is brand, not decoration. AGENTS.md
/// reserves the signature gradient for the logo, the FAB, loaders, success
/// moments and a single accent accent; this widget exists so that accent is a
/// token rather than a hard-coded brush.
class GradientRing extends StatelessWidget {
  /// Outline shape. [stroke] is measured inwards from it.
  final ShapeBorder shape;

  final Widget child;

  /// Ring weight. Defaults to [AppTokens.ring], the one border in the app that
  /// is deliberately heavier than the hairline.
  final double stroke;

  /// Colour laid inside the ring. Defaults to transparent, so whatever is
  /// behind the widget shows through.
  final Color? fill;

  /// Shadows cast by the *outer* shape, i.e. the glow that sits under the
  /// whole tile rather than under the ring alone.
  final List<BoxShadow>? shadows;

  const GradientRing({
    super.key,
    required this.shape,
    required this.child,
    this.stroke = AppTokens.ring,
    this.fill,
    this.shadows,
  });

  /// The circular form, for wrapping an icon badge.
  const GradientRing.circle({
    super.key,
    required this.child,
    this.stroke = AppTokens.ring,
    this.fill,
    this.shadows,
  }) : shape = const CircleBorder();

  @override
  Widget build(BuildContext context) {
    final gradient = context.appColors.signatureGradient;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: gradient,
        shadows: shadows,
      ),
      child: Padding(
        padding: EdgeInsets.all(stroke),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            color: fill ?? Colors.transparent,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The soft brand glow that sits behind a gradient-ringed tile.
///
/// Built from the signature gradient's own stops rather than a literal colour,
/// so it follows the ramp if the brand changes. Two overlapping shadows — one
/// per end of the ramp — read as a tinted halo instead of a flat grey one.
List<BoxShadow> gradientGlow(
  AppThemeExtension ext, {
  double opacity = 0.3,
}) {
  final stops = ext.signatureGradient.colors;

  return [
    BoxShadow(
      color: stops.last.withValues(alpha: opacity),
      blurRadius: AppTokens.xxl,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: stops[stops.length ~/ 2].withValues(alpha: opacity * 0.6),
      blurRadius: AppTokens.xl,
      offset: const Offset(0, 4),
    ),
  ];
}