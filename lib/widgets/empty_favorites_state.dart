import 'package:flutter/material.dart';
import '../colors.dart';

/// Warm gold matching the filled favorite star on [RecentFileCard].
const Color _favoriteGold = Color(0xFFF6B93B);

/// Friendly message shown when there are no favorited files yet.
///
/// Mirrors the style of [EmptyState] but speaks to starring files instead of
/// opening the first PDF.
class EmptyFavoritesState extends StatelessWidget {
  const EmptyFavoritesState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in a soft gold-tinted circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _favoriteGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_border_rounded,
                size: 40,
                color: _favoriteGold,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'No favorites yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the star icon on any file to\nkeep it handy here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.colorOf(context, 'textMuted'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
