import 'package:flutter/foundation.dart';
import '../models/recent_file.dart';
import '../services/storage_service.dart';
import '../services/file_service.dart';

/// Central state for the recent-files list.
///
/// Any widget that calls `Provider.of<RecentFilesProvider>(context)` (or uses
/// the `context.watch<>()` / `context.read<>()` extensions) will rebuild
/// whenever this list changes.
class RecentFilesProvider extends ChangeNotifier {
  List<RecentFile> _files = [];
  bool _loaded = false;

  // -- Sort modes (persisted under the "sort_mode" key) ----------------------

  static const String sortRecentlyOpened = 'recent';
  static const String sortNameAsc = 'name_asc';
  static const String sortNameDesc = 'name_desc';
  static const String sortSizeLargest = 'size_largest';
  static const String sortSizeSmallest = 'size_smallest';

  static const Set<String> _validSortModes = {
    sortRecentlyOpened,
    sortNameAsc,
    sortNameDesc,
    sortSizeLargest,
    sortSizeSmallest,
  };

  String _sortMode = sortRecentlyOpened;

  /// Monotonically increasing counter that bumps every time the file list
  /// or sort mode changes. Lets consumers cheaply detect whether cached
  /// sorted/filtered results are still valid without deep-comparing lists.
  int _version = 0;
  int get version => _version;

  // -- Public getters --------------------------------------------------------

  // Auto-bump version on every notify so consumers can cache cheaply.
  @override
  void notifyListeners() {
    _version++;
    super.notifyListeners();
  }

  List<RecentFile> get files => List.unmodifiable(_files);
  List<RecentFile> get favoriteFiles =>
      _files.where((f) => f.isFavorite).toList();
  bool get isLoaded => _loaded;

  /// Current file-list sort mode. `sortRecentlyOpened` is the default.
  String get sortMode => _sortMode;
  bool get isDefaultSort => _sortMode == sortRecentlyOpened;

  // -- Initialization --------------------------------------------------------

  /// Called once at app start to hydrate the list from disk.
  Future<void> loadFiles() async {
    _files = await StorageService.loadRecentFiles();
    _sortMode = await StorageService.loadSortMode();
    _loaded = true;
    notifyListeners();
  }

  // -- Sorting -----------------------------------------------------------------

  /// Change the file-list sort order and persist it across restarts.
  Future<void> setSortMode(String mode) async {
    if (!_validSortModes.contains(mode) || mode == _sortMode) return;

    _sortMode = mode;
    await StorageService.saveSortMode(mode);
    notifyListeners();
  }

  /// Sort [files] according to the current [sortMode] preference.
  ///
  /// THE single sorting implementation for every file list in the app —
  /// Home's Recent list, the Favorites view, and Library folder contents all
  /// funnel through here so ordering can never drift between screens.
  /// Returns a new sorted list; the input is not mutated.
  List<RecentFile> sortFiles(List<RecentFile> files) {
    final sorted = List<RecentFile>.of(files);
    switch (_sortMode) {
      case sortNameAsc:
        sorted.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case sortNameDesc:
        sorted.sort((a, b) =>
            b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case sortSizeLargest:
        sorted.sort((a, b) => b.size.compareTo(a.size));
      case sortSizeSmallest:
        sorted.sort((a, b) => a.size.compareTo(b.size));
      case sortRecentlyOpened:
      default:
        // Newest first. The list is normally already in this order (entries
        // are inserted at index 0 on open), but an explicit sort keeps the
        // result deterministic even if that ever changes.
        sorted.sort(
          (a, b) => DateTime.parse(b.lastOpened)
              .compareTo(DateTime.parse(a.lastOpened)),
        );
    }
    return sorted;
  }

  // -- Core operations -------------------------------------------------------

  /// Pick a new PDF from the device and add it (or move it to the top).
  ///
  /// Returns the [RecentFile] if a file was picked, `null` otherwise.
  Future<RecentFile?> pickAndOpenPdf() async {
    final path = await FileService.pickPdfFile();
    if (path == null) return null;

    final size = await FileService.getFileSize(path);
    final name = path.split('/').last;

    final recent = RecentFile(
      path: path,
      name: name,
      size: size,
      lastOpened: DateTime.now().toIso8601String(),
      lastPage: 1,
    );

    _addOrUpdate(recent);
    return recent;
  }

  /// Add a PDF created locally by the app (URL download or document scan)
  /// to the recent list.
  ///
  /// Follows the same insert-or-move-to-front pattern as [pickAndOpenPdf].
  Future<RecentFile> addLocalFile({
    required String path,
    required String name,
    required int size,
  }) async {
    final recent = RecentFile(
      path: path,
      name: name,
      size: size,
      lastOpened: DateTime.now().toIso8601String(),
      lastPage: 1,
    );

    _addOrUpdate(recent);
    return recent;
  }

  /// Record that the user has opened a file — moves it to the top of the list.
  Future<void> openFile(String path, {String? name, int? size}) async {
    final existing = _files.where((f) => f.path == path);
    final recent = RecentFile(
      path: path,
      name: name ?? (existing.isNotEmpty ? existing.first.name : path.split('/').last),
      size: size ?? (existing.isNotEmpty ? existing.first.size : 0),
      lastOpened: DateTime.now().toIso8601String(),
      lastPage: existing.isNotEmpty ? existing.first.lastPage : 1,
    );

    _addOrUpdate(recent);
  }

  /// Save the page number the user is currently viewing for a given file.
  Future<void> updatePageNumber(String path, int page) async {
    final index = _files.indexWhere((f) => f.path == path);
    if (index == -1) return;

    final old = _files[index];
    _files[index] = RecentFile(
      path: old.path,
      name: old.name,
      size: old.size,
      lastOpened: old.lastOpened,
      lastPage: page,
      isFavorite: old.isFavorite,
      folderId: old.folderId,
    );
    await StorageService.saveRecentFiles(_files);
    notifyListeners();
  }

  /// Flip the favorite flag for a given file and persist the change.
  ///
  /// Mirrors [updatePageNumber]: rebuilds the entry in place, saves the whole
  /// list, then notifies listeners so the UI updates immediately.
  Future<void> toggleFavorite(String path) async {
    final index = _files.indexWhere((f) => f.path == path);
    if (index == -1) return;

    final old = _files[index];
    _files[index] = RecentFile(
      path: old.path,
      name: old.name,
      size: old.size,
      lastOpened: old.lastOpened,
      lastPage: old.lastPage,
      isFavorite: !old.isFavorite,
      folderId: old.folderId,
    );
    await StorageService.saveRecentFiles(_files);
    notifyListeners();
  }

  /// Assign a file to a folder (or back to Uncategorized with `null`)
  /// and persist the change.
  ///
  /// Mirrors [toggleFavorite]: rebuilds the entry in place, saves the whole
  /// list, then notifies listeners.
  Future<void> assignToFolder(String path, String? folderId) async {
    final index = _files.indexWhere((f) => f.path == path);
    if (index == -1) return;

    _files[index] = _files[index].withFolder(folderId);
    await StorageService.saveRecentFiles(_files);
    notifyListeners();
  }

  /// Move every file currently in [folderId] back to Uncategorized.
  ///
  /// Called when a folder is deleted — the files themselves are never
  /// touched, they just lose their assignment. Single save + single notify
  /// so the UI updates atomically.
  Future<void> clearFolder(String folderId) async {
    var changed = false;
    _files = _files
        .map((f) {
          if (f.folderId != folderId) return f;
          changed = true;
          return f.withFolder(null);
        })
        .toList();

    if (!changed) return;
    await StorageService.saveRecentFiles(_files);
    notifyListeners();
  }

  /// Remove a file from the recent list (does NOT delete the file from disk).
  Future<void> removeFile(String path) async {
    _files.removeWhere((f) => f.path == path);
    await StorageService.saveRecentFiles(_files);
    notifyListeners();
  }

  /// Remove several entries at once (does NOT delete files from disk).
  ///
  /// Used by "Clear all imported files" after it has deleted the physical
  /// files — single save + single notify so the UI updates atomically.
  /// Returns how many entries were removed.
  Future<int> removePaths(Iterable<String> paths) async {
    final targets = paths.toSet();
    final before = _files.length;
    _files.removeWhere((f) => targets.contains(f.path));
    final removed = before - _files.length;
    if (removed == 0) return 0;

    await StorageService.saveRecentFiles(_files);
    notifyListeners();
    return removed;
  }

  /// Empty the whole recent list WITHOUT deleting any files from disk.
  ///
  /// Folder assignments live on the entries themselves, so clearing the list
  /// implicitly drops them; folder objects remain (now empty).
  Future<void> clearAll() async {
    if (_files.isEmpty) return;
    _files.clear();
    await StorageService.saveRecentFiles(_files);
    notifyListeners();
  }

  // -- Helpers ---------------------------------------------------------------

  /// Insert or move-to-front logic used by [pickAndOpenPdf] and [openFile].
  ///
  /// If the file already exists in the list, its favorite state and folder
  /// assignment are carried over so re-opening it never silently un-favorites
  /// or un-files it.
  void _addOrUpdate(RecentFile file) {
    final existingIndex = _files.indexWhere((f) => f.path == file.path);
    final existing =
        existingIndex != -1 ? _files[existingIndex] : null;

    var updated = file;
    if (existing != null) {
      if (existing.isFavorite) updated = updated.withFavorite();
      // Incoming entries are always created fresh with `folderId == null`,
      // so only restore when there's something to restore.
      if (updated.folderId == null && existing.folderId != null) {
        updated = updated.withFolder(existing.folderId);
      }
    }

    _files.removeWhere((f) => f.path == file.path);
    _files.insert(0, updated);
    StorageService.saveRecentFiles(_files);
    notifyListeners();
  }
}
