import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/context_extension.dart';

/// A reusable card that uses theme-based colors and tokens.
///
/// Use [AppCard] for content containers that need consistent surface,
/// border, and shadow styling across the app.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool useShadow;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTokens.lg),
    this.useShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = context.appColors;
    final borderColor = theme.brightness == Brightness.dark ? ext.border : null;

    final card = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.card),
        border: borderColor != null ? Border.all(color: borderColor) : null,
        boxShadow: useShadow && theme.brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.card),
        child: card,
      );
    }

    return card;
  }
}