import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../colors.dart';
import '../models/recent_file.dart';
import '../providers/recent_files_provider.dart';
import '../providers/settings_provider.dart';

/// Full-screen PDF viewer with zoom controls, jump-to-page,
/// file sharing, and bookmarks — powered by pdfrx (PDFium).
class PdfViewerScreen extends StatefulWidget {
  final RecentFile file;
  const PdfViewerScreen({super.key, required this.file});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfViewerController _controller;
  PdfTextSearcher? _textSearcher;

  // ---------------------------------------------------------------------------
  // Reading defaults — captured ONCE in initState so changing a setting
  // mid-session never mutates an already-open viewer. Only files opened
  // afterwards pick up the new defaults.
  // ---------------------------------------------------------------------------
  late final bool _rememberLastPage;
  late final bool _useSinglePageLayout;

  /// Current visible height of the viewer, tracked for the single-page
  /// layout (each page gets its own viewport-height slot).
  double _viewHeight = 0;

  // ---------------------------------------------------------------------------
  // Page tracking
  // ---------------------------------------------------------------------------
  int _currentPage = 1;
  int _totalPages = 0;

  // ---------------------------------------------------------------------------
  // Zoom state — tracked via controller listener since pdfrx has no
  // direct zoomLevel setter; we use setZoom() and read currentZoom.
  // Using a ValueNotifier so only the percentage label rebuilds, not the
  // entire AppBar/Tooltip/Icon cascade on every scroll/zoom frame.
  // ---------------------------------------------------------------------------
  final ValueNotifier<double> _zoomNotifier = ValueNotifier<double>(1.0);
  static const double _minZoom = 1.0;
  static const double _maxZoom = 3.0;

  // ---------------------------------------------------------------------------
  // TEMPORARY DEBUG: per-second performance counters. Each counter tracks how
  // many times a potentially per-frame callback fired in the last second:
  //   builds   — State.build() calls (any setState source)
  //   ctrl     — controller listener calls (scroll/zoom matrix changes)
  //   page     — pdfrx onPageChanged callbacks (page crossings only, expected ~0)
  //   viewSize — onViewSizeChanged callbacks (viewport resizes, expected 0)
  //   search   — text-searcher notifications (expected 0 while not searching)
  // A healthy profile during continuous scrolling is: builds≈0-2/s,
  // ctrl=high (matrix updates are expected every frame), page/viewSize/search=0.
  // If builds climbs every frame instead, something is rebuilding per-frame
  // and the [Perf] line will prove it.
  // ---------------------------------------------------------------------------
  int _perfBuilds = 0;
  int _perfCtrl = 0;
  int _perfPage = 0;
  int _perfViewSize = 0;
  int _perfSearch = 0;
  Timer? _perfTimer;

  // ---------------------------------------------------------------------------
  // Bookmarks (PDF outline)
  // ---------------------------------------------------------------------------
  List<PdfOutlineNode> _outlineNodes = [];

  // ---------------------------------------------------------------------------
  // Search state
  // ---------------------------------------------------------------------------
  bool _searchActive = false;
  final TextEditingController _searchInputController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ---------------------------------------------------------------------------
  // Cached PdfViewerParams callbacks — stable references so pdfrx's
  // didUpdateWidget doesn't detect spurious param changes every build.
  // ---------------------------------------------------------------------------
  late final void Function(int?) _onPageChanged;
  late final void Function(PdfDocumentRef, bool) _onDocLoadFinished;
  late final Future<void> Function(PdfDocument, PdfViewerController) _onViewerReady;
  late final PdfViewerViewSizeChanged _onViewSizeChanged;
  late final PdfPageLayoutFunction _pagedLayout;

  // =========================================================================
  // Lifecycle
  // =========================================================================

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();

    // Snapshot reading defaults once — an already-open viewer is never
    // affected by settings changed mid-session.
    final settings = context.read<SettingsProvider>();
    _rememberLastPage = settings.rememberLastPage;
    _useSinglePageLayout = settings.isSinglePageLayout;

    // TEMPORARY DEBUG: values the viewer will act on. These are the values
    // SettingsProvider hydrated from SharedPreferences at app start.
    debugPrint('[PdfViewer] initState "${widget.file.name}" ← '
        'pageLayoutMode="${settings.pageLayoutMode}" '
        '(useSinglePage=$_useSinglePageLayout), '
        'rememberLastPage=$_rememberLastPage');

    // "Remember last page" off → always start at page 1 (and skip saving
    // the position on dispose).
    _currentPage = _rememberLastPage ? widget.file.lastPage : 1;
    // TEMPORARY DEBUG: which page the viewer actually opens at.
    debugPrint(
        '[PdfViewer] Remember-last-page ${_rememberLastPage ? 'ON → restoring page $_currentPage' : 'OFF → starting at page 1'}');

    // Track zoom changes via the controller (it's a ValueListenable<Matrix4>).
    _controller.addListener(_onControllerUpdate);

    // TEMPORARY DEBUG: 1-second aggregated perf sampler (see counters above).
    _perfTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      debugPrint('[Perf 1s] layout=${_useSinglePageLayout ? 'SINGLE' : 'continuous'} '
          'zoom=${_zoomNotifier.value.toStringAsFixed(2)} '
          'builds=$_perfBuilds ctrl=$_perfCtrl page=$_perfPage '
          'viewSize=$_perfViewSize search=$_perfSearch');
      _perfBuilds = _perfCtrl = _perfPage = _perfViewSize = _perfSearch = 0;
    });

    // Cache PdfViewerParams callbacks so they are stable references.
    _onPageChanged = (int? pageNumber) {
      _perfPage++; // TEMPORARY DEBUG
      if (pageNumber != null) {
        setState(() => _currentPage = pageNumber);
      }
    };
    _onDocLoadFinished = (PdfDocumentRef documentRef, bool loadSucceeded) {
      if (loadSucceeded) {
        setState(() => _totalPages = _controller.pageCount);
      }
    };
    _onViewerReady = (PdfDocument document, PdfViewerController controller) async {
      if (mounted) {
        _textSearcher = PdfTextSearcher(_controller)..addListener(_onSearchUpdate);
      }
      final List<PdfOutlineNode> outline = await document.loadOutline();
      if (mounted) {
        setState(() => _outlineNodes = outline);
      }
    };

    // Track the visible viewer height; in single-page mode a size change
    // means the per-page slots must be recomputed, so relayout. The first
    // callback also invalidates because the initial layout may have run
    // before the real height was known (it falls back to max page height).
    _onViewSizeChanged = (Size viewSize, Size? oldViewSize,
        PdfViewerController controller) {
      _perfViewSize++; // TEMPORARY DEBUG
      final bool changed = viewSize.height != _viewHeight;
      _viewHeight = viewSize.height;
      if (_useSinglePageLayout && changed && mounted) {
        controller.invalidate();
      }
    };

    // Single-page layout: every page sits centered inside its own
    // viewport-height slot, so only one page is on screen at a time
    // (pdfrx 2.x has no built-in view mode — layout is fully driven by
    // this callback). Continuous scroll uses pdfrx's default layout.
    _pagedLayout = (List<PdfPage> pages, PdfViewerParams params) {
      final double width =
          pages.fold<double>(0, (w, p) => p.width > w ? p.width : w) +
              params.margin * 2;
      final double slotHeight = _viewHeight > 0
          ? _viewHeight
          : pages.fold<double>(0, (h, p) => p.height > h ? p.height : h) +
              params.margin * 2;
      final List<Rect> pageRects = <Rect>[];
      double y = params.margin;
      for (final PdfPage page in pages) {
        pageRects.add(
          Rect.fromLTWH((width - page.width) / 2, y, page.width, page.height),
        );
        y += slotHeight;
      }
      return PdfPageLayout(
        pageLayouts: pageRects,
        documentSize: Size(width, y),
      );
    };

    // Mark the file as "just opened" so it moves to the top of recents.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RecentFilesProvider>().openFile(
            widget.file.path,
            name: widget.file.name,
            size: widget.file.size,
          );
    });
  }

  @override
  void dispose() {
    // TEMPORARY DEBUG: stop the perf sampler.
    _perfTimer?.cancel();
    // "Remember last page" off → don't persist the reading position either.
    if (_rememberLastPage) {
      // TEMPORARY DEBUG: confirm the save path runs on close.
      debugPrint('[PdfViewer] dispose "${widget.file.name}" → '
          'SAVING last page=$_currentPage');
      _savePage();
    } else {
      // TEMPORARY DEBUG: confirm the save path is skipped when the setting is off.
      debugPrint('[PdfViewer] dispose "${widget.file.name}" → '
          'save SKIPPED (Remember-last-page OFF)');
    }
    _controller.removeListener(_onControllerUpdate);
    _zoomNotifier.dispose();
    _textSearcher?.removeListener(_onSearchUpdate);
    _textSearcher?.dispose();
    _searchInputController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Called on every controller change (zoom, scroll position, etc.).
  /// Updates the ValueNotifier directly — no setState, so only the
  /// ValueListenableBuilder wrapping the zoom label rebuilds.
  void _onControllerUpdate() {
    _perfCtrl++; // TEMPORARY DEBUG
    if (!mounted || !_controller.isReady) return;
    final double newZoom = _controller.currentZoom;
    if ((newZoom - _zoomNotifier.value).abs() > 0.01) {
      _zoomNotifier.value = newZoom;
    }
  }

  /// Called when the text searcher finishes processing pages or updates state.
  void _onSearchUpdate() {
    _perfSearch++; // TEMPORARY DEBUG
    if (mounted) setState(() {});
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  void _savePage() {
    context.read<RecentFilesProvider>().updatePageNumber(
          widget.file.path,
          _currentPage,
        );
  }

  // =========================================================================
  // Search helpers
  // =========================================================================

  void _openSearch() {
    setState(() => _searchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _textSearcher?.resetTextSearch();
    _searchInputController.clear();
    setState(() => _searchActive = false);
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      _textSearcher?.resetTextSearch();
      return;
    }
    _textSearcher?.startTextSearch(query);
  }

  // =========================================================================
  // Zoom helpers
  // =========================================================================

  void _zoomIn() {
    if (!_controller.isReady) return;
    final double current = _zoomNotifier.value;
    final double next = (current + 0.25).clamp(_minZoom, _maxZoom);
    if (next != current) {
      _controller.setZoom(
        Offset(
          _controller.viewSize.width / 2,
          _controller.viewSize.height / 2,
        ),
        next,
      );
      // _onControllerUpdate → _zoomNotifier.value will fire from the listener.
    }
  }

  void _zoomOut() {
    if (!_controller.isReady) return;
    final double current = _zoomNotifier.value;
    final double next = (current - 0.25).clamp(_minZoom, _maxZoom);
    if (next != current) {
      _controller.setZoom(
        Offset(
          _controller.viewSize.width / 2,
          _controller.viewSize.height / 2,
        ),
        next,
      );
      // _onControllerUpdate → _zoomNotifier.value will fire from the listener.
    }
  }

  // =========================================================================
  // Jump-to-page
  // =========================================================================

  void _showJumpToPageDialog() {
    final TextEditingController pageInput = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AppColors.colorOf(context, 'surface'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Jump to page',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.colorOf(context, 'textPrimary'),
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: pageInput,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
              decoration: InputDecoration(
                hintText: '1 – $_totalPages',
                hintStyle: TextStyle(color: AppColors.colorOf(context, 'textMuted')),
                filled: true,
                fillColor: AppColors.colorOf(context, 'inputFill'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.colorOf(context, 'primary')),
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) return 'Enter a page number';
                final int? page = int.tryParse(value);
                if (page == null || page < 1 || page > _totalPages) {
                  return 'Must be between 1 and $_totalPages';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.colorOf(context, 'textSecondary')),
              ),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final int page = int.parse(pageInput.text);
                  _controller.goToPage(pageNumber: page);
                  Navigator.of(ctx).pop();
                }
              },
              child: Text(
                'Go',
                style: TextStyle(
                  color: AppColors.colorOf(context, 'primary'),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // Share
  // =========================================================================

  Future<void> _shareFile() async {
    final XFile xfile = XFile(widget.file.path);
    await SharePlus.instance.share(
      ShareParams(files: [xfile], subject: widget.file.name),
    );
  }

  // =========================================================================
  // Bookmarks panel
  // =========================================================================

  /// Flatten a tree of PdfOutlineNode into a flat list for the bottom sheet UI.
  void _flattenOutline(List<PdfOutlineNode> nodes, List<PdfOutlineNode> flat) {
    for (final PdfOutlineNode node in nodes) {
      flat.add(node);
      if (node.children.isNotEmpty) {
        _flattenOutline(node.children, flat);
      }
    }
  }

  void _showBookmarksPanel() {
    if (_outlineNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bookmarks in this file'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final List<PdfOutlineNode> flat = [];
    _flattenOutline(_outlineNodes, flat);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.colorOf(context, 'surface'),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.25,
          maxChildSize: 0.85,
          expand: false,
          builder: (BuildContext ctx, ScrollController scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.colorOf(context, 'border'),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bookmarks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.colorOf(context, 'textPrimary'),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.colorOf(context, 'border')),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: flat.length,
                    itemBuilder: (BuildContext ctx, int index) {
                      final PdfOutlineNode node = flat[index];
                      return ListTile(
                        leading: Icon(
                          Icons.bookmark_outline,
                          color: AppColors.colorOf(context, 'primary'),
                          size: 20,
                        ),
                        title: Text(
                          node.title,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.colorOf(context, 'textPrimary'),
                          ),
                        ),
                        onTap: () {
                          if (node.dest != null) {
                            _controller.goToDest(node.dest);
                          }
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    _perfBuilds++; // TEMPORARY DEBUG: counts every rebuild of this screen
    return Scaffold(
      backgroundColor: AppColors.colorOf(context, 'background'),
      appBar: AppBar(
        backgroundColor: AppColors.colorOf(context, 'surface'),
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.colorOf(context, 'textPrimary'),
          ),
        ),
        elevation: 0,
        actions: [
          // -- Search icon --
          IconButton(
            icon: Icon(
              _searchActive ? Icons.close : Icons.search,
              color: AppColors.colorOf(context, 'textSecondary'),
              size: 22,
            ),
            onPressed: _searchActive ? _closeSearch : _openSearch,
            tooltip: 'Search',
          ),

          // -- Zoom out --
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              color: AppColors.colorOf(context, 'textSecondary'),
              size: 22,
            ),
            onPressed: _zoomOut,
            tooltip: 'Zoom out',
          ),

          // -- Zoom level label (only this widget rebuilds on zoom change) --
          ValueListenableBuilder<double>(
            valueListenable: _zoomNotifier,
            builder: (context, zoom, _) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    '${(zoom * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.colorOf(context, 'textSecondary'),
                    ),
                  ),
                ),
              );
            },
          ),

          // -- Zoom in --
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: AppColors.colorOf(context, 'textSecondary'),
              size: 22,
            ),
            onPressed: _zoomIn,
            tooltip: 'Zoom in',
          ),

          // -- Share --
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: AppColors.colorOf(context, 'textSecondary'),
              size: 22,
            ),
            onPressed: _shareFile,
            tooltip: 'Share file',
          ),

          // -- Page indicator badge --
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.colorOf(context, 'inputFill'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _totalPages > 0
                    ? '$_currentPage / $_totalPages'
                    : '$_currentPage',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.colorOf(context, 'textSecondary'),
                ),
              ),
            ),
          ),

          // -- Overflow menu: jump-to-page & bookmarks --
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: AppColors.colorOf(context, 'textSecondary'),
              size: 22,
            ),
            color: AppColors.colorOf(context, 'surface'),
            onSelected: (String value) {
              if (value == 'jump') {
                _showJumpToPageDialog();
              } else if (value == 'bookmarks') {
                _showBookmarksPanel();
              }
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
               PopupMenuItem<String>(
                value: 'jump',
                child: Row(
                  children: [
                    Icon(Icons.numbers, size: 20, color: AppColors.colorOf(context, 'textSecondary')),
                    const SizedBox(width: 12),
                    Text(
                      'Jump to page',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.colorOf(context, 'textPrimary'),
                      ),
                    ),
                  ],
                ),
              ),
               PopupMenuItem<String>(
                value: 'bookmarks',
                child: Row(
                  children: [
                    Icon(Icons.bookmark_outline, size: 20, color: AppColors.colorOf(context, 'textSecondary')),
                    const SizedBox(width: 12),
                    Text(
                      'Bookmarks',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.colorOf(context, 'textPrimary'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // -- Search bar (only visible when _searchActive is true) --
          if (_searchActive) _buildSearchBar(),

          // -- PDF viewer (fills remaining space) --
          Expanded(
            child: RepaintBoundary(
              child: PdfViewer.file(
                widget.file.path,
                key: ValueKey(widget.file.path),
                controller: _controller,
                initialPageNumber: _currentPage,
                params: PdfViewerParams(
                  textSelectionParams: const PdfTextSelectionParams(
                    enabled: false,
                  ),
                  margin: 0,
                  pageDropShadow: null,
                  layoutPages: _useSinglePageLayout ? _pagedLayout : null,
                  onViewSizeChanged: _onViewSizeChanged,
                  pagePaintCallbacks: [
                    if (_textSearcher != null) _textSearcher!.pageTextMatchPaintCallback,
                  ],
                  onPageChanged: _onPageChanged,
                  onDocumentLoadFinished: _onDocLoadFinished,
                  onViewerReady: _onViewerReady,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Search bar widget
  // =========================================================================

  Widget _buildSearchBar() {
    final bool hasResults = _textSearcher?.hasMatches ?? false;
    final int total = _textSearcher?.matches.length ?? 0;
    final int current = hasResults && _textSearcher?.currentIndex != null
        ? _textSearcher!.currentIndex! + 1
        : 0;
    final String counterText =
        (total > 0) ? '$current / $total' : (_searchInputController.text.isNotEmpty ? 'No results' : '');

    return Container(
      color: AppColors.colorOf(context, 'surface'),
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
      child: Row(
        children: [
          // -- Text input --
          Expanded(
            child: TextField(
              controller: _searchInputController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
              decoration: InputDecoration(
                hintText: 'Search in document…',
                hintStyle: TextStyle(color: AppColors.colorOf(context, 'textMuted')),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: AppColors.colorOf(context, 'inputFill'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.colorOf(context, 'primary')),
                ),
              ),
              onChanged: _performSearch,
            ),
          ),

          const SizedBox(width: 8),

          // -- Result counter ("3 / 12") --
          if (counterText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                counterText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.colorOf(context, 'textSecondary'),
                ),
              ),
            ),

          // -- Previous match --
          if (hasResults)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 22),
              color: AppColors.colorOf(context, 'textSecondary'),
              onPressed: () => _textSearcher?.goToPrevMatch(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Previous match',
            ),

          // -- Next match --
          if (hasResults)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 22),
              color: AppColors.colorOf(context, 'textSecondary'),
              onPressed: () => _textSearcher?.goToNextMatch(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Next match',
            ),

          // -- Close search --
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.colorOf(context, 'textMuted'),
            onPressed: _closeSearch,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Close search',
          ),
        ],
      ),
    );
  }
}
