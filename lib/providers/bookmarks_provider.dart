import 'package:flutter/foundation.dart';

import '../models/pdf_bookmark.dart';
import '../services/storage_service.dart';

/// Central state for user-created page bookmarks.
///
/// Mirrors [AnnotationsProvider]'s structure exactly: an in-memory list
/// hydrated once at app start, whole-list persistence under the
/// "pdf_bookmarks" key, and notifyListeners() after every mutation.
///
/// Bookmarks are grouped by file path in memory through
/// [bookmarksForFile] — the stored blob is one flat list, so per-file
/// reads are a simple filter (same strategy as folders/recent files).
class BookmarksProvider extends ChangeNotifier {
  List<PdfBookmark> _bookmarks = [];
  bool _loaded = false;

  // -- Public getters --------------------------------------------------------

  List<PdfBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  bool get isLoaded => _loaded;

  /// Look up a bookmark by id, or `null` if it no longer exists.
  PdfBookmark? byId(String id) {
    final matches = _bookmarks.where((b) => b.id == id).toList();
    return matches.isEmpty ? null : matches.first;
  }

  /// All bookmarks for [filePath], sorted by page number so the panel and
  /// per-page lookups stay deterministic (oldest first within a page).
  List<PdfBookmark> bookmarksForFile(String filePath) {
    final list = _bookmarks.where((b) => b.filePath == filePath).toList()
      ..sort((a, b) {
        final byPage = a.pageNumber.compareTo(b.pageNumber);
        return byPage != 0
            ? byPage
            : a.createdAt.compareTo(b.createdAt);
      });
    return list;
  }

  /// Whether [filePath] already has a bookmark on [pageNumber].
  bool isBookmarked(String filePath, int pageNumber) =>
      _bookmarks.any((b) => b.filePath == filePath && b.pageNumber == pageNumber);

  /// The existing bookmark for [filePath] on [pageNumber], if any.
  PdfBookmark? bookmarkOn(String filePath, int pageNumber) {
    for (final b in _bookmarks) {
      if (b.filePath == filePath && b.pageNumber == pageNumber) return b;
    }
    return null;
  }

  // -- Initialization --------------------------------------------------------

  /// Called once at app start to hydrate the whole list from disk.
  Future<void> loadAll() async {
    _bookmarks = await StorageService.loadBookmarks();
    _loaded = true;
    if (kDebugMode) {
      debugPrint(
        '[Bookmarks] loadAll ← disk: ${_bookmarks.length} bookmark(s) across '
        '${_bookmarks.map((b) => b.filePath).toSet().length} file(s)',
      );
    }
    notifyListeners();
  }

  /// Ensure bookmarks are hydrated, scoped to [filePath]'s list.
  ///
  /// Safe to call from the viewer on open: after the one-time startup load
  /// this is a no-op, so re-opening a file never re-reads from disk.
  Future<void> loadBookmarks(String filePath) async {
    if (_loaded) return;
    await loadAll();
  }

  // -- Core operations -------------------------------------------------------

  /// Add a newly created bookmark and persist the whole list.
  Future<void> addBookmark(PdfBookmark bookmark) async {
    _bookmarks.add(bookmark);
    await StorageService.saveBookmarks(_bookmarks);
    notifyListeners();
  }

  /// Remove a bookmark by [id] and persist. The PDF file itself is never
  /// touched — bookmarks are app-side only.
  Future<void> removeBookmark(String id) async {
    _bookmarks.removeWhere((b) => b.id == id);
    await StorageService.saveBookmarks(_bookmarks);
    notifyListeners();
  }

  /// Set (or clear) the optional label on a bookmark and persist.
  Future<void> updateBookmarkLabel(String id, String? label) async {
    final index = _bookmarks.indexWhere((b) => b.id == id);
    if (index == -1) return;

    final trimmed = label?.trim();
    _bookmarks[index] = _bookmarks[index].withLabel(
      trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    await StorageService.saveBookmarks(_bookmarks);
    notifyListeners();
  }
}