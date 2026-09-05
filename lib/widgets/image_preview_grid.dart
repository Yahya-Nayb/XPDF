import 'package:flutter/material.dart';

import '../colors.dart';
import '../models/selected_image.dart';
import 'selected_image_tile.dart';

/// A 3-column grid displaying thumbnails of all currently selected images,
/// plus an "Add More" tile as the last item.
///
/// Uses `shrinkWrap: true` + `NeverScrollableScrollPhysics` so it can be
/// embedded inside a `SingleChildScrollView` without scroll conflicts.
class ImagePreviewGrid extends StatelessWidget {
  final List<SelectedImage> images;
  final ValueChanged<String> onRemove;
  final VoidCallback onAddMore;

  const ImagePreviewGrid({
    super.key,
    required this.images,
    required this.onRemove,
    required this.onAddMore,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return _EmptyGridPlaceholder(onTap: onAddMore);
    }

    // +1 for the "Add More" tile at the end
    final itemCount = images.length + 1;

    return GridView.builder(
      shrinkWrap: true,
      // Prevents the grid from scrolling independently — its parent
      // SingleChildScrollView handles all scrolling.
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Last item is the "Add More" tile
        if (index == images.length) {
          return _AddMoreTile(onTap: onAddMore);
        }

        final image = images[index];
        return SelectedImageTile(
          key: ValueKey(image.id),
          image: image,
          pageIndex: index + 1,
          onRemove: onRemove,
        );
      },
    );
  }
}

/// Polished empty-state placeholder shown when no images are selected yet.
///
/// Tappable — opens the gallery picker directly. Uses a primary-colored icon
/// with a "+" badge overlay, clear typography hierarchy, and a dashed-style
/// border matching the "Add More" tile visual language.
class _EmptyGridPlaceholder extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyGridPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.colorOf(context, 'inputFill'),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.colorOf(context, 'border'),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // -- Icon with "+" badge overlay --------------------------------
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Primary-colored icon circle
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.colorOf(context, 'primary')
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.image_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),

                // "+" badge in bottom-right
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.colorOf(context, 'primary'),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.colorOf(context, 'inputFill'),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // -- Title ----------------------------------------------------
            Text(
              'No images selected yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
            const SizedBox(height: 6),

            // -- Hint -----------------------------------------------------
            Text(
              'Tap here to add images from your gallery',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.colorOf(context, 'textMuted'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed-border tile with a "+" icon — the last item in the grid.
/// Tapping it opens the gallery picker.
class _AddMoreTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMoreTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.colorOf(context, 'inputFill'),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.colorOf(context, 'border'),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 28,
              color: AppColors.colorOf(context, 'textMuted'),
            ),
            const SizedBox(height: 4),
            Text(
              'Add More',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.colorOf(context, 'textMuted'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
