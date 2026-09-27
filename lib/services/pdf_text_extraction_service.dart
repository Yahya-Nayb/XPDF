import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// User-facing failure raised when a PDF cannot provide readable text.
class PdfTextExtractionException implements Exception {
  final String message;

  const PdfTextExtractionException(this.message);

  @override
  String toString() => message;
}

/// Extracts selectable text from every page of a local PDF.
class PdfTextExtractionService {
  const PdfTextExtractionService._();

  /// Reads [filePath] and returns its normalized text from all pages.
  ///
  /// Parsing runs in a background isolate because large PDFs can otherwise
  /// block animation and scrolling on Flutter's UI isolate.
  static Future<String> extractText(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const PdfTextExtractionException(
          'This PDF file could not be found on the device.',
        );
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const PdfTextExtractionException('This PDF file is empty.');
      }

      final text = await Isolate.run(() => _extractFromBytes(bytes));
      final normalized = text.replaceAll('\u0000', '').trim();

      if (normalized.isEmpty) {
        throw const PdfTextExtractionException(
          'No readable text was found. This may be a scanned or image-only '
          'PDF; OCR is not available yet.',
        );
      }

      return normalized;
    } on PdfTextExtractionException {
      rethrow;
    } on FileSystemException {
      throw const PdfTextExtractionException(
        'The PDF could not be read. Check that the file is still available.',
      );
    } catch (_) {
      throw const PdfTextExtractionException(
        'Text extraction failed for this PDF. It may be damaged, encrypted, '
        'or use an unsupported format.',
      );
    }
  }
}

/// Syncfusion extracts all pages when no page range is supplied.
String _extractFromBytes(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(document).extractText();
  } finally {
    document.dispose();
  }
}
