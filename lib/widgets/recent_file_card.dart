import 'package:flutter/material.dart';
import '../colors.dart';
import '../models/recent_file.dart';

/// Warm gold used for the filled favorite star.
const Color _favoriteGold = Color(0xFFF6B93B);

/// A polished card displaying one recent PDF file.
///
/// Includes a red-tinted PDF badge, filename + metadata, a star toggle for
/// favoriting, and a three-dot overflow menu for actions like
/// "Remove from recent".
class RecentFileCard extends StatelessWidget {
  final RecentFile file;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuAction;
  final VoidCallback onToggleFavorite;

  const RecentFileCard({
    super.key,
    required this.file,
    required this.onTap,
    required this.onMenuAction,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.colorOf(context, 'card'),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.colorOf(context, 'border')),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // -- PDF icon badge ------------------------------------------------
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.colorOf(context, 'pdfBadgeBg'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.colorOf(context, 'pdfIcon'),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // -- File info -----------------------------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filename
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.colorOf(context, 'textPrimary'),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // "size · relative date"
                  Text(
                    '${file.formattedSize}  ·  ${file.relativeDate}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.colorOf(context, 'textMuted'),
                    ),
                  ),
                ],
              ),
            ),

            // -- Favorite star toggle -------------------------------------------
            IconButton(
              onPressed: onToggleFavorite,
              tooltip:
                  file.isFavorite ? 'Remove from favorites' : 'Add to favorites',
              icon: Icon(
                file.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 22,
                color: file.isFavorite
                    ? _favoriteGold
                    : AppColors.colorOf(context, 'textMuted'),
              ),
            ),

            // -- Three-dot menu ------------------------------------------------
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: AppColors.colorOf(context, 'textMuted'),
                size: 20,
              ),
              onSelected: onMenuAction,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'favorite',
                  child: Text(file.isFavorite
                      ? 'Remove from Favorites'
                      : 'Add to Favorites'),
                ),
                const PopupMenuItem(
                  value: 'move',
                  child: Text('Move to folder'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from recent'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
