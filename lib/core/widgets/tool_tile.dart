import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../theme/app_tokens.dart';
import '../theme/context_extension.dart';

/// A compact shortcut tile: a monochrome icon above a single label, on the app's
/// translucent glass surface.
///
/// Sized and coloured for a row of three that has to leave room for the content
/// below it — [height] is 84dp, and the subtitle the fuller tiles carry is gone,
/// because at this size the label is the only text that still reads. The tile
/// paints no blur: what sells the surface is a translucent fill, a hairline, and
/// a diagonal sheen, all of them tokens.
///
/// Nothing here is coloured. A row of three tinted boxes competes with the one
/// tile on the screen that is allowed an identity — the solid primary Import —
/// and the tools are found by their labels, not by their hues. The feature
/// colours stay in the theme for the screens that lead with them.
///
/// Pressing does two things at once — the tile shrinks, its fill brightens and
/// the icon's outline darkens — which is why this is a [StatefulWidget] rather
/// than a [PressScale]: the three share one gesture and one duration, and a
/// wrapper would only expose one of them.
class ToolTile extends StatefulWidget {
  /// Height of the tile. Fixed so a row of them lines up without the caller
  /// measuring anything.
  static const double height = 84;

  /// The icon's box: an outlined square with nothing inside it but the glyph.
  static const double iconBoxSize = 38;

  /// The glyph itself. Small enough that the outline, not the fill, is what the
  /// eye reads.
  static const double iconSize = 20;

  /// How much brighter the fill gets under the finger. Small on purpose: the
  /// surface is already translucent, and a large jump would wash it out.
  static const double pressFillLift = 0.04;

  /// How far the icon's outline moves toward the label colour under the finger.
  static const double pressBorderOpacity = 0.3;

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ToolTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// The glass surface [ToolTile] paints, for the tiles on a screen that have to
  /// match it.
  ///
  /// Exposed rather than duplicated so the whole screen shares one pane of
  /// glass. [pressed] lifts the fill the same way the tile's own press does.
  static BoxDecoration glassSurface(
    AppThemeExtension ext, {
    bool pressed = false,
  }) {
    final highlight = ext.glassHighlight;

    return BoxDecoration(
      color: pressed
          ? ext.glassFill.withValues(
              alpha: (ext.glassFill.a + pressFillLift).clamp(0.0, 1.0),
            )
          : ext.glassFill,
      borderRadius: BorderRadius.circular(AppTokens.card),
      border: Border.all(color: ext.glassBorder, width: AppTokens.hairline),
      // The sheen only exists where the fill is translucent; on a light page
      // the token is transparent, so the gradient is a no-op there.
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [highlight, highlight.withValues(alpha: 0)],
      ),
      boxShadow: ext.glassShadow.a == 0
          ? null
          : [
              BoxShadow(
                color: ext.glassShadow,
                blurRadius: _liftBlur,
                offset: const Offset(0, _liftOffsetY),
              ),
            ],
    );
  }

  /// The soft lift a glass tile casts on a light page: wide and shallow, so it
  /// separates the tile from the background without drawing an edge around it.
  static const double _liftBlur = 16;
  static const double _liftOffsetY = 4;

  @override
  State<ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<ToolTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.appColors;

    return AnimatedScale(
      scale: _pressed ? AppTokens.pressScale : 1,
      duration: AppTokens.press,
      curve: AppTokens.defaultCurve,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedContainer(
          duration: AppTokens.press,
          curve: AppTokens.defaultCurve,
          height: ToolTile.height,
          decoration: ToolTile.glassSurface(ext, pressed: _pressed),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolIconBox(icon: widget.icon, pressed: _pressed),
                const SizedBox(height: AppTokens.sm),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The outlined square a tool's glyph sits in.
///
/// No fill at all: the hairline is the whole box. It is a step stronger than the
/// tile's own border, because a box with nothing in it has no fill to carry it,
/// and under the finger it darkens toward the label colour so the press is
/// visible even though the icon itself never moves.
class _ToolIconBox extends StatelessWidget {
  final IconData icon;
  final bool pressed;

  const _ToolIconBox({required this.icon, required this.pressed});

  @override
  Widget build(BuildContext context) {
    final ext = context.appColors;
    final foreground = Theme.of(context).colorScheme.onSurface;

    return AnimatedContainer(
      duration: AppTokens.press,
      curve: AppTokens.defaultCurve,
      width: ToolTile.iconBoxSize,
      height: ToolTile.iconBoxSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.md),
        border: Border.all(
          color: pressed
              ? foreground.withValues(alpha: ToolTile.pressBorderOpacity)
              : ext.glassBorderStrong,
          width: AppTokens.hairline,
        ),
      ),
      child: Icon(icon, size: ToolTile.iconSize, color: foreground),
    );
  }
}