import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/context_extension.dart';
import 'gradient_ring.dart';

/// An empty state placeholder for when there is no data to show.
///
/// Use [EmptyState] to guide users when lists are empty with
/// an icon, title, and helpful message.
///
/// [gradientRing] adds the one touch of the signature gradient the design
/// system allows an empty state: a hairline-ish ring around the icon badge, so
/// the state is anchored to the brand without competing with the screen's
/// primary action. Off by default — it is a deliberate accent, not a default.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool gradientRing;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.gradientRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final ext = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;

    final badge = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ext.primaryContainer,
      ),
      child: Icon(
        icon,
        color: primary,
        size: 48,
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (gradientRing)
              GradientRing.circle(
                fill: ext.primaryContainer,
                stroke: AppTokens.hairline,
                child: badge,
              )
            else
              badge,
            const SizedBox(height: AppTokens.xl),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ext.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}