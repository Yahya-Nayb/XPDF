import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recent_file.dart';
import '../providers/annotations_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/recent_files_provider.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/brand_gradient.dart';
import '../widgets/xpdf_search_bar.dart';
import '../widgets/pdf_grid_card.dart';
import '../widgets/recent_file_list_row.dart';
import '../widgets/empty_state.dart';
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
import '../services/file_service.dart';

/// Display layouts for the Recent-files list.
///
/// Stored in SharedPreferences as the enum's lowercase name ("grid" | "list")
/// under the "recent_view_mode" key; Grid is the default.
enum RecentViewMode { grid, list }

/// Material's regular FAB diameter. Also the width of the scroll clearance
/// added at the end of the recents so the FAB never covers the last file.
const double _addFabSize = 56;

/// Bottom padding appended to the recents list. The FAB floats 16dp above the
/// bottom navigation bar (Scaffold's own margin), so the list needs to clear
/// 16 + [_addFabSize] for the button plus a further 16dp so the final row
/// settles fully above it rather than flush against it.
const double _addFabClearance = 16 + _addFabSize + 16;

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
    final colors = AppColors.schemeOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
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
                      color: colors.border,
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
                    color: colors.textPrimary,
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
    final colors = AppColors.schemeOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
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
                    ? const Color(0xFFF6B93B)
                    : colors.textSecondary,
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
                color: colors.textSecondary,
              ),
              title: const Text('Move to folder'),
              onTap: () {
                Navigator.pop(sheetContext);
                showMoveToFolderSheet(context, file);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.accent),
              title: Text(
                'Remove from recent',
                style: TextStyle(color: colors.accent),
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
    final colors = AppColors.schemeOf(context);
    final isSettingsView = _currentNavIndex == 3;
    final isHomeView = _currentNavIndex == 0;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (!isSettingsView) ...[
                    SliverToBoxAdapter(child: _buildTopBar(colors)),
                    if (_searchVisible && !isSettingsView)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: XpdfSearchBar(
                            controller: _searchController,
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            onClear: () => setState(() => _searchQuery = ''),
                          ),
                        ),
                      ),
                    if (isHomeView) ...[
                      SliverToBoxAdapter(child: _buildActionCards(colors)),
                      SliverToBoxAdapter(child: _buildQuickTools(colors)),
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
                  // The FAB floats over the bottom-right of this viewport, so
                  // the last recent file needs room to scroll clear of it. See
                  // [_addFabClearance].
                  const SliverToBoxAdapter(
                    child: SizedBox(height: _addFabClearance),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isHomeView ? const _AddDocumentFab() : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (i) => setState(() {
            _currentNavIndex = i;
            if (i != 0) _showAllRecents = false;
          }),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_rounded),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_rounded),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppColorScheme colors) {
    final titles = ['XPDF', 'Favorites', 'Library', 'Settings'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
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
              titles[_currentNavIndex],
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: colors.textPrimary,
              ),
            ),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() => _searchVisible = !_searchVisible),
            icon: Icon(
              _searchVisible ? Icons.close_rounded : Icons.search_rounded,
              color: colors.textSecondary,
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
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              icon: Icons.document_scanner_outlined,
              title: 'Scan',
              subtitle: 'Camera to PDF',
              background: colors.surface,
              foreground: colors.textPrimary,
              subtitleColor: colors.textSecondary,
              border: colors.border,
              onTap: _scanDocument,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.file_download_outlined,
              title: 'Import',
              subtitle: 'Files, URL & more',
              background: colors.accent,
              foreground: Colors.white,
              subtitleColor: Colors.white.withValues(alpha: 0.85),
              border: colors.accent,
              onTap: _showImportSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTools(AppColorScheme colors) {
    final (splitBg, splitFg) = _toolTint(context, 0);
    final (mergeBg, mergeFg) = _toolTint(context, 1);
    final (imageBg, imageFg) = _toolTint(context, 2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _QuickToolCard(
              icon: Icons.content_cut_rounded,
              name: 'Split',
              subtitle: 'Extract pages',
              iconBackground: splitBg,
              iconColor: splitFg,
              onTap: _openSplitPdf,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickToolCard(
              icon: Icons.merge_type_rounded,
              name: 'Merge',
              subtitle: 'Combine files',
              iconBackground: mergeBg,
              iconColor: mergeFg,
              onTap: _openMergePdf,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickToolCard(
              icon: Icons.image_rounded,
              name: 'Images',
              subtitle: 'To PDF',
              iconBackground: imageBg,
              iconColor: imageFg,
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
      return const [SliverFillRemaining(child: EmptyState())];
    }

    return [
      _buildSectionHeader('Recent', showActiveDot: showActiveDot),
      _buildFileGrid(provider),
    ];
  }

  Widget _buildSectionHeader(String title, {required bool showActiveDot}) {
    final colors = AppColors.schemeOf(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
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
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            if (title == 'Recent' && _showAllRecents) const SizedBox(width: 8),
            const SizedBox(width: 4),
            _buildViewToggle(),
            const SizedBox(width: 4),
            _buildSortButton(showActiveDot: showActiveDot),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    final colors = AppColors.schemeOf(context);
    final isGrid = _viewMode == RecentViewMode.grid;

    return InkWell(
      onTap: () =>
          _setViewMode(isGrid ? RecentViewMode.list : RecentViewMode.grid),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Tooltip(
          message: isGrid ? 'List view' : 'Grid view',
          child: Icon(
            isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
            size: 20,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton({required bool showActiveDot}) {
    final colors = AppColors.schemeOf(context);

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
              color: showActiveDot ? colors.accent : colors.textSecondary,
            ),
            if (showActiveDot)
              Positioned(
                top: -1,
                right: -3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors.accent,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
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
    final colors = AppColors.schemeOf(context);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < files.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: colors.border),
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color foreground;
  final Color subtitleColor;
  final Color border;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.foreground,
    required this.subtitleColor,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: foreground),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// A standalone quick-tool card: colored icon box, tool name and a one-line
/// subtitle, laid out as its own bordered card (no shared background strip).
class _QuickToolCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String subtitle;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickToolCard({
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.iconBackground,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.schemeOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A muted, theme-aware background+foreground pair for the tool entry points.
///
/// Index: 0 = Split (muted violet), 1 = Merge (muted blue), 2 = Images-to-PDF
/// (accent red — the flagship tool). Each pair stays soft and harmonious with
/// the neutral+accent palette in both light and dark mode.
(Color, Color) _toolTint(BuildContext context, int index) {
  final dark = AppColors.isDark(context);
  switch (index) {
    case 0: // Split — light purple box, purple icon
      return dark
          ? (const Color(0xFF2B2335), const Color(0xFFB79BD6))
          : (const Color(0xFFEFE9FB), const Color(0xFF7C5CD6));
    case 1: // Merge — light blue box, blue icon
      return dark
          ? (const Color(0xFF1D2738), const Color(0xFF7EA6E0))
          : (const Color(0xFFE3F1FB), const Color(0xFF3186C4));
    default: // Images to PDF — accent red
      return dark
          ? (const Color(0xFF3A1E22), const Color(0xFFFF4A56))
          : (const Color(0xFFFCE4E6), const Color(0xFFEF3F4B));
  }
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
    final colors = AppColors.schemeOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.accentTint,
                borderRadius: BorderRadius.circular(AppColors.radiusChip),
              ),
              child: Icon(icon, size: 22, color: colors.accent),
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
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
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
