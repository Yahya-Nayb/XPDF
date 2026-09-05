import 'dart:convert';

import 'package:intl/intl.dart';

/// Represents a single PDF that the user has opened.
///
/// Stored as a JSON map inside a JSON-encoded list in SharedPreferences.
/// Fields are intentionally simple — no database, no complex schema.
class RecentFile {
  /// Full device path to the PDF (e.g. /storage/emulated/0/Download/doc.pdf)
  final String path;

  /// Display name (filename without the path prefix)
  final String name;

  /// File size in bytes — formatted for display elsewhere
  final int size;

  /// ISO-8601 string of when the file was last opened
  final String lastOpened;

  /// The page number the user was on when they last closed the viewer (1-indexed)
  final int lastPage;

  /// Whether the user has starred this file as a favorite.
  final bool isFavorite;

  /// Id of the folder this file belongs to, or `null` for Uncategorized.
  final String? folderId;

  RecentFile({
    required this.path,
    required this.name,
    required this.size,
    required this.lastOpened,
    this.lastPage = 1,
    this.isFavorite = false,
    this.folderId,
  });

  // ---------------------------------------------------------------------------
  // JSON serialization — manual, no third-party codegen needed
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'size': size,
    'lastOpened': lastOpened,
    'lastPage': lastPage,
    'isFavorite': isFavorite,
    'folderId': folderId,
  };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
    path: json['path'] as String,
    name: json['name'] as String,
    size: json['size'] as int,
    lastOpened: json['lastOpened'] as String,
    lastPage: json['lastPage'] as int? ?? 1,

    // Old saved data (pre-favorites) has no such key — fall back to false
    // so existing users' lists load without crashing.
    isFavorite: json['isFavorite'] as bool? ?? false,

    // Old saved data (pre-folders) has no such key — falls back to null,
    // which means Uncategorized. Same safety pattern as isFavorite.
    folderId: json['folderId'] as String?,
  );

  /// Encode a list of [RecentFile] objects into a single JSON string
  /// suitable for storing in SharedPreferences.
  static String encodeList(List<RecentFile> files) =>
      jsonEncode(files.map((f) => f.toJson()).toList());

  /// Decode a JSON string back into a list of [RecentFile] objects.
  static List<RecentFile> decodeList(String jsonString) {
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded
        .map((item) => RecentFile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Copy helpers
  // ---------------------------------------------------------------------------

  /// Returns a copy of this file marked as favorite.
  ///
  /// Used by the provider when re-adding an existing entry so its saved
  /// favorite state isn't lost. The folder assignment is carried over too.
  RecentFile withFavorite() => RecentFile(
    path: path,
    name: name,
    size: size,
    lastOpened: lastOpened,
    lastPage: lastPage,
    isFavorite: true,
    folderId: folderId,
  );

  /// Returns a copy of this file assigned to [folderId]
  /// (or Uncategorized when `null`).
  RecentFile withFolder(String? folderId) => RecentFile(
    path: path,
    name: name,
    size: size,
    lastOpened: lastOpened,
    lastPage: lastPage,
    isFavorite: isFavorite,
    folderId: folderId,
  );

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  /// Format file size in human-readable form (e.g. "2.4 MB").
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Friendly relative date string like "2 hours ago", "Yesterday", "Aug 12".
  String get relativeDate {
    final date = DateTime.parse(lastOpened);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    // Older than a week — show the date
    return DateFormat('MMM d').format(date);
  }

  /// Full date for tooltip / future detail views.
  String get fullDate =>
      DateFormat('MMM d, yyyy  h:mm a').format(DateTime.parse(lastOpened));
}
