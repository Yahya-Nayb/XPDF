import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
/// Central state for the reading-defaults settings on the Settings screen.
///
/// Follows the same pattern as ThemeProvider: loaded once at app start,
/// persisted through [StorageService] on every change, exposed via plain
/// getters.
///
/// Page layout mode is stored as a string ("single" or "continuous") — kept
/// simple on purpose, matching the app's no-codegen style. The defaults
/// preserve the viewer's pre-settings behavior exactly: continuous scrolling
/// and always restoring the last-read page.
class SettingsProvider extends ChangeNotifier {
  /// Layout used when the user has never changed the setting.
  static const String defaultPageLayoutMode = 'continuous';

  String _pageLayoutMode = defaultPageLayoutMode;
  bool _rememberLastPage = true;
  bool _loaded = false;

  // -- Public getters --------------------------------------------------------

  /// "single" or "continuous".
  String get pageLayoutMode => _pageLayoutMode;
  bool get isSinglePageLayout => _pageLayoutMode == 'single';
  bool get rememberLastPage => _rememberLastPage;
  bool get isLoaded => _loaded;

  // -- Initialization --------------------------------------------------------

  /// Called once at app start to hydrate the settings from disk.
  Future<void> loadSettings() async {
    _pageLayoutMode = await StorageService.loadPageLayoutMode();
    _rememberLastPage = await StorageService.loadRememberLastPage();
    _loaded = true;
    // TEMPORARY DEBUG: verify hydration from SharedPreferences at startup.
    debugPrint('[Settings] loadSettings ← disk: pageLayoutMode="$_pageLayoutMode", '
        'rememberLastPage=$_rememberLastPage');
    notifyListeners();
  }

  // -- Core operations -------------------------------------------------------

  /// Set the default page layout for newly opened files
  /// ([mode] is "single" or "continuous") and persist.
  Future<void> setPageLayoutMode(String mode) async {
    if (mode != 'single' && mode != 'continuous') return;
    if (mode == _pageLayoutMode) {
      // TEMPORARY DEBUG: tapped value equals current value — nothing to save.
      debugPrint('[Settings] setPageLayoutMode("$mode") → no change, skipping save');
      return;
    }

    _pageLayoutMode = mode;
    // TEMPORARY DEBUG: verify the tap reaches persistence.
    debugPrint('[Settings] setPageLayoutMode("$mode") → saving to '
        'SharedPreferences key "default_page_layout"');
    await StorageService.savePageLayoutMode(mode);
    notifyListeners();
  }

  /// Toggle whether opening a file restores its last-read page (and whether
  /// closing it saves the position) and persist.
  Future<void> setRememberLastPage(bool value) async {
    if (value == _rememberLastPage) {
      // TEMPORARY DEBUG: toggled value equals current value — nothing to save.
      debugPrint('[Settings] setRememberLastPage($value) → no change, skipping save');
      return;
    }

    _rememberLastPage = value;
    // TEMPORARY DEBUG: verify the toggle reaches persistence.
    debugPrint('[Settings] setRememberLastPage($value) → saving to '
        'SharedPreferences key "remember_last_page"');
    await StorageService.saveRememberLastPage(value);
    notifyListeners();
  }
}
