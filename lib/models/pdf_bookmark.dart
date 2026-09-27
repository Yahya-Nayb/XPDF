import 'dart:convert';

/// A single user-created page bookmark on a PDF.
///
/// Bookmarks are stored by the app (SharedPreferences as a JSON-encoded
/// list), never written back into the PDF file itself — the file on disk
/// stays untouched, exactly like [PdfAnnotation] highlights. [filePath]
/// associates a bookmark with the PDF it was made on, [pageNumber] is the
/// 1-indexed page to jump to, and [label] is an optional user-chosen name
/// (e.g. "Chapter 3 recap") shown in the bookmarks panel.
class PdfBookmark {
  /// Unique id (microsecond timestamp — sufficient for a personal-use app).
  final String id;

  /// Full device path of the PDF this bookmark belongs to.
  final String filePath;

  /// The bookmarked page (1-indexed).
  final int pageNumber;

  /// Optional user-written label ("Chapter 3 recap"). Null when the bookmark
  /// was saved with just the page number.
  final String? label;

  /// ISO-8601 string of when the bookmark was created.
  final DateTime createdAt;

  PdfBookmark({
    required this.id,
    required this.filePath,
    required this.pageNumber,
    this.label,
    required this.createdAt,
  });

  /// A copy with a new optional label (pass `null` to clear it).
  PdfBookmark withLabel(String? label) => PdfBookmark(
    id: id,
    filePath: filePath,
    pageNumber: pageNumber,
    label: label,
    createdAt: createdAt,
  );

  // ---------------------------------------------------------------------------
  // JSON serialization — manual, same pattern as PdfAnnotation/RecentFile
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'id': id,
    'filePath': filePath,
    'pageNumber': pageNumber,
    'label': label,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PdfBookmark.fromJson(Map<String, dynamic> json) => PdfBookmark(
    id: json['id'] as String,
    filePath: json['filePath'] as String,
    pageNumber: json['pageNumber'] as int,
    label: json['label'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  /// Encode a list of [PdfBookmark] objects into a single JSON string.
  static String encodeList(List<PdfBookmark> bookmarks) =>
      jsonEncode(bookmarks.map((b) => b.toJson()).toList());

  /// Decode a JSON string back into a list of [PdfBookmark] objects.
  static List<PdfBookmark> decodeList(String jsonString) {
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded
        .map((item) => PdfBookmark.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}