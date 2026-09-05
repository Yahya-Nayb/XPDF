import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../colors.dart';
import '../models/recent_file.dart';
import '../providers/folders_provider.dart';
import '../providers/recent_files_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/folia_search_bar.dart';
import '../widgets/import_section.dart';
import '../widgets/recent_file_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/empty_favorites_state.dart';
import '../widgets/no_search_results.dart';
import '../widgets/move_to_folder_sheet.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/url_import_dialog.dart';
import 'library_screen.dart';
import 'image_to_pdf_screen.dart';
import 'pdf_viewer_screen.dart';
import 'settings_screen.dart';

/// The app's home screen — search bar, import shortcuts, and recent files.
///
/// The search query lives here as local StatefulWidget state (not in the
/// provider) because it's purely a UI filter — it doesn't affect what's
/// stored on disk or shared with other screens.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentNavIndex = 0; // 0 = Home, 1 = Favorites, 2 = Library, 3 = Settings

  // PERFORMANCE: Cache sorted/filtered file lists to avoid recomputing
  // sortFiles() + _filteredFiles() on every build. The cache is invalidated
  // when the provider's version counter bumps (any data or sort-mode change)
  // or when the search query changes.
  List<RecentFile>? _cachedSortedAll;
  List<RecentFile>? _cachedSortedFavorites;
  int _cachedVersion = -1;
  String _cachedSearchQuery = '';
  String _cachedSortMode = '';

  @override
  void initState() {
    super.initState();
    // Load saved files from disk on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecentFilesProvider>().loadFiles();
      context.read<FoldersProvider>().loadFolders();
      context.read<SettingsProvider>().loadSettings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Pick a PDF from the device filesystem and open it in the viewer.
  Future<void> _pickFile() async {
    final provider = context.read<RecentFilesProvider>();
    final file = await provider.pickAndOpenPdf();
    if (file != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfViewerScreen(file: file)),
      );
    }
  }

  /// Navigate to the viewer for an existing recent file.
  void _openFile(RecentFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerScreen(file: file)),
    );
  }

  /// Download a PDF from a pasted URL and open it in the viewer.
  Future<void> _importFromUrl() async {
    final downloaded = await showUrlImportDialog(context);
    if (downloaded == null || !mounted) return;

    final recent = await context.read<RecentFilesProvider>().addLocalFile(
          path: downloaded.path,
          name: downloaded.name,
          size: downloaded.size,
        );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfViewerScreen(file: recent)),
      );
    }
  }

  /// Scan documents with the camera, save them as one PDF and open it in
  /// the viewer. Silent on user cancellation; SnackBar feedback on errors.
  Future<void> _scanDocument() async {
    try {
      final scanned = await FileService.scanDocumentsToPdf();
      if (scanned == null || !mounted) return; // cancelled mid-scan

      final recent = await context.read<RecentFilesProvider>().addLocalFile(
            path: scanned.path,
            name: scanned.name,
            size: scanned.size,
          );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfViewerScreen(file: recent)),
      );
    } on ScanException catch (e) {
      // Permission denied, scanner failure, or save failure.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Scan failed. Please try again.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Navigate to the Images-to-PDF conversion screen.
  void _openImageToPdf() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
    );
  }

  /// Shows the Tools bottom sheet with tappable tool cards.
  void _showToolsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.2,
          maxChildSize: 0.6,
          expand: false,
          builder: (sheetContext, scrollController) {
            return Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.colorOf(sheetContext, 'textMuted')
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tools',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color:
                            AppColors.colorOf(sheetContext, 'textPrimary'),
                      ),
                    ),
                  ),
                ),

                // Tool cards
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      ToolCard(
                        icon: Icons.image_rounded,
                        iconBackground: AppColors.colorOf(
                          sheetContext,
                          'inputFill',
                        ),
                        iconColor: AppColors.colorOf(
                          sheetContext,
                          'primary',
                        ),
                        title: 'Images to PDF',
                        subtitle: 'Combine photos into one PDF file',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openImageToPdf();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Placeholder for coming-soon import sources.
  void _comingSoon(String source) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$source coming soon'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Handle menu actions from the three-dot popup on a recent file card.
  void _onMenuAction(String action, RecentFile file) {
    if (action == 'favorite') {
      // Instant toggle — no confirmation needed, unlike removal.
      context.read<RecentFilesProvider>().toggleFavorite(file.path);
    } else if (action == 'remove') {
      context.read<RecentFilesProvider>().removeFile(file.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${file.name} removed from list'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (action == 'move') {
      showMoveToFolderSheet(context, file);
    }
    // Future: handle 'rename', 'share', etc.
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isSettingsView = _currentNavIndex == 3;

    // PERFORMANCE: The header and floating bar are built OUTSIDE the
    // RecentFilesProvider Consumer so they never rebuild when files change.
    // Only the content slivers (below the header) rebuild on provider changes,
    // using SliverMainAxisGroup to keep them inside a single Consumer.
    return Scaffold(
      backgroundColor: AppColors.colorOf(context, 'background'),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // -- Static header (no provider dependency) ---------------------
                // The Settings tab renders its own dedicated header.
                if (!isSettingsView)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: GoogleFonts.orbitron(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'X',
                                      style: TextStyle(
                                        color: AppColors.colorOf(
                                          context,
                                          'textPrimary',
                                        ),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'PDF',
                                      style: const TextStyle(
                                        color: AppColors.brandRed,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _showToolsSheet,
                                    icon: Icon(
                                      Icons.grid_view_outlined,
                                      color: AppColors.colorOf(
                                        context,
                                        'textSecondary',
                                      ),
                                      size: 26,
                                    ),
                                  ),
                                  Consumer<ThemeProvider>(
                                    builder: (context, themeProvider, _) {
                                      return IconButton(
                                        onPressed: themeProvider.toggleTheme,
                                        icon: Icon(
                                          themeProvider.isDark
                                              ? Icons.light_mode_rounded
                                              : Icons.dark_mode_rounded,
                                          color: AppColors.colorOf(
                                            context,
                                            'textSecondary',
                                          ),
                                          size: 26,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open, read, and manage your PDF files',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.colorOf(context, 'textMuted'),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // -- Search bar --------------------------------------
                          FoliaSearchBar(
                            controller: _searchController,
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            onClear: () => setState(() => _searchQuery = ''),
                          ),

                          // -- Import section (Home view only) ------------------
                          if (_currentNavIndex != 0)
                            const SizedBox(height: 28)
                          else ...[
                            const SizedBox(height: 24),
                            ImportSection(
                              onFilesTap: _pickFile,
                              onDriveTap: () => _comingSoon('Google Drive'),
                              onScanTap: _scanDocument,
                              onUrlTap: _importFromUrl,
                            ),
                            const SizedBox(height: 28),
                          ],
                        ],
                      ),
                    ),
                  ),

                // -- Dynamic content (rebuilt only on provider changes) ---------
                // SliverMainAxisGroup lets a Consumer return multiple slivers.
                // This is the ONLY part that rebuilds when RecentFilesProvider
                // changes — the header and floating bar above/below stay still.
                Consumer<RecentFilesProvider>(
                  builder: (context, provider, _) {
                    // PERFORMANCE: showActiveDot is computed HERE inside the
                    // Consumer builder — a valid build context. It used to be
                    // read via context.select() inside _buildSortButton(), but
                    // that method's `this.context` belongs to _HomeScreenState,
                    // which is NOT building at that point (a descendant
                    // Consumer<ThemeProvider> is). The Provider package asserts
                    // debugDoingBuild on the element owning the context, causing
                    // a runtime error. By computing the value here and threading
                    // it down, we avoid the illegal context.select() entirely.
                    final showActiveDot = !provider.isDefaultSort;
                    return SliverMainAxisGroup(
                      slivers: _buildContentSlivers(
                        provider,
                        showActiveDot: showActiveDot,
                      ),
                    );
                  },
                ),

                // Bottom spacing so last items aren't hidden behind the floating bar
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),

            // Floating pill bar pinned to the bottom (no provider dependency)
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: _buildFloatingBar(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the content slivers that depend on RecentFilesProvider.
  ///
  /// Extracted from build() so they live inside the narrow Consumer scope
  /// and don't cause header/floating-bar rebuilds when the file list changes.
  List<Widget> _buildContentSlivers(
    RecentFilesProvider provider, {
    required bool showActiveDot,
  }) {
    final isFavoritesView = _currentNavIndex == 1;
    final isLibraryView = _currentNavIndex == 2;
    final isSettingsView = _currentNavIndex == 3;

    // -- Loading state -------------------------------------------
    if (!provider.isLoaded) {
      return const [
        SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    // -- Favorites view ------------------------------------------
    if (isFavoritesView) {
      if (provider.favoriteFiles.isEmpty && _searchQuery.isEmpty) {
        return const [SliverFillRemaining(child: EmptyFavoritesState())];
      }
      return [
        _buildSectionHeader('Favorites', showActiveDot: showActiveDot),
        _buildFileList(provider, favoritesOnly: true),
      ];
    }

    // -- Library view ---------------------------------------------
    if (isLibraryView) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: const LibraryView(),
          ),
        ),
      ];
    }

    // -- Settings view ---------------------------------------------
    if (isSettingsView) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: const SettingsView(),
          ),
        ),
      ];
    }

    // -- Home view ------------------------------------------------
    if (provider.files.isEmpty && _searchQuery.isEmpty) {
      return const [SliverFillRemaining(child: EmptyState())];
    }

    return [
      _buildSectionHeader('Recent', showActiveDot: showActiveDot),
      _buildFileList(provider),
    ];
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Filter the provider's file list by the current search query.
  List<RecentFile> _filteredFiles(List<RecentFile> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  /// Section header row ("Recent" / "Favorites") with a functional sort
  /// button on the trailing edge. The icon shows a small primary-colored dot
  /// whenever a non-default sort is active, as a visual cue. Rebuilt on
  /// theme changes like before.
  Widget _buildSectionHeader(String title, {required bool showActiveDot}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Consumer<ThemeProvider>(
          builder: (context, _, _) {
            return Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorOf(
                      context,
                      'textPrimary',
                    ),
                  ),
                ),
                const Spacer(),
                _buildSortButton(showActiveDot: showActiveDot),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Sort trigger for the section header — opens the sort bottom sheet.
  /// A dot badge marks non-default sorts.
  ///
  /// PERFORMANCE: [showActiveDot] is computed in the Consumer builder and
  /// threaded down. We avoid calling context.select() here because
  /// this.context belongs to _HomeScreenState — a widget that is NOT currently
  /// building at this point (Consumer is). The Provider package
  /// asserts debugDoingBuild on the element owning the context, which fails
  /// for HomeScreen when called from a descendant's build.
  Widget _buildSortButton({required bool showActiveDot}) {

    return InkWell(
      onTap: () => showSortSheet(context),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 20,
              color: showActiveDot
                  ? AppColors.colorOf(context, 'primary')
                  : AppColors.colorOf(context, 'textMuted'),
            ),
            if (showActiveDot)
              Positioned(
                top: -1,
                right: -3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.colorOf(context, 'primary'),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build either the file list or a "no search results" message.
  ///
  /// [favoritesOnly] sources the list from the provider's favorited files
  /// instead of all recent files — same card widget and search filtering.
  /// Ordering: search filter first, then the shared sort preference
  /// ([RecentFilesProvider.sortFiles]) applied to the filtered results.
  ///
  /// PERFORMANCE: Sort + filter results are cached and only recomputed when
  /// the provider's version counter changes (data/sort-mode mutation) or
  /// the search query changes. This avoids expensive re-sorting on every
  /// rebuild frame (e.g. during scroll when the Consumer rebuilds).
  Widget _buildFileList(RecentFilesProvider provider,
      {bool favoritesOnly = false}) {
    final needsRecompute = _cachedVersion != provider.version ||
        _cachedSearchQuery != _searchQuery ||
        _cachedSortMode != provider.sortMode;

    List<RecentFile> filtered;
    if (needsRecompute) {
      _cachedVersion = provider.version;
      _cachedSearchQuery = _searchQuery;
      _cachedSortMode = provider.sortMode;

      final allBase = provider.files;
      _cachedSortedAll = provider.sortFiles(_filteredFiles(allBase));

      final favBase = provider.favoriteFiles;
      _cachedSortedFavorites = provider.sortFiles(_filteredFiles(favBase));
    }

    filtered = favoritesOnly ? _cachedSortedFavorites! : _cachedSortedAll!;

    if (filtered.isEmpty) {
      return const SliverFillRemaining(
        child: NoSearchResults(query: ''), // query shown inside widget
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, i) => const SizedBox(height: 0),
        itemBuilder: (context, index) {
          final file = filtered[index];
          return RecentFileCard(
            key: ValueKey(file.path),
            file: file,
            onTap: () => _openFile(file),
            onMenuAction: (action) => _onMenuAction(action, file),
            onToggleFavorite: () =>
                context.read<RecentFilesProvider>().toggleFavorite(file.path),
          );
        },
      ),
    );
  }

  /// Floating pill-shaped navigation bar with Home, Favorites, Add, Library, and Settings.
  Widget _buildFloatingBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.colorOf(context, 'surface'),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home button
          IconButton(
            onPressed: () => setState(() => _currentNavIndex = 0),
            icon: Icon(
              Icons.home_rounded,
              size: 28,
              color: _currentNavIndex == 0
                  ? AppColors.colorOf(context, 'primary')
                  : AppColors.colorOf(context, 'textMuted'),
            ),
          ),

          // Favorites button
          IconButton(
            onPressed: () => setState(() => _currentNavIndex = 1),
            icon: Icon(
              Icons.star_rounded,
              size: 28,
              color: _currentNavIndex == 1
                  ? AppColors.colorOf(context, 'primary')
                  : AppColors.colorOf(context, 'textMuted'),
            ),
          ),

          // Center add button (replaces the docked FAB)
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.colorOf(context, 'primary'),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),

          // Library button
          IconButton(
            onPressed: () => setState(() => _currentNavIndex = 2),
            icon: Icon(
              Icons.library_books_rounded,
              size: 28,
              color: _currentNavIndex == 2
                  ? AppColors.colorOf(context, 'primary')
                  : AppColors.colorOf(context, 'textMuted'),
            ),
          ),

          // Settings button
          IconButton(
            onPressed: () => setState(() => _currentNavIndex = 3),
            icon: Icon(
              Icons.settings_rounded,
              size: 28,
              color: _currentNavIndex == 3
                  ? AppColors.colorOf(context, 'primary')
                  : AppColors.colorOf(context, 'textMuted'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable card for a tool/action on the Home screen.
///
/// Reusable — designed so future tools (e.g. "PDF Compress", "Page Extract")
/// can be added by simply calling `ToolCard(...)` with different parameters.
/// Styled to match [RecentFileCard]: same card color, border, radius, and
/// shadow treatment.
class ToolCard extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ToolCard({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.colorOf(context, 'card'),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.colorOf(context, 'border')),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon chip (matches RecentFileCard badge style)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.colorOf(context, 'textPrimary'),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.colorOf(context, 'textMuted'),
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.colorOf(context, 'textMuted'),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
