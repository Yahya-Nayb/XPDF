import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../colors.dart';
import '../models/folder.dart';
import '../models/recent_file.dart';
import '../providers/folders_provider.dart';
import '../providers/recent_files_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/create_folder_dialog.dart';
import '../widgets/folder_card.dart';
import '../widgets/move_to_folder_sheet.dart';
import '../widgets/recent_file_card.dart';
import 'pdf_viewer_screen.dart';

/// The Library tab — a grid of user-created folders plus an Uncategorized
/// pseudo-folder.
///
/// Embedded inside [HomeScreen]'s scroll view (nav index 2), exactly like
/// the Favorites view — only tapping a folder pushes a full-screen
/// [FolderFilesScreen], which gets a natural back button.
class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _createFolder(BuildContext context) async {
    final draft = await showFolderDialog(context);
    if (draft == null || !context.mounted) return;
    context.read<FoldersProvider>().createFolder(draft.name, draft.colorHex);
  }

  Future<void> _renameFolder(BuildContext context, Folder folder) async {
    final draft = await showFolderDialog(
      context,
      title: 'Rename Folder',
      confirmLabel: 'Save',
      initialName: folder.name,
      initialColorHex: folder.colorHex,
    );
    if (draft == null || !context.mounted) return;
    context.read<FoldersProvider>().renameFolder(folder.id, draft.name);
  }

  /// Color-only dialog (name field hidden); the name is carried through
  /// unchanged and only the accent color is updated.
  Future<void> _changeFolderColor(
      BuildContext context, Folder folder) async {
    final draft = await showFolderDialog(
      context,
      title: 'Change Color',
      confirmLabel: 'Save',
      initialName: folder.name,
      initialColorHex: folder.colorHex,
      showNameField: false,
    );
    if (draft == null || !context.mounted) return;
    context
        .read<FoldersProvider>()
        .setFolderColor(folder.id, draft.colorHex);
  }

  Future<void> _deleteFolder(BuildContext context, Folder folder) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${folder.name}"?',
      message:
          'Files inside this folder won\'t be deleted — they will become '
          'Uncategorized.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;

    // The provider's injected callback un-categorizes the files; this call
    // site doesn't need to know about RecentFilesProvider at all.
    context.read<FoldersProvider>().deleteFolder(folder.id);
  }

  void _openFolder(BuildContext context, String? folderId, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderFilesScreen(folderId: folderId),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE: .select() narrows which provider changes trigger a rebuild.
    // FoldersProvider: only rebuild when the folder list itself changes.
    // RecentFilesProvider: only rebuild when file count/assignments change
    // (not on sort-mode or favorite toggles which don't affect folder counts).
    final folders = context.select<FoldersProvider, List<Folder>>(
      (p) => p.folders,
    );
    final files = context.select<RecentFilesProvider, List<RecentFile>>(
      (p) => p.files,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organize your PDFs into folders',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.colorOf(context, 'textMuted'),
            ),
          ),
          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              // "+ New Folder" card first
              _NewFolderCard(onTap: () => _createFolder(context)),

              // One card per user folder
              ...folders.map((folder) {
                final count =
                    files.where((f) => f.folderId == folder.id).length;
                return FolderCard(
                  key: ValueKey(folder.id),
                  folder: folder,
                  fileCount: count,
                  onTap: () =>
                      _openFolder(context, folder.id, folder.name),
                  onLongPress: () => showFolderActionsSheet(
                    context,
                    folder: folder,
                    onRename: () => _renameFolder(context, folder),
                    onChangeColor: () => _changeFolderColor(context, folder),
                    onDelete: () => _deleteFolder(context, folder),
                  ),
                  onRename: () => _renameFolder(context, folder),
                  onChangeColor: () => _changeFolderColor(context, folder),
                  onDelete: () => _deleteFolder(context, folder),
                );
              }),

              // Uncategorized pseudo-folder last
              _UncategorizedCard(
                fileCount: files.where((f) => f.folderId == null).length,
                onTap: () =>
                    _openFolder(context, null, 'Uncategorized'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Grid cards internal to the Library view
// -----------------------------------------------------------------------------

/// Dashed-style "+ New Folder" placeholder card.
class _NewFolderCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewFolderCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.colorOf(context, 'inputFill'),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.colorOf(context, 'border'),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.colorOf(context, 'card'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 22,
                color: AppColors.colorOf(context, 'primary'),
              ),
            ),
            const Spacer(),
            Text(
              'New Folder',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Group related PDFs',
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

/// Muted pseudo-folder card for files without a folder.
class _UncategorizedCard extends StatelessWidget {
  final int fileCount;
  final VoidCallback onTap;

  const _UncategorizedCard({required this.fileCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.colorOf(context, 'textMuted');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.colorOf(context, 'card'),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.colorOf(context, 'border')),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.folder_off_rounded,
                  size: 22, color: muted),
            ),
            const Spacer(),
            Text(
              'Uncategorized',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              fileCount == 1 ? '1 file' : '$fileCount files',
              style: TextStyle(
                fontSize: 12,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Folder detail screen
// -----------------------------------------------------------------------------

/// Full-screen filtered list of the files inside one folder.
///
/// Pushed as its own route so Android back gesture/button works naturally.
/// A null [folderId] shows the Uncategorized pseudo-folder.
class FolderFilesScreen extends StatefulWidget {
  /// `null` = show all uncategorized files.
  final String? folderId;

  const FolderFilesScreen({super.key, required this.folderId});

  @override
  State<FolderFilesScreen> createState() => _FolderFilesScreenState();
}

class _FolderFilesScreenState extends State<FolderFilesScreen> {
  bool _popping = false;

  void _openFile(RecentFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerScreen(file: file)),
    );
  }

  void _onMenuAction(String action, RecentFile file) {
    if (action == 'favorite') {
      context.read<RecentFilesProvider>().toggleFavorite(file.path);
    } else if (action == 'move') {
      showMoveToFolderSheet(context, file);
    } else if (action == 'remove') {
      context.read<RecentFilesProvider>().removeFile(file.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${file.name} removed from list'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final folder =
        widget.folderId == null
            ? null
            : context.watch<FoldersProvider>().byId(widget.folderId!);

    // If this folder was deleted while the screen is open (e.g. via a
    // long-press elsewhere), quietly return to the grid.
    if (folder == null && widget.folderId != null && !_popping) {
      _popping = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }

    final provider = context.watch<RecentFilesProvider>();
    final folderFiles = provider.sortFiles(
      provider.files.where((f) => f.folderId == widget.folderId).toList(),
    );
    final title = folder?.name ?? 'Uncategorized';
    final accent = folder?.color ?? AppColors.colorOf(context, 'textMuted');

    return Scaffold(
      backgroundColor: AppColors.colorOf(context, 'background'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Header with back button ---------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 26,
                      color: AppColors.colorOf(context, 'textPrimary'),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.folder_rounded,
                                size: 18, color: accent),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.colorOf(
                                      context, 'textPrimary'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          folderFiles.length == 1
                              ? '1 file'
                              : '${folderFiles.length} files',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.colorOf(context, 'textMuted'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // -- File list -------------------------------------------------
            Expanded(
              child: folderFiles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.folder_open_rounded,
                                size: 40,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No files here yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.colorOf(
                                    context, 'textPrimary'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Use the three-dot menu on any file\nand choose "Move to folder".',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: AppColors.colorOf(
                                    context, 'textMuted'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: folderFiles.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 0),
                      itemBuilder: (context, index) {
                        final file = folderFiles[index];
                        return RecentFileCard(
                          key: ValueKey(file.path),
                          file: file,
                          onTap: () => _openFile(file),
                          onMenuAction: (action) =>
                              _onMenuAction(action, file),
                          onToggleFavorite: () => context
                              .read<RecentFilesProvider>()
                              .toggleFavorite(file.path),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
