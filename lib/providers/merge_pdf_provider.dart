import 'package:flutter/foundation.dart';

import '../services/file_service.dart';
import '../services/pdf_manipulation_service.dart';

/// Holds the mutable state for the Merge PDFs screen.
///
/// Created locally inside [MergePdfScreen] via `ChangeNotifierProvider`
/// (not in the global MultiProvider) because the state is only needed while
/// that screen is active. Each new session starts fresh.
class MergePdfProvider extends ChangeNotifier {
  List<String> _paths = [];
  bool _isMerging = false;
  String? _mergedFilePath;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Selected source PDF paths, in merge order (index 0 merges first).
  List<String> get paths => List.unmodifiable(_paths);
  bool get isMerging => _isMerging;
  bool get hasEnoughFiles => _paths.length >= 2;
  String? get mergedFilePath => _mergedFilePath;
  bool get hasMerged => _mergedFilePath != null;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Open the picker and append the chosen PDFs to the merge list.
  ///
  /// Duplicates are skipped so the same file can't be merged twice.
  Future<void> pickPdfs() async {
    try {
      final picked = await FileService.pickPdfFiles();
      if (picked.isEmpty) return;

      final existing = _paths.toSet();
      final added = picked.where((p) => !existing.contains(p)).toList();
      if (added.isEmpty) return;

      _paths.addAll(added);
      _errorMessage = null;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Could not open the file picker. Please try again.';
      notifyListeners();
    }
  }

  /// Remove a single source by its full [path].
  void removePath(String path) {
    _paths.remove(path);
    // A merge built from the now-changed list is stale — clear it.
    _mergedFilePath = null;
    notifyListeners();
  }

  /// Re-order the merge list: index 0 merges first.
  ///
  /// [newIndex] arrives pre-adjusted by the reorder widget (it is already the
  /// final insertion index after the item is removed).
  void move(int oldIndex, int newIndex) {
    final item = _paths.removeAt(oldIndex);
    _paths.insert(newIndex, item);
    _mergedFilePath = null;
    notifyListeners();
  }

  /// Merge the currently selected PDFs into a single output file.
  Future<void> merge() async {
    if (!hasEnoughFiles) return;

    _isMerging = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final name = 'merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await PdfManipulationService.mergePdfs(_paths, name);
      _mergedFilePath = file.path;
      _errorMessage = null;
    } on PdfManipulationException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    }

    _isMerging = false;
    notifyListeners();
  }

  /// Reset all state back to the initial empty state.
  void reset() {
    _paths = [];
    _isMerging = false;
    _mergedFilePath = null;
    _errorMessage = null;
    notifyListeners();
  }
}