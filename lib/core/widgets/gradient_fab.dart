import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';

/// A circular floating action button with the signature gradient.
///
/// Use [GradientFab] for the primary floating action on screens
/// that need a branded CTA (like the "+" action in home).
class GradientFab extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String? tooltip;

  const GradientFab({
    super.key,
    this.onTap,
    this.icon = Icons.add,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton(
      onPressed: onTap,
      elevation: 0,
      backgroundColor: Colors.transparent,
      tooltip: tooltip,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.signature,
        ),
        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );

    return fab;
  }
}