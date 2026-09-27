import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xpdf/models/pdf_bookmark.dart';
import 'package:xpdf/providers/bookmarks_provider.dart';
import 'package:xpdf/providers/settings_provider.dart';
import 'package:xpdf/providers/recent_files_provider.dart';
import 'package:xpdf/services/storage_service.dart';

/// Stand-in for SettingsProvider's `rememberLastPage` so the test can toggle
/// it without tripping the analyzer's constant flow-narrowing on a local bool.
class _SimSettings {
  final bool on;
  const _SimSettings({this.on = true});
}

/// Mirrors the viewer's initState seed: `rememberLastPage ? lastPage : 1`.
int _seededPage(RecentFilesProvider recents, String path, _SimSettings settings) {
  return settings.on
      ? recents.files.firstWhere((f) => f.path == path).lastPage
      : 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Start with a clean SharedPreferences store (the app's own first-launch
    // state: no reading-default keys present).
    SharedPreferences.setMockInitialValues({});
  });

  test('BUG1 trace: page-layout setting persists and round-trips', () async {
    // Fresh provider (app start, nothing hydrated yet) → defaults.
    final provider = SettingsProvider();
    debugPrint('[Test] defaults before loadSettings: '
        'pageLayoutMode="${provider.pageLayoutMode}" '
        '(expect continuous)');
    expect(provider.pageLayoutMode, 'continuous');

    // User picks "Single" on the Settings screen.
    await provider.setPageLayoutMode('single');
    expect(provider.isSinglePageLayout, true);

    // Direct SharedPreferences re-read (proves the write went to disk, not
    // just memory): key "default_page_layout".
    final raw = await StorageService.loadPageLayoutMode();
    debugPrint('[Test] re-read from SharedPreferences: "$raw"');
    expect(raw, 'single');

    // Simulate an app RESTART: brand-new provider hydrating from the same
    // prefs. This is where the original bug bit — BEFORE the hydration
    // completes the new provider still reports the hardcoded default.
    final restarted = SettingsProvider();
    debugPrint('[Test] restarted provider BEFORE loadSettings: '
        'pageLayoutMode="${restarted.pageLayoutMode}" '
        '(was the stale default)');
    await restarted.loadSettings();
    debugPrint('[Test] restarted provider AFTER loadSettings: '
        'pageLayoutMode="${restarted.pageLayoutMode}"');
    expect(restarted.isSinglePageLayout, true);
  });

  test('BUG2 trace: remember-last-page setting persists and round-trips',
      () async {
    final provider = SettingsProvider();
    expect(provider.rememberLastPage, true);

    // User turns the toggle OFF.
    await provider.setRememberLastPage(false);
    expect(provider.rememberLastPage, false);
    expect(await StorageService.loadRememberLastPage(), false);

    final restarted = SettingsProvider();
    await restarted.loadSettings();
    expect(restarted.rememberLastPage, false);

    // And back ON again.
    await provider.setRememberLastPage(true);
    expect(await StorageService.loadRememberLastPage(), true);
  });

  test('BUG2 trace: updatePageNumber persists lastPage; openFile keeps it',
      () async {
    final recents = RecentFilesProvider();
    await recents.loadFiles();

    await recents.addLocalFile(path: '/x.pdf', name: 'x.pdf', size: 42);
    // Viewer closes → dispose() → updatePageNumber(path, page).
    await recents.updatePageNumber('/x.pdf', 7);

    // Restart sim: another provider hydrating from disk.
    final restarted = RecentFilesProvider();
    await restarted.loadFiles();
    final file = restarted.files.firstWhere((f) => f.path == '/x.pdf');
    debugPrint('[Test] lastPage after restart = ${file.lastPage}');
    expect(file.lastPage, 7);

    // openFile (viewer post-frame) must NOT clobber the saved page.
    await restarted.openFile('/x.pdf');
    expect(
      restarted.files.firstWhere((f) => f.path == '/x.pdf').lastPage,
      7,
    );
  });

  test(
      'BUG2 trace: remember-last-page ON→OFF full scenario — save on close, '
      'restore on reopen, skip while OFF (lastPage preserved, not reset)',
      () async {
    final recents = RecentFilesProvider();
    await recents.loadFiles();

    // Viewer logic mirrors pdf_viewer_screen.dart: initState seeds
    // `_currentPage = rememberLastPage ? file.lastPage : 1`, dispose saves
    // ONLY when rememberLastPage is true.
    const settings = _SimSettings();

    // 1) Open a fresh file (lastPage=1), read to page 20, close (ON) → saved.
    await recents.addLocalFile(path: '/x.pdf', name: 'x.pdf', size: 42);
    int currentPage = _seededPage(recents, '/x.pdf', settings);
    debugPrint('[Test] open #1 (ON) → starts at page $currentPage');
    expect(currentPage, 1);
    currentPage = 20; // user scrolls to page 20
    if (settings.on) await recents.updatePageNumber('/x.pdf', currentPage);
    expect(recents.files.firstWhere((f) => f.path == '/x.pdf').lastPage, 20);

    // 2) Reopen with setting still ON → restores page 20.
    await recents.openFile('/x.pdf');
    currentPage = _seededPage(recents, '/x.pdf', settings);
    debugPrint('[Test] open #2 (ON) → restores page $currentPage');
    expect(currentPage, 20);

    // 3) User turns the toggle OFF, reopens, goes to page 5, closes.
    const settingsOff = _SimSettings(on: false);
    currentPage = _seededPage(recents, '/x.pdf', settingsOff);
    debugPrint('[Test] open #3 (OFF) → starts at page $currentPage');
    expect(currentPage, 1);
    currentPage = 5; // user scrolls while OFF
    if (settingsOff.on) await recents.updatePageNumber('/x.pdf', currentPage);
    // Save skipped → lastPage must STAY 20 (not 5, not reset to 1).
    final afterOff = recents.files.firstWhere((f) => f.path == '/x.pdf');
    debugPrint('[Test] after close (OFF) → lastPage=${afterOff.lastPage} '
        '(expect unchanged 20)');
    expect(afterOff.lastPage, 20);

    // 4) Reopen while OFF → starts at page 1.
    await recents.openFile('/x.pdf');
    currentPage = _seededPage(recents, '/x.pdf', settingsOff);
    debugPrint('[Test] open #4 (OFF) → starts at page $currentPage');
    expect(currentPage, 1);

    // 5) Re-enable → the untouched lastPage (20) is restored, not page 5.
    await recents.openFile('/x.pdf');
    currentPage = _seededPage(recents, '/x.pdf', settings);
    debugPrint('[Test] open #5 (back ON) → restores page $currentPage');
    expect(currentPage, 20);
  });

  test('BUG3 trace: user bookmarks persist, toggle & per-file grouping',
      () async {
    final bookmarks = BookmarksProvider();
    await bookmarks.loadAll();

    // Toggle ON (viewer app-bar icon): add bookmark for current page.
    expect(bookmarks.isBookmarked('/x.pdf', 3), false);
    await bookmarks.addBookmark(
      PdfBookmark(
        id: 'b1',
        filePath: '/x.pdf',
        pageNumber: 3,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    expect(bookmarks.isBookmarked('/x.pdf', 3), true);

    // Per-file grouping — a bookmark on another path must not leak in.
    await bookmarks.addBookmark(
      PdfBookmark(
        id: 'b2',
        filePath: '/y.pdf',
        pageNumber: 7,
        createdAt: DateTime(2026, 1, 2),
      ),
    );
    final forX = bookmarks.bookmarksForFile('/x.pdf');
    expect(forX.length, 1);
    expect(forX.first.pageNumber, 3);

    // Restart sim: another provider hydrating from disk.
    final restarted = BookmarksProvider();
    await restarted.loadAll();
    expect(restarted.isBookmarked('/x.pdf', 3), true);
    expect(restarted.isBookmarked('/y.pdf', 7), true);

    // Optional label round-trip.
    await restarted.updateBookmarkLabel('b2', '  Chapter 3 recap  ');
    expect(restarted.bookmarksForFile('/y.pdf').first.label, 'Chapter 3 recap');

    // Toggle OFF (viewer app-bar icon): remove bookmark for its page.
    await restarted.removeBookmark('b1');
    expect(restarted.isBookmarked('/x.pdf', 3), false);
  });
}