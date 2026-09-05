import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// A successfully downloaded PDF, ready to be added to the recent list.
class DownloadedPdf {
  final String path;
  final String name;
  final int size;

  const DownloadedPdf({
    required this.path,
    required this.name,
    required this.size,
  });
}

/// Download failure with a message safe to show directly in the UI.
class DownloadException implements Exception {
  final String message;

  const DownloadException(this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around file_picker so screen code stays clean.
class FileService {
  /// Open the system file picker filtered to PDF files.
  ///
  /// Returns the full path of the chosen file, or `null` if the user cancelled.
  static Future<String?> pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result.isEmpty) return null;
    return result.first.path;
  }

  /// Get the file size in bytes for a given [path].
  static Future<int> getFileSize(String path) async {
    final file = File(path);
    return file.length();
  }

  // ---------------------------------------------------------------------------
  // URL download
  // ---------------------------------------------------------------------------

  /// Download a PDF from [url], save it in the app documents directory and
  /// return a [DownloadedPdf] ready for the recent-files list.
  ///
  /// Throws a [DownloadException] with a user-presentable message on any
  /// failure (bad URL, network error, HTTP error, or non-PDF content).
  static Future<DownloadedPdf> downloadPdfFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const DownloadException(
        'Please enter a valid http(s) URL.',
      );
    }

    // -- Fetch ----------------------------------------------------------------
    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const DownloadException(
        'The request timed out. Check your connection and try again.',
      );
    } on SocketException {
      throw const DownloadException(
        'No internet connection. Check your network and try again.',
      );
    } on http.ClientException {
      throw const DownloadException(
        'Could not reach the server. Check the URL and try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DownloadException(
        'The server returned an error (HTTP ${response.statusCode}). '
        'The link may be broken or require login.',
      );
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw const DownloadException(
        'The server returned an empty response.',
      );
    }

    // -- Content check --------------------------------------------------------
    // Accept when EITHER the content-type says application/pdf OR the bytes
    // start with "%PDF-". Servers frequently mislabel PDFs as
    // application/octet-stream, so the header alone would reject valid files;
    // the magic bytes are the reliable ground truth.
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final headerSaysPdf = contentType.contains('application/pdf');
    final magicSaysPdf = bytes.length >= 5 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
    if (!headerSaysPdf && !magicSaysPdf) {
      throw DownloadException(
        "That link isn't a PDF"
        '${contentType.isEmpty ? '' : ' (server said "$contentType")'}.',
      );
    }

    // -- Save -----------------------------------------------------------------
    final dir = await getApplicationDocumentsDirectory();
    var fileName = _fileNameFromUrl(uri);
    var filePath = '${dir.path}/$fileName';

    // Never overwrite an existing file's backing data — a same-named but
    // different download would corrupt the older recent-list entry.
    if (File(filePath).existsSync()) {
      final base = fileName.substring(0, fileName.length - 4); // strip ".pdf"
      final stamp = DateTime.now().millisecondsSinceEpoch;
      filePath = '${dir.path}/${base}_$stamp.pdf';
    }

    await File(filePath).writeAsBytes(bytes);

    return DownloadedPdf(
      path: filePath,
      name: filePath.split('/').last,
      size: bytes.length,
    );
  }

  /// Derive a safe `.pdf` filename from a URL's last path segment.
  ///
  /// Falls back to `downloaded_<timestamp>.pdf` when the URL has no usable
  /// name (e.g. `/download?id=42`).
  static String _fileNameFromUrl(Uri uri) {
    var name = '';
    final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    try {
      name = Uri.decodeComponent(last);
    } on FormatException {
      name = last;
    }

    // Strip filesystem-hostile characters and control chars.
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();

    const maxBaseLength = 80;
    if (!name.toLowerCase().endsWith('.pdf')) {
      // Trim before appending so total length stays bounded.
      if (name.length > maxBaseLength - 4) {
        name = name.substring(0, maxBaseLength - 4);
      }
      name = '$name.pdf';
    }
    if (name.length > maxBaseLength + 4 || name == '.pdf') {
      name = 'downloaded_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
    return name;
  }

  // ---------------------------------------------------------------------------
  // Document scanning
  // ---------------------------------------------------------------------------

  /// Open the native document-scanner UI (auto edge detection, multi-page,
  /// perspective correction) and save the result as a single PDF in the app
  /// documents directory as `scan_<timestamp>.pdf`.
  ///
  /// The plugin exports a ready-made PDF (`asPdf: true`) — no manual
  /// image-to-PDF assembly needed. Its returned path lives in a plugin-owned
  /// cache, so the file is copied into persistent app storage first.
  ///
  /// Returns `null` when the user cancels or captures nothing. Throws a
  /// [ScanException] with a user-presentable message on permission denial or
  /// scanner/save failure.
  static Future<({String path, String name, int size})?>
      scanDocumentsToPdf() async {
    final List<String>? result;
    try {
      result = await CunningDocumentScanner.getPictures(asPdf: true);
    } on CunningDocumentScannerException {
      throw const ScanException(
        "Couldn't open the scanner. Camera access may be disabled — "
        'enable Camera for XPDF in system Settings and try again.',
      );
    }

    if (result == null || result.isEmpty) return null; // normal cancellation

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final targetPath = '${dir.path}/$fileName';

      final scanned = File(result.first);
      await scanned.copy(targetPath);

      // Free the plugin-owned cache copy; our copy is now the only one.
      await CunningDocumentScanner.cleanCache();

      final size = await File(targetPath).length();
      return (path: targetPath, name: fileName, size: size);
    } catch (_) {
      throw const ScanException("Couldn't save the scanned document.");
    }
  }
}

/// Scanner failure with a message safe to show directly in the UI.
class ScanException implements Exception {
  final String message;

  const ScanException(this.message);

  @override
  String toString() => message;
}
