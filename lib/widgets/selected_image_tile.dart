import 'dart:io';

import 'package:flutter/material.dart';

import '../colors.dart';
import '../models/selected_image.dart';

/// A card-style tile for a single selected image, showing a thumbnail,
/// a "Page N" caption, and a remove-button overlay.
///
/// Styled to match [RecentFileCard]: same border radius, border color,
/// and shadow treatment (both light and dark modes).
class SelectedImageTile extends StatelessWidget {
  final SelectedImage image;
  final int pageIndex;
  final ValueChanged<String> onRemove;

  const SelectedImageTile({
    super.key,
    required this.image,
    required this.pageIndex,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorOf(context, 'card'),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.colorOf(context, 'border')),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -- Thumbnail with remove button overlay -----------------------
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image
                Image.file(
                  File(image.path),
                  fit: BoxFit.cover,
                  // Gracefully handle missing / corrupted image files.
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.colorOf(context, 'inputFill'),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.colorOf(context, 'textMuted'),
                        ),
                      ),
                    );
                  },
                ),

                // Semi-transparent "X" pill in the top-right corner
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(image.id),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // -- Page number caption ----------------------------------------
          // Uses textSecondary in dark mode for better contrast against
          // the card background (#252525). textMuted (#6B6B6F) is too low
          // contrast in dark mode.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: AppColors.colorOf(context, 'card'),
            child: Text(
              'Page $pageIndex',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.colorOf(
                  context,
                  isDark ? 'textSecondary' : 'textMuted',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
