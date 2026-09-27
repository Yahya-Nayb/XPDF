import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf_manipulator/io.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';

/// Failure with a message safe to show directly in the UI.
class PdfManipulationException implements Exception {
  final String message;

  const PdfManipulationException(this.message);

  @override
  String toString() => message;
}

/// How [PdfManipulationService.splitPdf] should divide the source document.
enum SplitMode {
  /// One output PDF per source page.
  individualPages,

  /// Outputs defined by the user's explicit [PdfPageRange]s.
  customRanges,

  /// Fixed-size chunks of [PdfManipulationService.splitPdf]'s `everyNPages`
  /// pages each (e.g. 5 pages → files of pages 1-5, 6-10, …).
  fixedChunks,
}

/// A single user-defined page range for splitting, **1-based and inclusive**
/// (so "1-5" is `PdfPageRange(start: 1, end: 5)`).
///
/// This matches the page numbers a user sees in a reader — the engine's
/// zero-based page indices are derived from it internally.
class PdfPageRange {
  final int start;
  final int end;

  const PdfPageRange({required this.start, required this.end});

  /// User-facing description of the range, e.g. `1-5`.
  String get display => '$start-$end';
}

/// Static methods for merging and splitting existing PDF files.
///
/// Powered by `pdf_manipulator` (a Rust/PDFium-free engine that copies PDF
/// page objects verbatim), so merged/split files keep their original fonts,
/// images and vector content — nothing is re-rendered as an image. All work
/// happens on-device; no network calls are made.
///
/// All output files are written to the app documents directory using the same
/// `prefix_<timestamp>…` naming convention as scanned/downloaded files.
class PdfManipulationService {
  /// Return the number of pages in the PDF at [filePath].
  ///
  /// Throws [PdfManipulationException] with a user-presentable message for
  /// password-protected or corrupt/unparseable files.
  static Future<int> getPageCount(String filePath) async {
    final pdf = Pdf();
    try {
      return await _pageCountOf(filePath, pdf);
    } finally {
      await pdf.dispose();
    }
  }

  /// Merge the PDFs at [filePaths] into a single document and save it as
  /// [outputName] inside the app documents directory.
  ///
  /// Source pages are appended in the order they appear in [filePaths] — the
  /// caller (the merge screen) passes them in the user's drag-reordered order.
  ///
  /// Returns the created [File]. Throws [PdfManipulationException] with a
  /// user-presentable message (naming the offending source when possible).
  static Future<File> mergePdfs(
    List<String> filePaths,
    String outputName,
  ) async {
    if (filePaths.length < 2) {
      throw const PdfManipulationException(
        'Select at least two PDFs to merge.',
      );
    }

    final pdf = Pdf();
    try {
      // Pre-open each source so password/corruption problems are reported
      // with the exact file's name.
      for (final path in filePaths) {
        await _pageCountOf(path, pdf);
      }

      final dir = await getApplicationDocumentsDirectory();
      final outputPath = '${dir.path}/$outputName';

      final sink = await FileSink.create(File(outputPath));
      try {
        await pdf.merge(
          [for (final path in filePaths) FileSource(File(path))],
          sink,
        );
      } finally {
        await sink.close();
      }

      return File(outputPath);
    } on PdfManipulationException {
      rethrow;
    } on PdfError catch (e) {
      throw _mapError(e);
    } catch (e) {
      throw PdfManipulationException('Failed to merge the PDFs: $e');
    } finally {
      await pdf.dispose();
    }
  }

  /// Split the PDF at [filePath] into multiple output files.
  ///
  /// The split strategy is chosen via [mode]:
  ///  * [SplitMode.individualPages] — one file per page.
  ///  * [SplitMode.customRanges] — one file per [PdfPageRange] in
  ///    [pageRanges] (validated against the document's page count).
  ///  * [SplitMode.fixedChunks] — one file per [everyNPages] pages.
  ///
  /// [onProgress] is invoked as each output file is finished with the running
  /// `(done, total)` counts so the UI can paint real progress.
  ///
  /// Returns the created files. Throws [PdfManipulationException] with a
  /// user-presentable message (password-protected source, corrupt file, or an
  /// out-of-bounds page range).
  static Future<List<File>> splitPdf(
    String filePath,
    SplitMode mode, {
    List<PdfPageRange>? pageRanges,
    int? everyNPages,
    void Function(int done, int total)? onProgress,
  }) async {
    final pdf = Pdf();
    try {
      final pageCount = await _pageCountOf(filePath, pdf);

      // Build the per-output job list. Each job is the (0-based) list of
      // source page indices that should land in one output file.
      final List<List<int>> jobs;
      final String Function(List<int> indices) labelFor;

      if (mode == SplitMode.customRanges) {
        final ranges = _validatedRanges(pageRanges, pageCount);
        jobs = [
          for (final r in ranges)
            [for (var i = r.start - 1; i <= r.end - 1; i++) i],
        ];
        // Label output files with their 1-based page span, e.g. p6-10.
        labelFor = (indices) =>
            'p${indices.first + 1}-${indices.last + 1}';
      } else if (mode == SplitMode.fixedChunks) {
        final n = everyNPages ?? 2;
        if (n < 1) {
          throw const PdfManipulationException(
            'Pages per file must be at least 1.',
          );
        }
        jobs = [
          for (var start = 0; start < pageCount; start += n)
            [for (var i = start; i < (start + n).clamp(0, pageCount); i++) i],
        ];
        labelFor = (indices) => 'p${indices.first + 1}-${indices.last + 1}';
      } else {
        jobs = [for (var i = 0; i < pageCount; i++) [i]];
        labelFor = (indices) => 'page${indices.first + 1}';
      }

      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final source = FileSource(File(filePath));
      final outputFiles = <File>[];

      for (var i = 0; i < jobs.length; i++) {
        final outputPath =
            '${dir.path}/split_${stamp}_${labelFor(jobs[i])}.pdf';
        final sink = await FileSink.create(File(outputPath));
        try {
          await pdf.extractPages(source, sink, pages: jobs[i]);
        } finally {
          await sink.close();
        }
        outputFiles.add(File(outputPath));
        onProgress?.call(i + 1, jobs.length);
      }

      return outputFiles;
    } on PdfManipulationException {
      rethrow;
    } on PdfError catch (e) {
      throw _mapError(e, fileName: _baseName(filePath));
    } catch (e) {
      throw PdfManipulationException('Failed to split the PDF: $e');
    } finally {
      await pdf.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Open [filePath] for reading, returning its page count.
  ///
  /// Throws [PdfManipulationException] naming the file when it is
  /// password-protected or corrupt/unparseable.
  static Future<int> _pageCountOf(String filePath, Pdf pdf) async {
    final name = _baseName(filePath);
    try {
      final doc = await pdf.open(FileSource(File(filePath)));
      final count = doc.pageCount;
      final requiresPassword = doc.requiresPassword;
      await doc.dispose();

      if (requiresPassword) {
        throw PdfManipulationException(
          '"$name" is password-protected and can\'t be processed. '
          'Remove the password and try again.',
        );
      }
      return count;
    } on PdfError catch (e) {
      if (e is PdfPasswordRequired || e is PdfWrongPassword) {
        throw PdfManipulationException(
          '"$name" is password-protected and can\'t be processed. '
          'Remove the password and try again.',
        );
      }
      throw _mapError(e, fileName: name);
    }
  }

  /// Validate user-supplied (1-based, inclusive) ranges against [pageCount],
  /// throwing a user-presentable message for any invalid range.
  static List<PdfPageRange> _validatedRanges(
    List<PdfPageRange>? ranges,
    int pageCount,
  ) {
    if (ranges == null || ranges.isEmpty) {
      throw const PdfManipulationException(
        'Enter at least one page range, e.g. "1-5".',
      );
    }

    final out = <PdfPageRange>[];
    for (final r in ranges) {
      if (r.start < 1 || r.end < r.start) {
        throw PdfManipulationException(
          'Range "${r.display}" is invalid — start must be at least 1 '
          'and no greater than the end.',
        );
      }
      if (r.end > pageCount) {
        throw PdfManipulationException(
          'Range "${r.display}" exceeds the document\'s $pageCount '
          'pages (pages are numbered 1 to $pageCount).',
        );
      }
      out.add(r);
    }
    return out;
  }

  /// Best-effort display name from a full path, robust to / and \\ separators.
  static String _baseName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    final name = segments.isNotEmpty ? segments.last : path;
    return name.isNotEmpty ? name : 'This PDF';
  }

  /// Convert any [PdfError]-family failure into a UI-safe message.
  static PdfManipulationException _mapError(
    Object error, {
    String? fileName,
  }) {
    if (error is PdfPasswordRequired || error is PdfWrongPassword) {
      final name = fileName ?? 'This PDF';
      return PdfManipulationException(
        '"$name" is password-protected and can\'t be processed. '
        'Remove the password and try again.',
      );
    }
    if (error is PdfCorrupted) {
      final name = fileName ?? 'This file';
      return PdfManipulationException(
        '"$name" is corrupt or not a valid PDF.',
      );
    }
    if (error is PdfPageRangeError) {
      return PdfManipulationException(
        'A page range goes outside the document. Check your ranges.',
      );
    }
    if (error is PdfError) {
      return PdfManipulationException(error.message);
    }
    return PdfManipulationException('An unexpected error occurred: $error');
  }
}