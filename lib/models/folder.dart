import 'dart:convert';
import 'package:flutter/material.dart';

/// A user-created folder used to organize PDFs in the Library view.
///
/// Stored as a JSON map inside a JSON-encoded list in SharedPreferences,
/// exactly like [RecentFile] — simple fields, manual serialization, no
/// codegen. Files reference folders by [id]; a `null` folderId on a file
/// means "Uncategorized".
class Folder {
  /// Unique id (millisecond timestamp — sufficient for a personal-use app).
  final String id;

  /// User-facing display name (e.g. "Work").
  final String name;

  /// Folder accent color as a hex string (e.g. "#3A7BD5"), chosen from
  /// [colorPalette].
  final String colorHex;

  Folder({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  // ---------------------------------------------------------------------------
  // Fixed palette — ~6 pleasant accents from Folia's existing color family
  // (primary blue, PDF red, favorite gold, plus three harmonized companions).
  // No full color picker by design.
  // ---------------------------------------------------------------------------

  static const List<String> colorPalette = [
    '#3A7BD5', // Folia primary blue
    '#E0473C', // PDF badge red
    '#F6B93B', // Favorite star gold
    '#3BA776', // Calm green
    '#8E6FD8', // Soft purple
    '#2FB6A8', // Teal
  ];

  /// Parse a "#RRGGBB" hex string into an opaque [Color].
  static Color colorFromHex(String hex) {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  }

  /// This folder's accent color as a [Color].
  Color get color => colorFromHex(colorHex);

  // ---------------------------------------------------------------------------
  // JSON serialization — same manual pattern as RecentFile
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
      };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as String,
        name: json['name'] as String,
        colorHex: json['colorHex'] as String? ?? '#3A7BD5',
      );

  /// Encode a list of [Folder] objects into a single JSON string.
  static String encodeList(List<Folder> folders) =>
      jsonEncode(folders.map((f) => f.toJson()).toList());

  /// Decode a JSON string back into a list of [Folder] objects.
  static List<Folder> decodeList(String jsonString) {
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded
        .map((item) => Folder.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
