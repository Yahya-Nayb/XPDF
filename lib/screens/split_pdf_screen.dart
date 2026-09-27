import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../colors.dart';
import '../models/recent_file.dart';
import '../providers/recent_files_provider.dart';
import '../providers/split_pdf_provider.dart';
import '../services/pdf_manipulation_service.dart';
import 'pdf_viewer_screen.dart';

/// Full-screen flow for splitting a single PDF into multiple files.
///
/// The [SplitPdfProvider] is created locally via `ChangeNotifierProvider` so
/// the split state is self-contained and disposed automatically when the
/// screen is popped — no global provider needed.
class SplitPdfScreen extends StatelessWidget {
  const SplitPdfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SplitPdfProvider(),
      child: const _SplitPdfView(),
    );
  }
}

class _SplitPdfView extends StatefulWidget {
  const _SplitPdfView();

  @override
  State<_SplitPdfView> createState() => _SplitPdfViewState();
}

class _SplitPdfViewState extends State<_SplitPdfView> {
  final _rangesController = TextEditingController();

  @override
  void dispose() {
    _rangesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitPdfProvider>(
      builder: (context, provider, _) {
        final hasSource = provider.sourcePath != null;

        return Scaffold(
          backgroundColor: AppColors.colorOf(context, 'background'),
          appBar: AppBar(
            title: const Text('Split PDF'),
            backgroundColor: AppColors.colorOf(context, 'background'),
            elevation: 0,
            foregroundColor: AppColors.colorOf(context, 'textPrimary'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -- Screen header -----------------------------------------
                Text(
                  'Divide a PDF into Multiple Files',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.colorOf(context, 'textPrimary'),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Split every page into its own PDF, or into the page ranges '
                  'you define. Works fully on-device.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.colorOf(context, 'textMuted'),
                  ),
                ),

                const SizedBox(height: 24),

                // -- Pick source PDF ---------------------------------------
                Text(
                  'Select a PDF',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorOf(context, 'textPrimary'),
                  ),
                ),
                const SizedBox(height: 14),
                hasSource
                    ? _SourcePdfCard(
                        name: provider.sourceName!,
                        pageCount: provider.pageCount,
                        isLoading: provider.isLoadingInfo,
                        onRemove: provider.clearSource,
                      )
                    : _PickSourceCard(
                        onTap: provider.pickSource,
                        isLoading: provider.isLoadingInfo,
                      ),

                // -- Split settings (once we know the document) -----------
                if (hasSource && provider.pageCount != null) ...[
                  const SizedBox(height: 24),

                  // Mode toggle ------------------------------------------
                  Text(
                    'Split mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.colorOf(context, 'textPrimary'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<SplitMode>(
                      segments: const [
                        ButtonSegment(
                          value: SplitMode.individualPages,
                          label: Text('All pages'),
                          icon: Icon(Icons.view_agenda_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: SplitMode.customRanges,
                          label: Text('Custom ranges'),
                          icon: Icon(Icons.splitscreen_rounded, size: 18),
                        ),
                      ],
                      selected: {provider.mode},
                      onSelectionChanged: (selection) =>
                          provider.setMode(selection.first),
                      showSelectedIcon: false,
                    ),
                  ),

                  // Custom ranges input ----------------------------------
                  if (provider.mode == SplitMode.customRanges) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _rangesController,
                      onChanged: provider.setRangesText,
                      keyboardType: TextInputType.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.colorOf(context, 'textPrimary'),
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. 1-5, 6-10, 11-15',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: AppColors.colorOf(context, 'textMuted'),
                        ),
                        filled: true,
                        fillColor: AppColors.colorOf(context, 'inputFill'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.colorOf(context, 'primary'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pages are numbered 1 to ${provider.pageCount}. '
                      'Separate ranges with commas.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.colorOf(context, 'textMuted'),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // -- Split button ------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        hasSource &&
                            provider.pageCount != null &&
                            !provider.isSplitting
                        ? () => _splitAndShowResult(context, provider)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.colorOf(context, 'primary'),
                      disabledBackgroundColor:
                          AppColors.colorOf(context, 'primary')
                              .withValues(alpha: 0.4),
                      disabledForegroundColor: Colors.white,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: provider.isSplitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Split PDF',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                // -- Determinate progress for large files -----------------
                if (provider.isSplitting) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: provider.progress,
                      minHeight: 6,
                      backgroundColor:
                          AppColors.colorOf(context, 'border'),
                      color: AppColors.colorOf(context, 'primary'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Writing file ${provider.progressDone} of '
                      '${provider.progressTotal}…',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.colorOf(context, 'textMuted'),
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

  /// Run the split, add every output to Recents, then show the success sheet.
  Future<void> _splitAndShowResult(
    BuildContext context,
    SplitPdfProvider provider,
  ) async {
    // Capture the provider before any await so we never touch the BuildContext
    // across an async gap (the loop below awaits once per output file).
    final recentProvider = context.read<RecentFilesProvider>();

    await provider.split();
    if (!provider.hasOutputs || !context.mounted) return;

    final outputs = provider.outputPaths!;
    final recents = <RecentFile>[];
    for (final path in outputs) {
      final size = await File(path).length();
      final recent = await recentProvider.addLocalFile(
        path: path,
        name: path.split('/').last,
        size: size,
      );
      recents.add(recent);
    }

    if (!context.mounted) return;
    _showSuccessSheet(context, provider, recents);
  }

  /// Modal bottom sheet shown after a successful split.
  void _showSuccessSheet(
    BuildContext context,
    SplitPdfProvider provider,
    List<RecentFile> recents,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SuccessBottomSheet(
        recents: recents,
        onOpen: (recent) {
          // Pop the sheet first, then push the viewer from the screen's own
          // context (still mounted while the sheet is animating away).
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PdfViewerScreen(file: recent)),
          );
        },
        onShareAll: () {
          Navigator.pop(sheetContext);
          SharePlus.instance.share(
            ShareParams(
              files: [for (final r in recents) XFile(r.path)],
            ),
          );
        },
      ),
    ).then((_) {
      // Dismissing the sheet resets the screen so a fresh split can start.
      if (provider.hasOutputs) {
        _rangesController.clear();
        provider.reset();
      }
    });
  }
}

// =============================================================================
// Success bottom sheet
// =============================================================================

/// Modal bottom sheet displayed after splitting succeeds.
///
/// Lists every created file (tappable to open), offers a "Share PDFs" action
/// that shares them all at once, and a "Done" dismiss. All created files were
/// added to Recents before this sheet appears.
class _SuccessBottomSheet extends StatelessWidget {
  final List<RecentFile> recents;
  final void Function(RecentFile recent) onOpen;
  final VoidCallback onShareAll;

  const _SuccessBottomSheet({
    required this.recents,
    required this.onOpen,
    required this.onShareAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.colorOf(context, 'surface'),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Drag handle -------------------------------------------
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.colorOf(context, 'border'),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // -- Checkmark + title -------------------------------------
            Center(
              child: Container(
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
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Split Complete!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.colorOf(context, 'textPrimary'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${recents.length} ${recents.length == 1 ? 'file' : 'files'} '
                'created · tap a file to open it',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.colorOf(context, 'textMuted'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // -- List of created files ---------------------------------
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.colorOf(context, 'card'),
                  border:
                      Border.all(color: AppColors.colorOf(context, 'border')),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  // Bound the list so it scrolls internally instead of
                  // pushing the actions off screen.
                  height: (recents.length * 56).clamp(0, 5 * 56).toDouble(),
                  child: ListView.separated(
                    itemCount: recents.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.colorOf(context, 'border'),
                    ),
                    itemBuilder: (context, index) {
                      final recent = recents[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        onTap: () => onOpen(recent),
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.colorOf(
                              context,
                              'pdfBadgeBg',
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_outlined,
                            color: AppColors.colorOf(context, 'pdfIcon'),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          recent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.colorOf(context, 'textPrimary'),
                          ),
                        ),
                        subtitle: Text(
                          recent.formattedSize,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.colorOf(context, 'textMuted'),
                          ),
                        ),
                        trailing: Icon(
                          Icons.open_in_full_rounded,
                          color: AppColors.colorOf(context, 'textMuted'),
                          size: 18,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // -- Share PDFs (primary) -----------------------------------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onShareAll,
                icon: const Icon(Icons.share_rounded, size: 20),
                label: Text(
                  recents.length == 1 ? 'Share PDF' : 'Share PDFs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorOf(context, 'surface'),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorOf(context, 'primary'),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // -- Done (text dismiss) -----------------------------------
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.colorOf(context, 'textMuted'),
                  ),
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
// Source cards: empty state + picked file
// =============================================================================

/// Tappable card shown before a PDF is picked.
class _PickSourceCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _PickSourceCard({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.colorOf(context, 'card'),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.colorOf(context, 'border')),
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
                color: AppColors.colorOf(context, 'inputFill'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.colorOf(context, 'primary'),
                      ),
                    )
                  : Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.colorOf(context, 'primary'),
                      size: 24,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading ? 'Reading page count…' : 'Choose a PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.colorOf(context, 'textPrimary'),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLoading
                        ? 'Opening the selected file'
                        : 'Select the file you want to split',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.colorOf(context, 'textMuted'),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoading)
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.colorOf(context, 'textMuted'),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// Card showing the picked source PDF and its page count.
class _SourcePdfCard extends StatelessWidget {
  final String name;
  final int? pageCount;
  final bool isLoading;
  final VoidCallback onRemove;

  const _SourcePdfCard({
    required this.name,
    required this.pageCount,
    required this.isLoading,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.colorOf(context, 'card'),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.colorOf(context, 'border')),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.colorOf(context, 'pdfBadgeBg'),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.colorOf(context, 'pdfIcon'),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorOf(context, 'textPrimary'),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLoading
                      ? 'Reading page count…'
                      : pageCount != null
                          ? '$pageCount ${pageCount == 1 ? 'page' : 'pages'}'
                          : '',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.colorOf(context, 'textMuted'),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.colorOf(context, 'textMuted'),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}