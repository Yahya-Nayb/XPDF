import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A tappable card that shrinks slightly while it is pressed, then springs back.
///
/// The scale is deliberately tiny ([AppTokens.pressScale]) and the tween short
/// ([AppTokens.press]) so it reads as the surface giving way under a finger
/// rather than as an animation. It drives the [InkWell] that owns the card's
/// gesture, so the press response and the Material ink ripple are the same
/// gesture — there is no second recognizer to compete in the arena, and a drag
/// that turns into a scroll never squashes the card.
///
/// Put it inside a Material ancestor (a [Scaffold] is enough) so the ripple has
/// a surface to paint on.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;

    return AnimatedScale(
      scale: _pressed ? AppTokens.pressScale : 1,
      duration: AppTokens.press,
      curve: AppTokens.defaultCurve,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: widget.borderRadius,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: widget.child,
      ),
    );
  }
}