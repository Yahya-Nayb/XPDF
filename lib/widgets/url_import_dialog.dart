import 'package:flutter/material.dart';

import '../colors.dart';
import '../services/file_service.dart';

/// Amber used for the "doesn't look like a PDF" warning — readable on both
/// the light and dark palettes.
const _warningColor = Color(0xFFD97706);

/// Dialog for importing a PDF from a direct URL.
///
/// Shows a URL field with soft validation (warns when the URL doesn't end in
/// `.pdf` but still allows proceeding), an inline downloading state, and
/// user-presentable error messages with retry. Pops with a [DownloadedPdf]
/// on success, or `null` when cancelled/failed.
Future<DownloadedPdf?> showUrlImportDialog(BuildContext context) {
  return showDialog<DownloadedPdf>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const UrlImportDialog(),
  );
}

class UrlImportDialog extends StatefulWidget {
  const UrlImportDialog({super.key});

  @override
  State<UrlImportDialog> createState() => _UrlImportDialogState();
}

class _UrlImportDialogState extends State<UrlImportDialog> {
  final _controller = TextEditingController();
  bool _downloading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// True when the URL is non-empty but doesn't end in `.pdf`.
  ///
  /// Only a warning — some valid PDF links don't have the extension.
  bool get _showNotPdfWarning {
    final url = _controller.text.trim();
    return url.isNotEmpty && !url.toLowerCase().endsWith('.pdf');
  }

  Future<void> _download() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a URL first.');
      return;
    }

    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      final result = await FileService.downloadPdfFromUrl(url);
      if (!mounted) return;
      Navigator.pop(context, result);
    } on DownloadException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _downloading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while downloading. Please try again.';
        _downloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Block back/tap-outside dismissal mid-download so the fetch isn't orphaned.
    return PopScope(
      canPop: !_downloading,
      child: AlertDialog(
        backgroundColor: AppColors.colorOf(context, 'surface'),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Import from URL',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.colorOf(context, 'textPrimary'),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_downloading,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 15,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
              decoration: InputDecoration(
                hintText: 'https://example.com/file.pdf',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.colorOf(context, 'textMuted'),
                ),
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color: AppColors.colorOf(context, 'textMuted'),
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.colorOf(context, 'inputFill'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            // Soft validation warning — doesn't block download.
            if (_showNotPdfWarning && !_downloading) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: _warningColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "This doesn't look like a PDF link, but you can still try.",
                      style: TextStyle(
                        fontSize: 12,
                        color: _warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Inline error — stays visible until retried or dismissed manually.
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          if (_downloading)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 12),
                Text('Downloading...'),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.colorOf(context, 'textSecondary'),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _download,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        AppColors.colorOf(context, 'primary'),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
