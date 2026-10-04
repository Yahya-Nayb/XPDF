import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/context_extension.dart';

/// A feature tile for actions like Scan, Split, Merge, or Images.
///
/// Use [FeatureTile] when you need to highlight a key feature action
/// with an icon in a tinted background based on the feature color.
class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color featureColor;
  final VoidCallback? onTap;

  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.featureColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = context.appColors;
    final textSecondary = ext.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.tile),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: featureColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTokens.button),
              ),
              child: Icon(
                icon,
                color: featureColor,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTokens.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppTokens.xs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}