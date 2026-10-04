import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A prominent primary action tile for key flows like Import.
///
/// Use [PrimaryActionTile] when you need a large, high-impact action
/// that stands out with the app's primary color.
class PrimaryActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const PrimaryActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.tile),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.xl),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(AppTokens.tile),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: AppTokens.lg),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}