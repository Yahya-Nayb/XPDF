import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';

/// A loading indicator that uses the signature gradient.
///
/// Use [GradientLoader] to match the branded loading animation
/// seen in the splash screen.
class GradientLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;

  const GradientLoader({
    super.key,
    this.size = 48,
    this.strokeWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GradientLoaderPainter(
          gradient: AppGradients.signature,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _GradientLoaderPainter extends CustomPainter {
  final Gradient gradient;
  final double strokeWidth;

  _GradientLoaderPainter({
    required this.gradient,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientLoaderPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}