import 'package:flutter/foundation.dart';

import '../services/file_service.dart';
import '../services/pdf_manipulation_service.dart';

/// Holds the mutable state for the Split PDF screen.
///
/// Created locally inside [SplitPdfScreen] via `ChangeNotifierProvider`
/// (not in the global MultiProvider) because the state is only needed while
/// that screen is active. Each new session starts fresh.
class SplitPdfProvider extends ChangeNotifier {
  String? _sourcePath;
  int? _pageCount;
  bool _isLoadingInfo = false;
  bool _isSplitting = false;
  int _progressDone = 0;
  int _progressTotal = 0;

  SplitMode _mode = SplitMode.individualPages;
  String _rangesText = '';
  List<String>? _outputPaths;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  String? get sourcePath => _sourcePath;
  String? get sourceName => _sourcePath?.split('/').last;
  int? get pageCount => _pageCount;
  bool get isLoadingInfo => _isLoadingInfo;
  bool get isSplitting => _isSplitting;
  int get progressDone => _progressDone;
  int get progressTotal => _progressTotal;
  double? get progress {
    if (!_isSplitting || _progressTotal == 0) return null;
    return (_progressDone / _progressTotal).clamp(0.0, 1.0);
  }

  SplitMode get mode => _mode;
  String get rangesText => _rangesText;
  List<String>? get outputPaths =>
      _outputPaths == null ? null : List.unmodifiable(_outputPaths!);
  bool get hasOutputs => (_outputPaths ?? []).isNotEmpty;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Pick the single PDF to split and read its page count.
  Future<void> pickSource() async {
    try {
      final path = await FileService.pickPdfFile();
      if (path == null) return;

      _sourcePath = path;
      _outputPaths = null;
      _errorMessage = null;
      _pageCount = null;
      _isLoadingInfo = true;
      notifyListeners();

      try {
        _pageCount = await PdfManipulationService.getPageCount(path);
      } on PdfManipulationException catch (e) {
        // Not a usable PDF — drop the selection and surface the reason.
        _errorMessage = e.message;
        _sourcePath = null;
      }

      _isLoadingInfo = false;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Could not open the file picker. Please try again.';
      notifyListeners();
    }
  }

  /// Clear the chosen source PDF.
  void clearSource() {
    _sourcePath = null;
    _pageCount = null;
    _outputPaths = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Switch between the split modes.
  void setMode(SplitMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _outputPaths = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Update the custom-ranges text field.
  void setRangesText(String value) {
    _rangesText = value;
    notifyListeners();
  }

  /// Run the split with the current selections.
  ///
  /// For [SplitMode.customRanges] the text field is parsed and validated here
  /// (bad syntax, reversed ranges and out-of-bounds ranges all fail with a
  /// clear message before any file is written).
  Future<void> split() async {
    final source = _sourcePath;
    final count = _pageCount;
    if (source == null || count == null || _isSplitting) return;

    List<PdfPageRange>? ranges;
    if (_mode == SplitMode.customRanges) {
      final parsed = _parseRanges(_rangesText, count);
      if (parsed == null) return; // _errorMessage already set
      ranges = parsed;
    }

    _isSplitting = true;
    _errorMessage = null;
    _progressDone = 0;
    _progressTotal = _mode == SplitMode.customRanges ? ranges!.length : count;
    notifyListeners();

    try {
      final files = await PdfManipulationService.splitPdf(
        source,
        _mode,
        pageRanges: ranges,
        onProgress: (done, total) {
          _progressDone = done;
          _progressTotal = total;
          notifyListeners();
        },
      );
      _outputPaths = [for (final f in files) f.path];
      _progressDone = 0;
      _progressTotal = 0;
    } on PdfManipulationException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    }

    _isSplitting = false;
    notifyListeners();
  }

  /// Reset all state back to the initial empty state.
  void reset() {
    _sourcePath = null;
    _pageCount = null;
    _isLoadingInfo = false;
    _isSplitting = false;
    _progressDone = 0;
    _progressTotal = 0;
    _mode = SplitMode.individualPages;
    _rangesText = '';
    _outputPaths = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Range parsing
  // ---------------------------------------------------------------------------

  /// Parse the custom-ranges text field ("1-5, 6-10, 11") into validated,
  /// 1-based [PdfPageRange]s. Returns `null` and sets [_errorMessage] when any
  /// token is malformed or out of bounds.
  List<PdfPageRange>? _parseRanges(String text, int pageCount) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Enter at least one page range, e.g. "1-5".';
      return null;
    }

    final ranges = <PdfPageRange>[];
    final pattern = RegExp(r'^\s*(\d+)\s*(?:-\s*(\d+)\s*)?$');
    for (final raw in trimmed.split(',')) {
      final match = pattern.firstMatch(raw);
      if (match == null) {
        _errorMessage = 'Couldn\'t read "$raw". Use the format "1-5, 6-10".';
        notifyListeners();
        return null;
      }

      final start = int.parse(match.group(1)!);
      final end = match.group(2) != null ? int.parse(match.group(2)!) : start;

      if (start < 1 || end < start) {
        _errorMessage =
            'Range "$raw" is invalid — start must be at least 1 and '
            'no greater than the end.';
        notifyListeners();
        return null;
      }
      if (end > pageCount) {
        _errorMessage =
            'Range "$raw" exceeds the document\'s $pageCount pages '
            '(pages are numbered 1 to $pageCount).';
        notifyListeners();
        return null;
      }

      ranges.add(PdfPageRange(start: start, end: end));
    }
    return ranges;
  }
}