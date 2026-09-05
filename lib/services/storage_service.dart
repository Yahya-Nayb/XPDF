import 'package:shared_preferences/shared_preferences.dart';

import '../models/recent_file.dart';
import '../models/folder.dart';
import '../models/pdf_annotation.dart';

/// Handles all reads and writes to SharedPreferences.
///
/// The entire recent-files list is stored as a single JSON string under
/// the key "recent_files". Folders are stored separately under "folders"
/// so the two lists never mix. Dark mode preference is stored separately
/// under the key "dark_mode". PDF highlight annotations live under their own
/// "pdf_annotations" key so they never collide with any of the above.
class StorageService {
  static const String _recentFilesKey = 'recent_files';
  static const String _foldersKey = 'folders';
  static const String _darkModeKey = 'dark_mode';
  static const String _annotationsKey = 'pdf_annotations';

  // Reading-defaults settings (Settings screen). The page-layout value is a
  // plain string: "single" or "continuous" ("continuous" = current default).
  static const String _pageLayoutKey = 'default_page_layout';
  static const String _rememberLastPageKey = 'remember_last_page';

  // File-list sort order ("recent", "name_asc", "name_desc",
  // "size_largest", "size_smallest"). Default = insertion order recency.
  static const String _sortModeKey = 'sort_mode';

  // -- Recent files ----------------------------------------------------------

  /// Load the saved list of recent files.
  ///
  /// If nothing has been saved yet (first launch), returns an empty list.
  static Future<List<RecentFile>> loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_recentFilesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    return RecentFile.decodeList(jsonString);
  }

  /// Persist the full list of recent files.
  ///
  /// This always writes the *entire* list — simple and sufficient for
  /// the small number of files a personal-use app will track.
  static Future<void> saveRecentFiles(List<RecentFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentFilesKey, RecentFile.encodeList(files));
  }

  // -- Folders ---------------------------------------------------------------

  /// Load the saved list of folders.
  ///
  /// If nothing has been saved yet (first launch), returns an empty list.
  static Future<List<Folder>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_foldersKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    return Folder.decodeList(jsonString);
  }

  /// Persist the full list of folders (same whole-list strategy as recent
  /// files — simple and sufficient at this scale).
  static Future<void> saveFolders(List<Folder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_foldersKey, Folder.encodeList(folders));
  }

  // -- PDF annotations -------------------------------------------------------

  /// Load the saved list of highlight annotations.
  ///
  /// If nothing has been saved yet (first launch), returns an empty list.
  static Future<List<PdfAnnotation>> loadAnnotations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_annotationsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    return PdfAnnotation.decodeList(jsonString);
  }

  /// Persist the full list of annotations (same whole-list strategy; the
  /// annotations for every PDF share one key).
  static Future<void> saveAnnotations(List<PdfAnnotation> annotations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _annotationsKey,
      PdfAnnotation.encodeList(annotations),
    );
  }

  // -- Reading defaults ------------------------------------------------------

  /// Load the default page layout mode ("single" or "continuous").
  ///
  /// Falls back to "continuous" — pdfrx's built-in behavior, so users who
  /// never touch the setting see exactly what they saw before.
  static Future<String> loadPageLayoutMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pageLayoutKey) ?? 'continuous';
  }

  /// Persist the default page layout mode.
  static Future<void> savePageLayoutMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pageLayoutKey, mode);
  }

  /// Load the "remember last page" preference (defaults to `true` — the
  /// behavior the viewer always had before this setting existed).
  static Future<bool> loadRememberLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberLastPageKey) ?? true;
  }

  /// Persist the "remember last page" preference.
  static Future<void> saveRememberLastPage(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberLastPageKey, value);
  }

  // -- File-list sort order ----------------------------------------------------

  /// Load the saved sort mode. Falls back to "recent" (the list's original
  /// implicit behavior: most recently opened first).
  static Future<String> loadSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sortModeKey) ?? 'recent';
  }

  /// Persist the sort mode.
  static Future<void> saveSortMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortModeKey, mode);
  }

  // -- Dark mode -------------------------------------------------------------

  /// Load the saved dark-mode preference.
  ///
  /// Returns `true` (dark mode) on first launch or if nothing is stored.
  static Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? true;
  }

  /// Persist the dark-mode preference.
  static Future<void> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }
}
