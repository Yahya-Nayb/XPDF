import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Manages the app-wide light/dark theme preference.
///
/// Follows the same pattern as [RecentFilesProvider]: the preference is
/// loaded once at app start via [loadTheme] and persisted on every toggle.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Load the persisted preference. Called once before the first frame
  /// so the correct theme is applied from the start (no flash).
  Future<void> loadTheme() async {
    final isDark = await StorageService.loadDarkMode();
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Toggle between light and dark mode, then persist the choice.
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await StorageService.saveDarkMode(isDark);
    notifyListeners();
  }
}
