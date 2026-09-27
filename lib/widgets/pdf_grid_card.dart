import 'package:flutter/material.dart';

import '../models/recent_file.dart';
import '../theme/app_colors.dart';

/// Warm gold for the favorite star overlay.
const Color _favoriteGold = Color(0xFFF6B93B);

/// A compact 3-column grid card: solid accent-gradient tile, filename, metadata.
///
/// Pure graphics — no real page preview is generated; the tile is a diagonal
/// accent gradient with a white file icon + "PDF" label, so every card reads
/// as one cohesive, color-coded set.
class PdfGridCard extends StatelessWidget {
  final RecentFile file;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onLongPress;

  const PdfGridCard({
    super.key,
    required this.file,
    required this.onTap,
    this.onToggleFavorite,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.schemeOf(context);
    final pageLabel = file.lastPage > 1 ? 'p.${file.lastPage}' : null;
    final accentDeep = Color.lerp(colors.accent, Colors.black, 0.14)!;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.accent, accentDeep],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.description_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'PDF',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (file.isFavorite)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onToggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: _favoriteGold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: file.name,
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              ?pageLabel,
              file.formattedSize,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}