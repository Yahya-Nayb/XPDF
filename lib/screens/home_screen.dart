import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/recent_file.dart';
import '../providers/annotations_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/recent_files_provider.dart';
import '../providers/theme_provider.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../theme/brand_gradient.dart';
import '../widgets/xpdf_search_bar.dart';
import '../widgets/pdf_grid_card.dart';
import '../widgets/recent_file_list_row.dart';
import '../widgets/empty_favorites_state.dart';
import '../widgets/no_search_results.dart';
import '../widgets/move_to_folder_sheet.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/url_import_dialog.dart';
import 'library_screen.dart';
import 'image_to_pdf_screen.dart';
import 'merge_pdf_screen.dart';
import 'split_pdf_screen.dart';
import 'onboarding_screen.dart';
import 'pdf_viewer_screen.dart';
import 'settings_screen.dart';

/// Display layouts for the Recent-files list.
///
/// Stored in SharedPreferences as the enum's lowercase name ("grid" | "list")
/// under the "recent_view_mode" key; Grid is the default.
enum RecentViewMode { grid, list }

/// Material's regular FAB diameter, and the button half of the scroll clearance
/// appended to the recents so the FAB never covers the last file's actions.
const double _addFabSize = 56;

/// The main tabs, in order. Shared by the header titles and the floating pill so
/// an index can never mean two different things.
const List<FloatingPillNavItem> _navItems = [
  FloatingPillNavItem(icon: Icons.home_outlined, label: 'Home'),
  FloatingPillNavItem(icon: Icons.star_outlined, label: 'Favorites'),
  FloatingPillNavItem(icon: Icons.folder_outlined, label: 'Library'),
  FloatingPillNavItem(icon: Icons.settings_outlined, label: 'Settings'),
];

/// The app's home screen — action cards, quick tools, and recent files grid.
class HomeScreen extends StatefulWidget {
  final bool showOnboarding;

  const HomeScreen({super.key, this.showOnboarding = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentNavIndex = 0;
  bool _searchVisible = false;
  bool _showAllRecents = false;

  RecentViewMode _viewMode = RecentViewMode.grid;

  List<RecentFile>? _cachedSortedAll;
  List<RecentFile>? _cachedSortedFavorites;
  int _cachedVersion = -1;
  String _cachedSearchQuery = '';
  String _cachedSortMode = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final savedMode = await StorageService.loadRecentViewMode();
      if (!mounted) return;

      setState(
        () => _viewMode = RecentViewMode.values.firstWhere(
          (m) => m.name == savedMode,
          orElse: () => RecentViewMode.grid,
        ),
      );

      context.read<RecentFilesProvider>().loadFiles();
      context.read<FoldersProvider>().loadFolders();
      context.read<AnnotationsProvider>().loadAll();
      context.read<BookmarksProvider>().loadAll();

      if (widget.showOnboarding) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions (logic unchanged)
  // ---------------------------------------------------------------------------

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

  void _openFile(RecentFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerScreen(file: file)),
    );
  }

  Future<void> _setViewMode(RecentViewMode mode) async {
    setState(() => _viewMode = mode);
    await StorageService.saveRecentViewMode(mode.name);
  }

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

  Future<void> _scanDocument() async {
    try {
      final scanned = await FileService.scanDocumentsToPdf();
      if (scanned == null || !mounted) return;

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Scan failed. Please try again.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _openImageToPdf() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
    );
  }

  void _openMergePdf() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MergePdfScreen()),
    );
  }

  void _openSplitPdf() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SplitPdfScreen()),
    );
  }

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

  void _showImportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Import document',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _ImportOptionRow(
                  icon: Icons.folder_open_rounded,
                  title: 'Files',
                  subtitle: 'Pick a PDF from your device',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickFile();
                  },
                ),
                _ImportOptionRow(
                  icon: Icons.cloud_rounded,
                  title: 'Drive',
                  subtitle: 'Import from Google Drive',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _comingSoon('Google Drive');
                  },
                ),
                _ImportOptionRow(
                  icon: Icons.link_rounded,
                  title: 'URL',
                  subtitle: 'Download a PDF from a link',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _importFromUrl();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFileActions(RecentFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                file.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: file.isFavorite
                    ? AppColors.favorite
                    : context.appColors.textSecondary,
              ),
              title: Text(
                file.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<RecentFilesProvider>().toggleFavorite(file.path);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.drive_file_move_outline,
                color: context.appColors.textSecondary,
              ),
              title: const Text('Move to folder'),
              onTap: () {
                Navigator.pop(sheetContext);
                showMoveToFolderSheet(context, file);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.primary),
              title: Text(
                'Remove from recent',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _onMenuAction('remove', file);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onMenuAction(String action, RecentFile file) {
    if (action == 'favorite') {
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
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isSettingsView = _currentNavIndex == 3;
    final isHomeView = _currentNavIndex == 0;

    return Scaffold(
      // The page itself is the lowest of the three surface levels; every tile
      // the user can tap sits on one of the two above it, which is what makes
      // the hierarchy readable in dark mode without leaning on borders.
      backgroundColor: context.appColors.surfaceBase,
      // The pill floats over the page, so the page runs all the way to the
      // bottom edge and scrolls under the glass. Every scroll view has to pay
      // for the pill in its bottom padding — see [_recentsClearance].
      extendBody: true,
      body: SafeArea(
        // The bottom inset belongs to the pill, which already keeps itself clear
        // of it; insetting the body here as well would push the scroll viewport
        // up past the pill's top edge and leave a band of page showing through.
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (!isSettingsView) ...[
                    SliverToBoxAdapter(child: _buildTopBar()),
                    if (_searchVisible && !isSettingsView)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTokens.xl,
                            0,
                            AppTokens.xl,
                            AppTokens.lg,
                          ),
                          child: XpdfSearchBar(
                            controller: _searchController,
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            onClear: () => setState(() => _searchQuery = ''),
                          ),
                        ),
                      ),
                    if (isHomeView) ...[
                      SliverToBoxAdapter(child: _buildActionCards()),
                      SliverToBoxAdapter(child: _buildQuickTools()),
                    ],
                  ],
                  Consumer<RecentFilesProvider>(
                    builder: (context, provider, _) {
                      final showActiveDot = !provider.isDefaultSort;
                      return SliverMainAxisGroup(
                        slivers: _buildContentSlivers(
                          provider,
                          showActiveDot: showActiveDot,
                        ),
                      );
                    },
                  ),
                  // The page runs behind both the FAB and the pill, so the last
                  // recent file needs room to scroll clear of them. See
                  // [_recentsClearance].
                  SliverToBoxAdapter(
                    child: SizedBox(height: _recentsClearance(hasFab: isHomeView)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isHomeView
          ? const Padding(
              // Scaffold hangs the FAB off the bar's top edge with its own 16dp
              // margin, which is the gap we want — but it also insets it 16dp
              // from the screen edge, so the nudge below lines it up with the
              // pill's margin.
              padding: EdgeInsets.only(right: AppTokens.md),
              child: _AddDocumentFab(),
            )
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// Bottom padding the page needs so nothing hides behind the floating chrome.
  ///
  /// The pill's whole block — its height plus the margin it keeps off the
  /// screen edge — because the body scrolls behind it. On Home the FAB stacks
  /// one more button plus one more gap on top of that. The trailing 16dp keeps
  /// the final row off the glass rather than flush against it. The system
  /// inset is already inside the pill's own margin, so it is not counted twice.
  double _recentsClearance({required bool hasFab}) =>
      FloatingPillNav.scrollClearance +
      (hasFab ? _addFabSize + AppTokens.lg : 0) +
      AppTokens.lg;

  /// The floating pill that carries the four main tabs.
  Widget _buildBottomNav() {
    return FloatingPillNav(
      currentIndex: _currentNavIndex,
      onSelect: (i) => setState(() {
        _currentNavIndex = i;
        if (i != 0) _showAllRecents = false;
      }),
      items: _navItems,
    );
  }

  Widget _buildTopBar() {
    final ext = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.xl,
        AppTokens.lg,
        AppTokens.md,
        AppTokens.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_currentNavIndex == 0)
                // The gradient "XPDF" wordmark replaces the former coral wordmark
                // image. It is a text widget, so it needs a SizedBox to hold the
                // header's visual rhythm the way the 30px image did.
                SizedBox(
                  height: BrandGradient.wordmarkFontSize,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BrandGradient.text(context),
                  ),
                )
              else
                Text(
                  _navItems[_currentNavIndex].label,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _searchVisible = !_searchVisible),
                icon: Icon(
                  _searchVisible ? Icons.close_rounded : Icons.search_rounded,
                  color: ext.textSecondary,
                ),
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) => IconButton(
                  tooltip: themeProvider.isDark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onPressed: themeProvider.toggleTheme,
                  icon: Icon(
                    themeProvider.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: ext.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          // What the library currently holds, in one quiet line. Hidden while it
          // is empty — "0 files · 0 B" is noise, not information.
          if (_currentNavIndex == 0)
            Consumer<RecentFilesProvider>(
              builder: (context, provider, _) {
                final summary = _librarySummary(provider.files);
                if (summary == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: AppTokens.xs),
                  child: Text(
                    summary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ext.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// "12 files · 24.3 MB in library", or `null` when there is nothing to say.
  String? _librarySummary(List<RecentFile> files) {
    if (files.isEmpty) return null;

    final bytes = files.fold<int>(0, (sum, file) => sum + file.size);
    return '${files.length} ${files.length == 1 ? 'file' : 'files'} · '
        '${_formatBytes(bytes)} in library';
  }

  /// Human-readable byte count, matching [RecentFile.formattedSize]'s scale.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildActionCards() {
    return Padding(
      // No top gap: the header's own 12dp bottom padding already separates the
      // stats line from this row, and two 12dp gaps read as a hole.
      padding: const EdgeInsets.fromLTRB(
        AppTokens.xl,
        0,
        AppTokens.xl,
        AppTokens.md,
      ),
      // IntrinsicHeight gives the Row a height to stretch to — inside a scroll
      // view an unbounded height would leave `stretch` with nothing to fill —
      // and both tiles then take the taller of the two contents instead of a
      // number someone has to remember to raise when a font gets bigger.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SurfaceActionCard(
                icon: Icons.document_scanner_outlined,
                title: 'Scan',
                subtitle: 'Camera to PDF',
                onTap: _scanDocument,
              ),
            ),
            const SizedBox(width: AppTokens.md),
            Expanded(
              child: _PrimaryActionCard(
                icon: Icons.file_download_outlined,
                title: 'Import',
                subtitle: 'Files, URL & more',
                onTap: _showImportSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTools() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.xl,
        0,
        AppTokens.xl,
        AppTokens.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: ToolTile(
              icon: Icons.content_cut_outlined,
              label: 'Split',
              onTap: _openSplitPdf,
            ),
          ),
          const SizedBox(width: _toolTileGap),
          Expanded(
            child: ToolTile(
              icon: Icons.merge_type_outlined,
              label: 'Merge',
              onTap: _openMergePdf,
            ),
          ),
          const SizedBox(width: _toolTileGap),
          Expanded(
            child: ToolTile(
              icon: Icons.image_outlined,
              label: 'Images',
              onTap: _openImageToPdf,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    RecentFilesProvider provider, {
    required bool showActiveDot,
  }) {
    if (!provider.isLoaded) {
      return const [
        SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      ];
    }

    if (_currentNavIndex == 1) {
      if (provider.favoriteFiles.isEmpty && _searchQuery.isEmpty) {
        return const [SliverFillRemaining(child: EmptyFavoritesState())];
      }
      return [
        _buildSectionHeader('Favorites', showActiveDot: showActiveDot),
        _buildFileGrid(provider, favoritesOnly: true),
      ];
    }

    if (_currentNavIndex == 2) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 4),
            child: LibraryView(),
          ),
        ),
      ];
    }

    if (_currentNavIndex == 3) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 4),
            child: SettingsView(),
          ),
        ),
      ];
    }

if (provider.files.isEmpty && _searchQuery.isEmpty) {
      return const [
        SliverFillRemaining(
          child: EmptyState(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Open your first PDF',
            message:
                'Tap the + button or use "Files" to\npick a document from your device.',
            gradientRing: true,
          ),
        )
      ];
    }

    return [
      _buildSectionHeader('Recent', showActiveDot: showActiveDot),
      _buildFileGrid(provider),
    ];
  }

  Widget _buildSectionHeader(String title, {required bool showActiveDot}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.xl,
          AppTokens.sm,
          AppTokens.xl,
          AppTokens.md,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (title == 'Recent' && !_showAllRecents)
              GestureDetector(
                onTap: () => setState(() => _showAllRecents = true),
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            if (title == 'Recent' && _showAllRecents) const SizedBox(width: AppTokens.sm),
            const SizedBox(width: AppTokens.xs),
            _buildViewToggle(),
            const SizedBox(width: AppTokens.xs),
            _buildSortButton(showActiveDot: showActiveDot),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    final isGrid = _viewMode == RecentViewMode.grid;

    return InkWell(
      onTap: () =>
          _setViewMode(isGrid ? RecentViewMode.list : RecentViewMode.grid),
      borderRadius: BorderRadius.circular(AppTokens.button),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sm),
        child: Tooltip(
          message: isGrid ? 'List view' : 'Grid view',
          child: Icon(
            isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
            size: 20,
            color: context.appColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton({required bool showActiveDot}) {

    return InkWell(
      onTap: () => showSortSheet(context),
      borderRadius: BorderRadius.circular(AppTokens.button),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sm),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 20,
              color: showActiveDot ? Theme.of(context).colorScheme.primary : context.appColors.textSecondary,
            ),
            if (showActiveDot)
              Positioned(
                top: -1,
                right: -3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileGrid(
    RecentFilesProvider provider, {
    bool favoritesOnly = false,
  }) {
    final needsRecompute =
        _cachedVersion != provider.version ||
        _cachedSearchQuery != _searchQuery ||
        _cachedSortMode != provider.sortMode;

    if (needsRecompute) {
      _cachedVersion = provider.version;
      _cachedSearchQuery = _searchQuery;
      _cachedSortMode = provider.sortMode;

      final allBase = provider.files;
      _cachedSortedAll = provider.sortFiles(_filteredFiles(allBase));

      final favBase = provider.favoriteFiles;
      _cachedSortedFavorites = provider.sortFiles(_filteredFiles(favBase));
    }

    var filtered = favoritesOnly ? _cachedSortedFavorites! : _cachedSortedAll!;

    if (!favoritesOnly && !_showAllRecents && _searchQuery.isEmpty) {
      filtered = filtered.take(9).toList();
    }

    if (filtered.isEmpty) {
      return const SliverFillRemaining(child: NoSearchResults(query: ''));
    }

    if (_viewMode == RecentViewMode.list) {
      return _buildFileList(filtered);
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.xl),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppTokens.lg,
          crossAxisSpacing: AppTokens.md,
          childAspectRatio: 0.55,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final file = filtered[index];
          return PdfGridCard(
            key: ValueKey(file.path),
            file: file,
            onTap: () => _openFile(file),
            onToggleFavorite: () =>
                context.read<RecentFilesProvider>().toggleFavorite(file.path),
            onLongPress: () => _showFileActions(file),
          );
        }, childCount: filtered.length),
      ),
    );
  }

  Widget _buildFileList(List<RecentFile> files) {
    final ext = context.appColors;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.xl),
      sliver: SliverToBoxAdapter(
        child: Container(
          // A `surface` card, one level above the page: the rows read as a
          // single sheet rather than as rows floating on the background.
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTokens.card),
            border: Border.all(color: ext.border),
            boxShadow: _lightLiftShadow(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < files.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: AppTokens.hairline,
                    color: ext.border,
                  ),
                RecentFileListRow(
                  key: ValueKey(files[i].path),
                  file: files[i],
                  onTap: () => _openFile(files[i]),
                  onToggleFavorite: () => context
                      .read<RecentFilesProvider>()
                      .toggleFavorite(files[i].path),
                  onMenu: () => _showFileActions(files[i]),
                  onLongPress: () => _showFileActions(files[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<RecentFile> _filteredFiles(List<RecentFile> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((f) => f.name.toLowerCase().contains(q)).toList();
  }
}

// -----------------------------------------------------------------------------
// Private UI components
// -----------------------------------------------------------------------------

/// Icon size in both main action tiles. Shared so the two tiles are built from
/// the same parts and can only differ in colour — which is the whole point of
/// the pair. A bordered icon box would be taller than a bare glyph and push the
/// glass tile past its height, so there is no box here: Scan is marked by its
/// surface, Import by its fill.
const double _actionCardIconSize = 24;

/// Gap between the glass tool tiles. A shade wider than [AppTokens.sm] so the
/// three panes read as separate objects rather than as one divided card.
const double _toolTileGap = 10;

// -----------------------------------------------------------------------------
// Private UI components
// -----------------------------------------------------------------------------

/// The secondary action — Scan.
///
/// Deliberately quiet next to [_PrimaryActionCard]: the same glass surface the
/// tool tiles below it are made of, at the taller shape a main action needs. It
/// has no fill of its own and no shadow to speak of, because the point of the
/// row is that Import is the only tile on the screen that is not glass.
class _SurfaceActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SurfaceActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = context.appColors;

    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.card),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.lg),
        decoration: ToolTile.glassSurface(ext),
        child: _ActionCardBody(
          icon: icon,
          title: title,
          subtitle: subtitle,
          foreground: Theme.of(context).colorScheme.onSurface,
          subtitleColor: ext.textSecondary,
        ),
      ),
    );
  }
}

/// The primary action — Import.
///
/// Filled solid with the primary colour, as AGENTS.md requires: one primary
/// action per screen. No gradient border — the glow behind the fill, tinted with
/// the primary itself, is what pulls the tile forward; a second brand element on
/// the same tile competed with it.
class _PrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.card),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(AppTokens.card),
          boxShadow: _primaryGlow(context),
        ),
        child: _ActionCardBody(
          icon: icon,
          title: title,
          subtitle: subtitle,
          foreground: onPrimary,
          subtitleColor: onPrimary.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

/// The shared layout of both main action tiles: icon, then title and subtitle
/// pinned to the bottom. Titles are w700, subtitles w400 in a muted colour, so
/// the pair reads as one label at two emphases.
///
/// Both tiles lay out identically — same padding, same bare outlined glyph, same
/// title and subtitle styles — and take only their colours from the caller. That
/// is what keeps the glass tile and the solid one the same size.
class _ActionCardBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color foreground;
  final Color subtitleColor;

  const _ActionCardBody({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: _actionCardIconSize, color: foreground),
        const Spacer(),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
        const SizedBox(height: AppTokens.xs),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }
}

/// The soft shadow light mode lifts a surface with.
///
/// Dark mode gets none — AGENTS.md reserves elevation for light mode, and there
/// the three surface levels plus the hairline already do the work.
List<BoxShadow>? _lightLiftShadow(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const [
            BoxShadow(
              color: AppColors.lightShadow,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ]
        : null;

/// The halo behind the primary action tile, tinted with the primary colour
/// itself.
///
/// The tile is already a solid primary fill, so a glow in any other hue read as
/// a second colour rather than as light. A single wide, low-offset shadow keeps
/// it to one soft edge. Light mode drops the alpha because a near-white page
/// swallows a strong halo that dark mode reads clearly.
List<BoxShadow> _primaryGlow(BuildContext context) {
  final isLight = Theme.of(context).brightness == Brightness.light;

  return [
    BoxShadow(
      color: Theme.of(context).colorScheme.primary.withValues(
            alpha: isLight ? 0.2 : 0.3,
          ),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
  ];
}

class _ImportOptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.appColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppTokens.pill),
              ),
              child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.appColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// The circular "Add document" action, rendered in Scaffold's FAB slot so it
/// stays pinned above the bottom navigation bar at every scroll offset.
///
/// The brand gradient is alive: the ramp drifts slowly back and forth so the
/// colours appear to flow within the circle. The circle itself never moves or
/// resizes, and the four brand colours never change — only the gradient's
/// axis does, so the [BrandGradient] contrast guarantees still hold.
///
/// It is its own `StatefulWidget` rather than a method on the home screen so
/// the ticker lives exactly as long as the button: when the user switches to
/// Favorites, Library or Settings the slot becomes `null`, this widget is
/// unmounted and the controller is disposed, so nothing keeps ticking.
class _AddDocumentFab extends StatefulWidget {
  const _AddDocumentFab();

  @override
  State<_AddDocumentFab> createState() => _AddDocumentFabState();
}

class _AddDocumentFabState extends State<_AddDocumentFab>
    with SingleTickerProviderStateMixin {
  /// One full there-and-back sweep. Long enough to read as ambient rather than
  /// as motion.
  static const Duration _shimmerPeriod = Duration(seconds: 5);

  /// How far the gradient axis drifts, in alignment units. The ramp spans -1
  /// to 1, so this is a small fraction of the circle: a visible but gentle
  /// shift rather than the colours cycling round.
  static const double _drift = 0.16;

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: _shimmerPeriod,
  );

  @override
  void initState() {
    super.initState();
    _shimmer.repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  /// Mirrors `_HomeScreenState._pickFile` exactly — the same provider call, the
  /// same push — so moving the button into its own widget did not change what
  /// tapping it does.
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

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add document',
      child: SizedBox(
        width: _addFabSize,
        height: _addFabSize,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          // Material's resting FAB elevation.
          elevation: 6,
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _shimmer,
            // Only the gradient layer rebuilds per frame. The icon and the
            // ripple target are built once and passed through as `child`, so
            // the recurring repaint never touches them or the home screen.
            builder: (context, child) {
              // A cosine: zero velocity at both ends of the sweep, so the
              // ramp eases in and back out instead of running linearly, and
              // the value returns to its start each cycle for a seamless loop.
              final wave = -math.cos(_shimmer.value * 2 * math.pi);
              final shift = _drift * wave;
              return Ink(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: BrandGradient.linearFor(
                    context,
                    begin: Alignment(-1 + shift, -1 + shift * 0.6),
                    end: Alignment(1 + shift, 1 + shift * 0.6),
                  ),
                ),
                child: child,
              );
            },
            child: _AddDocumentTapTarget(onTap: _pickFile),
          ),
        ),
      ),
    );
  }
}

/// The FAB's ripple target and "+" glyph, split out so the shimmer can rebuild
/// the gradient without rebuilding them.
class _AddDocumentTapTarget extends StatelessWidget {
  final VoidCallback onTap;

  const _AddDocumentTapTarget({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: const Center(
        child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
