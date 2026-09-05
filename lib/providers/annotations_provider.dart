import 'package:flutter/foundation.dart';

import '../models/pdf_annotation.dart';
import '../services/storage_service.dart';

/// Central state for user-created PDF highlight annotations.
///
/// Mirrors [RecentFilesProvider]'s structure exactly: an in-memory list
/// hydrated once at app start, whole-list persistence under the
/// "pdf_annotations" key, and notifyListeners() after every mutation.
///
/// Annotations are grouped by file path in memory through
/// [annotationsForFile] — the stored blob is one flat list, so per-file
/// reads are a simple filter (same strategy as folders/recent files).
class AnnotationsProvider extends ChangeNotifier {
  List<PdfAnnotation> _annotations = [];
  bool _loaded = false;

  // Monotonically increasing counter bumped on every change. Lets consumers
  // (e.g. the PDF viewer's overlay builder) cheaply detect whether anything
  // changed without deep-comparing lists.
  int _version = 0;
  int get version => _version;

  // -- Public getters --------------------------------------------------------

  @override
  void notifyListeners() {
    _version++;
    super.notifyListeners();
  }

  List<PdfAnnotation> get annotations => List.unmodifiable(_annotations);
  bool get isLoaded => _loaded;

  /// Look up an annotation by id, or `null` if it no longer exists.
  PdfAnnotation? byId(String id) {
    final matches = _annotations.where((a) => a.id == id).toList();
    return matches.isEmpty ? null : matches.first;
  }

  /// All annotations for [filePath], sorted by page number so the panel and
  /// per-page lookups stay deterministic.
  List<PdfAnnotation> annotationsForFile(String filePath) {
    final list = _annotations.where((a) => a.filePath == filePath).toList()
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    return list;
  }

  // -- Initialization --------------------------------------------------------

  /// Called once at app start to hydrate the whole list from disk.
  Future<void> loadAll() async {
    _annotations = await StorageService.loadAnnotations();
    _loaded = true;
    if (kDebugMode) {
      debugPrint(
        '[Annotations] loadAll ← disk: ${_annotations.length} '
        'annotations across '
        '${_annotations.map((a) => a.filePath).toSet().length} file(s)',
      );
    }
    notifyListeners();
  }

  /// Ensure annotations are hydrated, scoped to [filePath]'s list.
  ///
  /// Safe to call from the viewer on open: after the one-time startup load
  /// this is a no-op, so re-opening a file never re-reads from disk.
  Future<void> loadAnnotations(String filePath) async {
    if (_loaded) return;
    await loadAll();
  }

  // -- Core operations -------------------------------------------------------

  /// Add a newly created highlight and persist the whole list.
  Future<void> addAnnotation(PdfAnnotation annotation) async {
    _annotations.add(annotation);
    await StorageService.saveAnnotations(_annotations);
    notifyListeners();
  }

  /// Remove an annotation by [id] and persist. The PDF file itself is never
  /// touched — annotations are app-side only.
  Future<void> removeAnnotation(String id) async {
    _annotations.removeWhere((a) => a.id == id);
    await StorageService.saveAnnotations(_annotations);
    notifyListeners();
  }

  /// Change an annotation's highlight color and persist.
  Future<void> updateAnnotationColor(String id, String colorHex) =>
      _editAnnotation(id, colorHex: colorHex);

  /// Set the user note on an annotation and persist. Pass `null` to clear it.
  Future<void> updateAnnotationNote(String id, String? note) =>
      _editAnnotation(id, note: note, clearNote: note == null);

  Future<void> _editAnnotation(
    String id, {
    String? colorHex,
    String? note,
    bool clearNote = false,
  }) async {
    final index = _annotations.indexWhere((a) => a.id == id);
    if (index == -1) return;

    final old = _annotations[index];
    _annotations[index] = PdfAnnotation(
      id: old.id,
      filePath: old.filePath,
      pageNumber: old.pageNumber,
      rects: old.rects,
      colorHex: colorHex ?? old.colorHex,
      createdAt: old.createdAt,
      textSnippet: old.textSnippet,
      note: clearNote ? null : (note ?? old.note),
    );
    await StorageService.saveAnnotations(_annotations);
    notifyListeners();
  }
}
