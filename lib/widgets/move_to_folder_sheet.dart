import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../colors.dart';
import '../models/recent_file.dart';
import '../providers/folders_provider.dart';
import '../providers/recent_files_provider.dart';

/// Bottom sheet for moving a file into a folder (or back to Uncategorized).
///
/// Lists every existing folder plus a pseudo "Uncategorized" entry; the
/// file's current location is marked with a check. Selecting an option
/// calls [RecentFilesProvider.assignToFolder] and pops immediately.
Future<void> showMoveToFolderSheet(
  BuildContext context,
  RecentFile file,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.colorOf(context, 'surface'),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => MoveToFolderSheet(file: file),
  );
}

class MoveToFolderSheet extends StatelessWidget {
  final RecentFile file;
  const MoveToFolderSheet({super.key, required this.file});

  void _select(BuildContext context, String? folderId, String label) {
    context.read<RecentFilesProvider>().assignToFolder(file.path, folderId);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved to "$label"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = context.watch<FoldersProvider>().folders;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move to folder',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.colorOf(context, 'textMuted'),
              ),
            ),
            const SizedBox(height: 14),

            // Uncategorized pseudo-folder first.
            _buildTile(
              context,
              icon: Icons.folder_off_rounded,
              color: AppColors.colorOf(context, 'textMuted'),
              name: 'Uncategorized',
              isSelected: file.folderId == null,
              onTap: () => _select(context, null, 'Uncategorized'),
            ),

            // Then one tile per folder.
            ...folders.map(
              (folder) => _buildTile(
                context,
                icon: Icons.folder_rounded,
                color: folder.color,
                name: folder.name,
                isSelected: file.folderId == folder.id,
                onTap: () => _select(context, folder.id, folder.name),
              ),
            ),

            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No folders yet — create one in the Library tab.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.colorOf(context, 'textMuted'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.colorOf(context, 'textPrimary'),
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: 20,
                color: AppColors.colorOf(context, 'primary'),
              ),
          ],
        ),
      ),
    );
  }
}
