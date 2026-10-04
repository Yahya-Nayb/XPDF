import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/context_extension.dart';
import '../core/widgets/pdf_page_thumbnail.dart';
import '../models/recent_file.dart';

/// A single row in the Home screen's List view of recent files.
///
/// Rendered inside the shared rounded container built in the Home screen
/// (rows are separated there by thin dividers). Tapping the row opens the
/// file; the star toggles favorite and the overflow menu / long-press open
/// the same actions sheet as the grid cards.
///
/// The leading box is the document's real first page, rendered at thumbnail
/// resolution — a list of twenty files is twenty documents you can recognise
/// without reading a single word of it. Until the page arrives, or if it cannot
/// be rendered at all, the box falls back to the accent document icon, so the
/// row never shows an empty square.
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
    final theme = Theme.of(context);
    final ext = context.appColors;
    final pageLabel = file.lastPage == 1 ? '1 page' : '${file.lastPage} pages';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.md,
          AppTokens.md,
          AppTokens.sm,
          AppTokens.md,
        ),
        child: Row(
          children: [
            PdfPageThumbnail(path: file.path),
            const SizedBox(width: AppTokens.md),
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
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppTokens.xs),
                  Text(
                    '$pageLabel · ${file.formattedSize}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: ext.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.sm),
            InkWell(
              onTap: onToggleFavorite,
              borderRadius: BorderRadius.circular(AppTokens.button),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.xs),
                child: Icon(
                  file.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  color: file.isFavorite ? AppColors.favorite : ext.textSecondary,
                ),
              ),
            ),
            InkWell(
              onTap: onMenu,
              borderRadius: BorderRadius.circular(AppTokens.button),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.xs),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: ext.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}