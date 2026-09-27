import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'providers/annotations_provider.dart';
import 'providers/bookmarks_provider.dart';
import 'providers/folders_provider.dart';
import 'providers/recent_files_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/open_with_listener.dart';
import 'services/storage_service.dart';

/// Shared navigator key so the "Open with" listener (which lives below the
/// MaterialApp's Navigator) can push the PDF viewer from outside the widget
/// tree — e.g. when a PDF is opened into this app from another app.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // debugPrintRebuildDirtyWidgets = true; // OFF: adds rebuild-logging overhead that slows scroll

  // Load local development configuration before any service reads the Gemini
  // key. The .env file is ignored by Git and bundled as a Flutter asset.
  await dotenv.load(fileName: '.env');

  // Load dark-mode preference synchronously before the first frame so the
  // correct theme is applied instantly — no flash of the wrong theme.
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  // Read the first-launch flag up front so the home screen knows whether to
  // push the onboarding tour (returning users never see even a flash of it).
  final hasSeenOnboarding = await StorageService.loadHasSeenOnboarding();

  // BUG FIX (reading defaults): hydrate the reading-defaults settings from
  // SharedPreferences BEFORE runApp. Previously loadSettings() was fired
  // unawaited from HomeScreen's post-frame callback, so on a cold start
  // (especially a deep-link "Open with" launch, whose listener runs before
  // HomeScreen's callback) a PdfViewerScreen could snapshot the hardcoded
  // defaults before the real persisted values arrived — making "Page layout"
  // and "Remember last page" look dead for the first file opened. Like the
  // theme above, settings are now authoritative from the very first frame.
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  runApp(
    XpdfApp(
      themeProvider: themeProvider,
      settingsProvider: settingsProvider,
      showOnboarding: !hasSeenOnboarding,
    ),
  );
}

/// Root widget of the XPDF application.
class XpdfApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final SettingsProvider settingsProvider;
  final bool showOnboarding;
  const XpdfApp({
    super.key,
    required this.themeProvider,
    required this.settingsProvider,
    this.showOnboarding = false,
  });

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
        // Already hydrated in main() before runApp (see the BUG FIX comment
        // there) so no viewer can ever snapshot stale defaults.
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),

        // User-created PDF highlight annotations, grouped by file path.
        ChangeNotifierProvider(create: (_) => AnnotationsProvider()),

        // User-created page bookmarks, grouped by file path (BUG 3 feature).
        ChangeNotifierProvider(create: (_) => BookmarksProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'XPDF',
            debugShowCheckedModeBanner: false,

            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),

            // Driven by ThemeProvider
            themeMode: themeProvider.themeMode,

            navigatorKey: navigatorKey,

            // Start with the Flutter splash, then replace it with the existing
            // home/listener stack after 2.5 seconds.
            home: SplashScreen(
              destination: OpenWithListener(
                navigatorKey: navigatorKey,
                child: HomeScreen(showOnboarding: showOnboarding),
              ),
            ),
          );
        },
      ),
    );
  }
}
