import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'colors.dart';
import 'providers/annotations_provider.dart';
import 'providers/folders_provider.dart';
import 'providers/recent_files_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/open_with_listener.dart';

/// Shared navigator key so the "Open with" listener (which lives below the
/// MaterialApp's Navigator) can push the PDF viewer from outside the widget
/// tree — e.g. when a PDF is opened into this app from another app.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // debugPrintRebuildDirtyWidgets = true; // OFF: adds rebuild-logging overhead that slows scroll

  // Load dark-mode preference synchronously before the first frame so the
  // correct theme is applied instantly — no flash of the wrong theme.
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(FoliaApp(themeProvider: themeProvider));
}

/// Root widget of the Folia application.
class FoliaApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const FoliaApp({super.key, required this.themeProvider});

  /// Shared Switch theming applied to BOTH ThemeData variants so every
  /// Switch in the app keeps a clearly visible thumb in all four visual
  /// combos (ON/OFF × hovered/resting).
  ///
  /// Why this exists: the ColorScheme below only sets primary/surface/
  /// onSurface/outline. The M3 switch's ON-thumb normally derives from
  /// `colorScheme.onPrimary` (unset here → framework default) while hover/
  /// press draw primary-tinted state layers over the track — combinations
  /// that could merge into one flat blob. Pinning a constant white thumb,
  /// palette-colored tracks, and faint overlays makes the contrast
  /// structural instead of dependent on unspecified theme slots.
  static SwitchThemeData _foliaSwitchTheme({
    required Color activeTrack,
    required Color inactiveTrack,
  }) {
    return SwitchThemeData(
      // White thumb in every enabled state → always contrasts against both
      // the blue ON track and the muted-gray OFF track.
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? activeTrack : inactiveTrack,
      ),
      // No outline ring — keeps OFF state as a clean gray pill.
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      // Hover/press highlight: a faint tint of whichever track color is
      // currently showing. Low alpha = gentle feedback that never obscures
      // the white thumb or flattens the track.
      overlayColor: WidgetStateProperty.resolveWith((states) {
        final base = states.contains(WidgetState.selected)
            ? activeTrack
            : inactiveTrack;
        if (states.contains(WidgetState.pressed)) {
          return base.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return base.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => RecentFilesProvider()),

        // FoldersProvider coordinates with the recent-files list on folder
        // deletion: deleting a folder un-categorizes its files instead of
        // deleting them. The injected callback keeps the two providers
        // decoupled (FoldersProvider never imports RecentFilesProvider),
        // and `ctx` here already has access to the provider declared above.
        ChangeNotifierProvider<FoldersProvider>(
          create: (ctx) => FoldersProvider(
            onFolderDeleted: (folderId) =>
                ctx.read<RecentFilesProvider>().clearFolder(folderId),
          ),
        ),

        // Reading-defaults settings (page layout mode, remember last page).
        ChangeNotifierProvider(create: (_) => SettingsProvider()),

        // User-created PDF highlight annotations, grouped by file path.
        ChangeNotifierProvider(create: (_) => AnnotationsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'XPDF',
            debugShowCheckedModeBanner: false,

            // Light theme
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: AppColors.background,
              switchTheme: _foliaSwitchTheme(
                activeTrack: AppColors.primary,
                inactiveTrack: AppColors.textMuted,
              ),
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
                outline: AppColors.border,
                outlineVariant: AppColors.border,
              ),
            ),

            // Dark theme
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColors.darkBackground,
              switchTheme: _foliaSwitchTheme(
                activeTrack: AppColors.darkPrimary,
                inactiveTrack: AppColors.darkTextMuted,
              ),
              colorScheme: const ColorScheme.dark(
                primary: AppColors.darkPrimary,
                surface: AppColors.darkSurface,
                onSurface: AppColors.darkTextPrimary,
                outline: AppColors.darkBorder,
                outlineVariant: AppColors.darkBorder,
              ),
            ),

            // Driven by ThemeProvider
            themeMode: themeProvider.themeMode,

            navigatorKey: navigatorKey,

            // OpenWithListener wraps the home screen so PDFs opened via
            // Android's "Open with" dialog are captured on both cold and warm
            // starts and pushed straight into the PDF viewer.
            home: OpenWithListener(
              navigatorKey: navigatorKey,
              child: const HomeScreen(),
            ),
          );
        },
      ),
    );
  }
}
