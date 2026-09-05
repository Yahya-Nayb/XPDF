import 'package:flutter/foundation.dart';
import '../models/folder.dart';
import '../services/storage_service.dart';

/// Central state for the user-created folders.
///
/// Mirrors [RecentFilesProvider]'s structure exactly: an in-memory list
/// hydrated once at app start, whole-list persistence, and notifyListeners()
/// after every mutation.
///
/// Folder deletion coordinates with the recent-files list through the
/// [onFolderDeleted] callback injected at construction time (wired in
/// main.dart to `RecentFilesProvider.clearFolder`). This keeps this provider
/// completely unaware of RecentFilesProvider — no import, no circular
/// dependency, easy to test with a fake callback — while the UI still only
/// needs to call [deleteFolder] and everything stays consistent.
class FoldersProvider extends ChangeNotifier {
  List<Folder> _folders = [];
  bool _loaded = false;

  /// Invoked after a folder has been removed from storage so the owner of
  /// the callback can un-categorize its files.
  final void Function(String folderId)? onFolderDeleted;

  FoldersProvider({this.onFolderDeleted});

  // -- Public getters --------------------------------------------------------

  List<Folder> get folders => List.unmodifiable(_folders);
  bool get isLoaded => _loaded;

  /// Look up a folder by id, or `null` if it no longer exists.
  Folder? byId(String id) {
    final matches = _folders.where((f) => f.id == id).toList();
    return matches.isEmpty ? null : matches.first;
  }

  // -- Initialization --------------------------------------------------------

  /// Called once at app start to hydrate the list from disk.
  Future<void> loadFolders() async {
    _folders = await StorageService.loadFolders();
    _loaded = true;
    notifyListeners();
  }

  // -- Core operations -------------------------------------------------------

  /// Create a new folder with [name] and one of [Folder.colorPalette]'s
  /// hex colors. Returns the created folder.
  Future<Folder> createFolder(String name, String colorHex) async {
    final folder = Folder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      colorHex: colorHex,
    );

    _folders.add(folder);
    await StorageService.saveFolders(_folders);
    notifyListeners();
    return folder;
  }

  /// Rename a folder in place and persist.
  Future<void> renameFolder(String id, String newName) =>
      _editFolder(id, name: newName);

  /// Update a folder's accent color and persist (name unchanged).
  Future<void> setFolderColor(String id, String colorHex) =>
      _editFolder(id, colorHex: colorHex);

  Future<void> _editFolder(
    String id, {
    String? name,
    String? colorHex,
  }) async {
    final index = _folders.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final old = _folders[index];
    _folders[index] = Folder(
      id: old.id,
      name: name?.trim() ?? old.name,
      colorHex: colorHex ?? old.colorHex,
    );
    await StorageService.saveFolders(_folders);
    notifyListeners();
  }

  /// Delete a folder. The files inside it are NOT deleted — they become
  /// Uncategorized via the injected [onFolderDeleted] callback before this
  /// provider notifies, so both lists stay coherent within the same frame.
  Future<void> deleteFolder(String id) async {
    _folders.removeWhere((f) => f.id == id);
    await StorageService.saveFolders(_folders);
    onFolderDeleted?.call(id);
    notifyListeners();
  }
}
