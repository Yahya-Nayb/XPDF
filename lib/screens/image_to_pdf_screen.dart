import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../colors.dart';
import '../providers/image_to_pdf_provider.dart';
import '../providers/recent_files_provider.dart';
import '../widgets/image_preview_grid.dart';
import 'pdf_viewer_screen.dart';

/// Full-screen flow for converting user-selected images into a single PDF.
///
/// The [ImageToPdfProvider] is created locally via `ChangeNotifierProvider`
/// so the conversion state is self-contained and disposed automatically when
/// the screen is popped — no global provider needed.
class ImageToPdfScreen extends StatelessWidget {
  const ImageToPdfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ImageToPdfProvider(),
      child: const _ImageToPdfView(),
    );
  }
}

class _ImageToPdfView extends StatelessWidget {
  const _ImageToPdfView();

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageToPdfProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.colorOf(context, 'background'),
          appBar: AppBar(
            title: const Text('Images to PDF'),
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
                  'Combine Images into PDF',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.colorOf(context, 'textPrimary'),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Turn your photos into a single PDF document.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.colorOf(context, 'textMuted'),
                  ),
                ),

                const SizedBox(height: 24),

                // -- Pick buttons (card/chip style) -------------------------
                Text(
                  'Select Images',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorOf(context, 'textPrimary'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PickCard(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: provider.pickFromGallery,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickCard(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        onTap: provider.pickFromCamera,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // -- Selected images grid -----------------------------------
                ImagePreviewGrid(
                  images: provider.selectedImages,
                  onRemove: provider.removeImage,
                  onAddMore: provider.pickFromGallery,
                ),

                const SizedBox(height: 24),

                // -- Convert button -----------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: provider.hasImages && !provider.isConverting
                        ? () => _convertAndShowResult(context, provider)
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
                    child: provider.isConverting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Convert to PDF',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

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

  /// Convert and then show the success bottom sheet.
  Future<void> _convertAndShowResult(
    BuildContext context,
    ImageToPdfProvider provider,
  ) async {
    await provider.convertToPdf();
    if (provider.hasGeneratedPdf && context.mounted) {
      _showSuccessSheet(context, provider);
    }
  }

  /// Modal bottom sheet shown after a successful conversion.
  void _showSuccessSheet(
    BuildContext context,
    ImageToPdfProvider provider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessBottomSheet(provider: provider),
    ).then((_) {
      // Dismissing the sheet (drag-down or tap outside) resets the state
      // so the user can start a fresh conversion.
      if (provider.hasGeneratedPdf) {
        provider.reset();
      }
    });
  }
}

// =============================================================================
// Success bottom sheet
// =============================================================================

/// Modal bottom sheet displayed after PDF generation succeeds.
///
/// Shows a checkmark, file details, Open/Share actions, and a "Done" dismiss.
/// Uses the [provider] passed directly — NOT a Consumer, because this sheet
/// lives in a separate overlay route outside the ChangeNotifierProvider.
class _SuccessBottomSheet extends StatelessWidget {
  final ImageToPdfProvider provider;

  const _SuccessBottomSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.colorOf(context, 'surface'),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
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
                color: AppColors.colorOf(context, 'border'),
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
              'PDF Created Successfully!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            // -- Subtitle with details ---------------------------------
            FutureBuilder<int>(
              future: provider.generatedPdfPath != null
                  ? File(provider.generatedPdfPath!).length()
                  : null,
              builder: (context, snapshot) {
                final sizeStr = snapshot.hasData
                    ? _formatFileSize(snapshot.data!)
                    : '';
                final count = provider.selectedImages.length;
                final detail = sizeStr.isNotEmpty
                    ? '$count images combined  \u00B7  $sizeStr'
                    : '$count images combined';
                return Text(
                  detail,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.colorOf(context, 'textMuted'),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // -- Open PDF (primary) ------------------------------------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // close sheet
                  await _openPdf(context, provider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.colorOf(context, 'primary'),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Open PDF',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // -- Share PDF (outlined) ----------------------------------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  _sharePdf(provider);
                },
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(
                  'Share PDF',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      AppColors.colorOf(context, 'primary'),
                  side: BorderSide(
                    color: AppColors.colorOf(context, 'primary'),
                  ),
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
                  color: AppColors.colorOf(context, 'textMuted'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Add the generated PDF to the recent-files list and open it in the viewer.
  Future<void> _openPdf(
    BuildContext context,
    ImageToPdfProvider prov,
  ) async {
    final path = prov.generatedPdfPath!;
    final file = File(path);
    final size = await file.length();
    final name = path.split('/').last;

    if (!context.mounted) return;

    final recent = await context.read<RecentFilesProvider>().addLocalFile(
          path: path,
          name: name,
          size: size,
        );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfViewerScreen(file: recent)),
      );
    }
  }

  /// Share the generated PDF without adding it to recent files.
  void _sharePdf(ImageToPdfProvider prov) {
    SharePlus.instance.share(
      ShareParams(files: [XFile(prov.generatedPdfPath!)]),
    );
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// =============================================================================
// Pick card (Gallery / Camera)
// =============================================================================

/// Card-style tappable chip for picking images. Matches the app's card
/// visual language (border, borderRadius 14, shadow on light mode).
class _PickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: AppColors.colorOf(context, 'primary'),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
