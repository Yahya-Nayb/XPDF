import 'dart:convert';

import 'package:flutter/material.dart';

/// A single user-created highlight annotation on a PDF page.
///
/// Annotations are stored by the app (SharedPreferences as a JSON-encoded
/// list), never written back into the PDF file itself — pdfrx has no support
/// for persisting highlights into the PDF bytes, so the file on disk stays
/// untouched. [filePath] associates an annotation with the PDF it was made on.
class PdfAnnotation {
  /// Unique id (microsecond timestamp — sufficient for a personal-use app).
  final String id;

  /// Full device path of the PDF this annotation belongs to
  /// (e.g. /storage/emulated/0/Download/doc.pdf).
  final String filePath;

  /// The page the highlight is on (1-indexed).
  final int pageNumber;

  /// One rectangle per selected line/word segment, in PDF page coordinates.
  final List<AnnotationRect> rects;

  /// Highlight color as a hex string (e.g. "#FDE047"), chosen from
  /// [colorPalette].
  final String colorHex;

  /// ISO-8601 string of when the highlight was created.
  final String createdAt;

  /// The selected text this highlight covers, cleaned for display
  /// (used by the annotations panel).
  final String? textSnippet;

  /// Optional user-written note attached to this highlight.
  final String? note;

  PdfAnnotation({
    required this.id,
    required this.filePath,
    required this.pageNumber,
    required this.rects,
    this.colorHex = defaultColorHex,
    required this.createdAt,
    this.textSnippet,
    this.note,
  });

  /// Default highlight color — a classic yellow highlighter.
  static const String defaultColorHex = '#FDE047';

  /// Fixed palette shown in the color picker. Kept simple on purpose
  /// (yellow/green/pink/blue), matching the app's no-full-picker style.
  static const List<String> colorPalette = [
    '#FDE047', // Yellow
    '#4ADE80', // Green
    '#F9A8D4', // Pink
    '#93C5FD', // Blue
  ];

  /// Parse a "#RRGGBB" hex string into an opaque [Color].
  static Color colorFromHex(String hex) {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  }

  /// This highlight's color as an opaque [Color]. Rendering layers on the
  /// translucency (call `withValues(alpha: ...)` at draw time) so the text
  /// stays readable underneath.
  Color get color => colorFromHex(colorHex);

  /// Whether this highlight carries a user-written note.
  bool get hasNote => note != null && note!.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // JSON serialization — manual, same pattern as RecentFile/Folder
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'id': id,
    'filePath': filePath,
    'pageNumber': pageNumber,
    'rects': rects.map((r) => r.toJson()).toList(),
    'colorHex': colorHex,
    'createdAt': createdAt,
    'textSnippet': textSnippet,
    'note': note,
  };

  factory PdfAnnotation.fromJson(Map<String, dynamic> json) => PdfAnnotation(
    id: json['id'] as String,
    filePath: json['filePath'] as String,
    pageNumber: json['pageNumber'] as int,
    rects: (json['rects'] as List<dynamic>? ?? const [])
        .map((r) => AnnotationRect.fromJson(r as Map<String, dynamic>))
        .toList(),
    // Old saved data may have no such key — fall back to yellow so
    // existing annotations still load (same safety pattern as isFavorite).
    colorHex: json['colorHex'] as String? ?? defaultColorHex,
    createdAt: json['createdAt'] as String,
    textSnippet: json['textSnippet'] as String?,
    note: json['note'] as String?,
  );

  /// Encode a list of [PdfAnnotation] objects into a single JSON string.
  static String encodeList(List<PdfAnnotation> annotations) =>
      jsonEncode(annotations.map((a) => a.toJson()).toList());

  /// Decode a JSON string back into a list of [PdfAnnotation] objects.
  static List<PdfAnnotation> decodeList(String jsonString) {
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded
        .map((item) => PdfAnnotation.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

/// One bounding rectangle of a highlight, stored in PDF page coordinates.
///
/// PDF page coordinates have their origin at the bottom-left corner with the
/// Y-axis pointing up. [x] is the left edge, [y] is the TOP edge (larger Y =
/// higher on the page) and [height] extends downward (toward the smaller Y /
/// bottom). This is exactly the coordinate space pdfrx reports text bounding
/// boxes in (`PdfRect`), so rects round-trip straight into rendering.
class AnnotationRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const AnnotationRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  // ---------------------------------------------------------------------------
  // JSON serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory AnnotationRect.fromJson(Map<String, dynamic> json) => AnnotationRect(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );
}
