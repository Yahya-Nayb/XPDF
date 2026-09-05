import 'package:flutter/material.dart';
import '../colors.dart';
import '../models/folder.dart';

/// Red used for the destructive Delete action — matches the app's
/// PDF-badge red so destructive items read consistently everywhere.
const Color _destructiveRed = Color(0xFFE0473C);

/// A colored card representing one folder in the Library grid.
///
/// Shows the folder's accent color (soft tint + solid icon), its name and
/// the number of files inside. Two paths lead to the same three actions:
/// a visible ⋮ button in the card's top-right corner (discoverable) and a
/// long-press action sheet (kept as a shortcut).
class FolderCard extends StatelessWidget {
  final Folder folder;
  final int fileCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRename;
  final VoidCallback onChangeColor;
  final VoidCallback onDelete;

  const FolderCard({
    super.key,
    required this.folder,
    required this.fileCount,
    required this.onTap,
    required this.onLongPress,
    required this.onRename,
    required this.onChangeColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = folder.color;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.colorOf(context, 'card'),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.colorOf(context, 'border')),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent icon chip + corner actions menu. The menu button wins
            // the gesture arena over the card's own tap handler, so opening
            // it never opens the folder.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_rounded, size: 22, color: color),
                ),
                const Spacer(),
                _CardMenu(
                  onRename: onRename,
                  onChangeColor: onChangeColor,
                  onDelete: onDelete,
                ),
              ],
            ),
            const Spacer(),

            // Name
            Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
            const SizedBox(height: 3),

            // File count
            Text(
              fileCount == 1 ? '1 file' : '$fileCount files',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.colorOf(context, 'textMuted'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small three-dot popup on a folder card: Rename / Change color /
/// Delete (destructive red). Mirrors the long-press action sheet's options.
class _CardMenu extends StatelessWidget {
  final VoidCallback onRename;
  final VoidCallback onChangeColor;
  final VoidCallback onDelete;

  const _CardMenu({
    required this.onRename,
    required this.onChangeColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: AppColors.colorOf(context, 'textMuted'),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'rename') onRename();
        if (value == 'color') onChangeColor();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18),
              SizedBox(width: 10),
              Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'color',
          child: Row(
            children: [
              Icon(Icons.palette_outlined, size: 18),
              SizedBox(width: 10),
              Text('Change color'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 44,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: _destructiveRed),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: _destructiveRed)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Long-press action sheet for a folder — same three actions as the card's
/// ⋮ menu, presented full-width for quick access.
Future<void> showFolderActionsSheet(
  BuildContext context, {
  required Folder folder,
  required VoidCallback onRename,
  required VoidCallback onChangeColor,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.colorOf(context, 'surface'),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_rounded,
                    size: 22, color: folder.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.colorOf(context, 'textPrimary'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              context,
              icon: Icons.edit_rounded,
              label: 'Rename',
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.palette_outlined,
              label: 'Change color',
              onTap: () {
                Navigator.pop(context);
                onChangeColor();
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildActionTile(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool destructive = false,
}) {
  final tileColor = destructive
      ? const Color(0xFFE0473C)
      : AppColors.colorOf(context, 'textPrimary');

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: tileColor),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: tileColor,
            ),
          ),
        ],
      ),
    ),
  );
}
