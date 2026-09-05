import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../colors.dart';
import '../providers/recent_files_provider.dart';

/// Bottom sheet for choosing the file-list sort order.
///
/// Radio-style list of the five supported modes; the current selection is
/// marked with a filled radio dot and accent-colored label. Selecting an
/// option persists it via [RecentFilesProvider.setSortMode] and pops.
///
/// The same preference drives the Home Recent list, Favorites view, and
/// Library folder contents — sorting lives in one place
/// ([RecentFilesProvider.sortFiles]).
Future<void> showSortSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.colorOf(context, 'surface'),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const SortSheet(),
  );
}

class SortSheet extends StatelessWidget {
  const SortSheet({super.key});

  static const List<({String id, String label})> _options = [
    (
      id: RecentFilesProvider.sortRecentlyOpened,
      label: 'Recently opened',
    ),
    (id: RecentFilesProvider.sortNameAsc, label: 'Name (A-Z)'),
    (id: RecentFilesProvider.sortNameDesc, label: 'Name (Z-A)'),
    (id: RecentFilesProvider.sortSizeLargest, label: 'Size (largest first)'),
    (id: RecentFilesProvider.sortSizeSmallest, label: 'Size (smallest first)'),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecentFilesProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort by',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
            const SizedBox(height: 6),

            ..._options.map((option) {
              final isSelected = provider.sortMode == option.id;
              return InkWell(
                onTap: () async {
                  await provider.setSortMode(option.id);
                  if (context.mounted) Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      // Radio indicator
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 2,
                            color: isSelected
                                ? AppColors.colorOf(context, 'primary')
                                : AppColors.colorOf(context, 'textMuted'),
                          ),
                        ),
                        child: isSelected
                            ? Container(
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      AppColors.colorOf(context, 'primary'),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.colorOf(context, 'primary')
                                : AppColors.colorOf(context, 'textPrimary'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
