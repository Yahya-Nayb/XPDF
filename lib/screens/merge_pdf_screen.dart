import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';
import '../models/recent_file.dart';
import '../providers/merge_pdf_provider.dart';
import '../providers/recent_files_provider.dart';
import 'pdf_viewer_screen.dart';

/// Full-screen flow for merging multiple PDFs into a single document.
///
/// The [MergePdfProvider] is created locally via `ChangeNotifierProvider` so the
/// merge state is self-contained and disposed automatically when the screen is
/// popped — no global provider needed.
class MergePdfScreen extends StatelessWidget {
  const MergePdfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MergePdfProvider(),
      child: const _MergePdfView(),
    );
  }
}

class _MergePdfView extends StatelessWidget {
  const _MergePdfView();

  @override
  Widget build(BuildContext context) {
    return Consumer<MergePdfProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Merge PDFs'),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -- Screen header -----------------------------------------
                Text(
                  'Combine PDFs into One',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Merge two or more PDF files into a single document. '
                  'Works fully on-device.',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

                // -- Pick PDFs ----------------------------------------------
                Text(
                  'Select PDFs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                _PickFileCard(onTap: provider.pickPdfs),

                // -- Merge order list ---------------------------------------
                if (provider.paths.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Merge order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${provider.paths.length} files · drag to reorder',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border:
                            Border.all(color: context.appColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SizedBox(
                        // Bound the list so it scrolls internally once it
                        // grows past ~6 files instead of pushing the button
                        // off screen.
                        height: (provider.paths.length * 64)
                            .clamp(0, 6 * 64)
                            .toDouble(),
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          shrinkWrap: true,
                          itemCount: provider.paths.length,
                          onReorderItem: provider.move,
                          itemBuilder: (context, index) {
                            final path = provider.paths[index];
                            return _MergeFileTile(
                              key: ValueKey(path),
                              index: index,
                              path: path,
                              onRemove: () => provider.removePath(path),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // -- Merge button -------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: provider.hasEnoughFiles && !provider.isMerging
                        ? () => _mergeAndShowResult(context, provider)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      disabledBackgroundColor:
                          Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.4),
                      disabledForegroundColor: Colors.white,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: provider.isMerging
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            provider.paths.length < 2
                                ? 'Select 2 or more PDFs'
                                : 'Merge ${provider.paths.length} PDFs',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                // -- Progress hint for large files --------------------------
                if (provider.isMerging) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Merging… this can take a moment for large files.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ),
                ],

                // -- Error banner -------------------------------------------
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Merge and then show the success bottom sheet.
  ///
  /// The merged file is added to Recents automatically so it shows up in the
  /// user's file list even if they just tap "Done".
  Future<void> _mergeAndShowResult(
    BuildContext context,
    MergePdfProvider provider,
  ) async {
    // Capture the provider before any await so we never touch the BuildContext
    // across an async gap.
    final recentProvider = context.read<RecentFilesProvider>();

    await provider.merge();
    if (!provider.hasMerged || !context.mounted) return;

    final path = provider.mergedFilePath!;
    final size = await File(path).length();

    final recent = await recentProvider.addLocalFile(
      path: path,
      name: path.split('/').last,
      size: size,
    );

    if (context.mounted) {
      _showSuccessSheet(context, provider, recent);
    }
  }

  /// Modal bottom sheet shown after a successful merge.
  void _showSuccessSheet(
    BuildContext context,
    MergePdfProvider provider,
    RecentFile recent,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SuccessBottomSheet(
        recent: recent,
        fileCount: provider.paths.length,
        onOpen: () {
          // Pop the sheet first, then push the viewer from the screen's own
          // context (still mounted while the sheet is animating away).
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PdfViewerScreen(file: recent)),
          );
        },
        onShare: () {
          Navigator.pop(sheetContext);
          SharePlus.instance.share(
            ShareParams(files: [XFile(recent.path)]),
          );
        },
      ),
    ).then((_) {
      // Dismissing the sheet (drag-down or tap outside) resets the state
      // so the user can start a fresh merge.
      if (provider.hasMerged) {
        provider.reset();
      }
    });
  }
}

// =============================================================================
// Success bottom sheet
// =============================================================================

/// Modal bottom sheet displayed after merging succeeds.
///
/// Shows a checkmark, file details, Open/Share actions, and a "Done" dismiss.
/// The merged file was already added to Recents before this sheet appears, so
/// Open just navigates to the viewer for the existing [RecentFile] entry.
class _SuccessBottomSheet extends StatelessWidget {
  final RecentFile recent;
  final int fileCount;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  const _SuccessBottomSheet({
    required this.recent,
    required this.fileCount,
    required this.onOpen,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // -- Drag handle -------------------------------------------
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // -- Checkmark icon ----------------------------------------
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFF2ECC71),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),

            // -- Title -------------------------------------------------
            const Text(
              'Merge Complete!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // -- Subtitle with details ---------------------------------
            Text(
              '$fileCount PDFs combined · ${recent.formattedSize}',
              style: TextStyle(
                fontSize: 14,
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            // -- Open PDF (primary) ------------------------------------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onOpen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Open PDF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // -- Share PDF (outlined) ----------------------------------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(
                  'Share PDF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // -- Done (text dismiss) -----------------------------------
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Done',
                style: TextStyle(
                  fontSize: 15,
                  color: context.appColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Pick card
// =============================================================================

/// Tappable card that opens the file picker to select more PDFs to merge.
class _PickFileCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PickFileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.note_add_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add PDFs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pick two or more files to merge',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Merge list tile
// =============================================================================

/// A single reorderable row in the merge-order list.
///
/// The leading drag handle is the only thing that starts a drag, so tapping
/// remove/title never conflicts with reordering.
class _MergeFileTile extends StatelessWidget {
  final int index;
  final String path;
  final VoidCallback onRemove;

  const _MergeFileTile({
    super.key,
    required this.index,
    required this.path,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle_rounded,
            color: context.appColors.textSecondary,
          ),
        ),
        title: Text(
          path.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: IconButton(
          onPressed: onRemove,
          icon: Icon(
            Icons.close_rounded,
            color: context.appColors.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }
}