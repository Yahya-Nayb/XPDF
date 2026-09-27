import 'package:flutter/material.dart';

import '../models/recent_file.dart';
import '../theme/app_colors.dart';

/// Warm gold for the favorite star (muted outline when not favorited).
const Color _favoriteGold = Color(0xFFF6B93B);

/// A single row in the Home screen's List view of recent files.
///
/// Rendered inside the shared rounded container built in the Home screen
/// (rows are separated there by thin dividers). Tapping the row opens the
/// file; the star toggles favorite and the overflow menu / long-press open
/// the same actions sheet as the grid cards.
class RecentFileListRow extends StatelessWidget {
  final RecentFile file;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onMenu;
  final VoidCallback? onLongPress;

  const RecentFileListRow({
    super.key,
    required this.file,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onMenu,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.schemeOf(context);
    final pageLabel = file.lastPage == 1 ? '1 page' : '${file.lastPage} pages';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.accentTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.description_rounded,
                color: colors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$pageLabel · ${file.formattedSize}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onToggleFavorite,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  file.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  color: file.isFavorite ? _favoriteGold : colors.textSecondary,
                ),
              ),
            ),
            InkWell(
              onTap: onMenu,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}