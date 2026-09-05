import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Hide pdfrx's low-level PdfAnnotation (engine-side) — our app-level
// annotation model ships under the same name.
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../colors.dart';
import '../models/pdf_annotation.dart';
import '../models/recent_file.dart';
import '../providers/annotations_provider.dart';
import '../providers/recent_files_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/confirm_dialog.dart';

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
  late final Future<void> Function(PdfDocument, PdfViewerController)
  _onViewerReady;
  late final PdfViewerViewSizeChanged _onViewSizeChanged;
  late final PdfPageLayoutFunction _pagedLayout;
  late final PdfTextSelectionParams _textSelectionParams;
  late final PdfViewerContextMenuBuilder _buildSelectionContextMenu;
  late final PdfPageOverlaysBuilder _pageOverlays;

  // ---------------------------------------------------------------------------
  // Highlight annotations
  // ---------------------------------------------------------------------------

  /// Annotations for the currently open file, kept as a cached snapshot so
  /// overlay builds never touch the provider tree mid-frame. Refreshed from
  /// [AnnotationsProvider] only when this file's list actually changes.
  final List<PdfAnnotation> _annotationsForFile = [];

  AnnotationsProvider? _annotationsProvider;

  // ---------------------------------------------------------------------------
  // Floating selection toolbar (Highlight bar)
  // ---------------------------------------------------------------------------

  /// Latest PdfTextSelection state fed to [onTextSelectionChange] (see below).
  /// Kept so the toolbar's Highlight action can create annotations from the
  /// currently selected text without holding onto a live pdfrx delegate.
  PdfTextSelectionRange? _lastSelectionRange;

  /// Whether the floating toolbar is currently shown. It is hidden whenever
  /// the selection is cleared or the viewer's copy permission blocks it.
  bool _selectionToolbarVisible = false;

  /// Page (1-indexed) on which the END of the selection sits — the toolbar is
  /// anchored to the last selected fragment's rect, so it appears right next
  /// to where the user finished selecting.
  int _selectionToolbarPage = 0;

  /// Rect of the last selected text fragment, in PDF page coordinates. Stored
  /// in the same coordinate space as annotation rects so it stays glued to the
  /// text at any zoom level; converted to viewer-local at render time.
  PdfRect? _selectionToolbarEndRect;

  /// Generation counter — rapid selection changes (handle drags) fire several
  /// callbacks in a row; a stale async rect computation must not overwrite a
  /// newer one. (Only the rare async fallback path needs this; the common path
  /// anchors the toolbar synchronously inside the selection callback.)
  int _selectionChangeSeq = 0;

  /// TEMPORARY DEBUG: wall-clock time of the most recent selection callback,
  /// so the toolbar render pass can report how many ms it took the toolbar to
  /// appear (delay-bug diagnostics). Remove once verified.
  DateTime? _selectionCallbackTs;

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
    debugPrint(
      '[PdfViewer] initState "${widget.file.name}" ← '
      'pageLayoutMode="${settings.pageLayoutMode}" '
      '(useSinglePage=$_useSinglePageLayout), '
      'rememberLastPage=$_rememberLastPage',
    );

    // "Remember last page" off → always start at page 1 (and skip saving
    // the position on dispose).
    _currentPage = _rememberLastPage ? widget.file.lastPage : 1;
    // TEMPORARY DEBUG: which page the viewer actually opens at.
    debugPrint(
      '[PdfViewer] Remember-last-page ${_rememberLastPage ? 'ON → restoring page $_currentPage' : 'OFF → starting at page 1'}',
    );

    // Track zoom changes via the controller (it's a ValueListenable<Matrix4>).
    _controller.addListener(_onControllerUpdate);

    // Subscribe to the annotations provider so highlight changes for this
    // file refresh the page overlays without rebuilding the whole screen.
    // The provider (annotations_provider.dart) is the SINGLE source of truth:
    // it is hydrated once at app startup (home_screen calls loadAll()), so its
    // notifyListeners() for RESTORED annotations fires BEFORE this screen
    // subscribes. Relying on the listener alone leaves _annotationsForFile
    // empty for saved highlights — the annotations panel (reads the provider
    // directly) shows them but the page-overlay builder draws nothing. We
    // therefore mirror the provider's list into our snapshot immediately at
    // subscribe time; the listener below keeps it fresh for live edits.
    _annotationsProvider = context.read<AnnotationsProvider>()
      ..addListener(_onAnnotationsChanged);
    _annotationsForFile
      ..clear()
      ..addAll(
        _annotationsProvider?.annotationsForFile(widget.file.path) ?? const [],
      );
    // TEMPORARY DEBUG: confirm the restored annotations actually reach the
    // overlay snapshot right at open (previously they never did).
    debugPrint(
      '[Annotations] viewer "${widget.file.name}" opened: '
      '${_annotationsForFile.length} annotation(s) in snapshot '
      '(source: provider${_annotationsProvider?.isLoaded == true ? ' already loaded' : ', hydration in flight'})',
    );
    // Ensure hydration even on a cold/direct open. Once loaded this is a
    // no-op; if the load is still in flight its notifyListeners() will also
    // refresh us via _onAnnotationsChanged (setState + mounted-guarded).
    _annotationsProvider?.loadAnnotations(widget.file.path);

    // TEMPORARY DEBUG: 1-second aggregated perf sampler (see counters above).
    _perfTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      debugPrint(
        '[Perf 1s] layout=${_useSinglePageLayout ? 'SINGLE' : 'continuous'} '
        'zoom=${_zoomNotifier.value.toStringAsFixed(2)} '
        'builds=$_perfBuilds ctrl=$_perfCtrl page=$_perfPage '
        'viewSize=$_perfViewSize search=$_perfSearch',
      );
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
    _onViewerReady =
        (PdfDocument document, PdfViewerController controller) async {
          if (mounted) {
            _textSearcher = PdfTextSearcher(_controller)
              ..addListener(_onSearchUpdate);
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
    _onViewSizeChanged =
        (Size viewSize, Size? oldViewSize, PdfViewerController controller) {
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

    // Text selection — enabled so users can select words/lines. pdfrx keeps
    // its pan/zoom/scroll gestures (and ours) working through its own gesture
    // arena; the overlay regions below are pointer-transparent so they never
    // compete with selection or scrolling.
    //
    // The floating Highlight toolbar is OUR widget, rendered through
    // pageOverlaysBuilder and driven by [PdfTextSelectionParams.onTextSelectionChange].
    // pdfrx's built-in context menu is intentionally NOT auto-shown
    // (showContextMenuAutomatically: false) — it is gated behind PDF copy
    // permissions (a file with copying disabled suppresses it entirely, which
    // is why the native copy menu never appeared), and its device-based auto
    // show only fires on touch. Our toolbar is not subject to either.
    _textSelectionParams = PdfTextSelectionParams(
      enabled: true,
      showContextMenuAutomatically: false,
      onTextSelectionChange: _onSelectionChanged,
    );

    // Context menu shown next to the active selection: a "Highlight" action
    // (opens the color-picker sheet) plus the standard Copy action.
    _buildSelectionContextMenu =
        (BuildContext context, PdfViewerContextMenuBuilderParams params) {
          if (params.contextMenuFor != PdfViewerPart.selectedText) {
            return null;
          }
          final PdfTextSelectionDelegate delegate =
              params.textSelectionDelegate;
          if (!delegate.isCopyAllowed) {
            return null;
          }
          final List<ContextMenuButtonItem> items = <ContextMenuButtonItem>[
            ContextMenuButtonItem(
              onPressed: () => _showHighlightCreationSheet(
                params.textSelectionDelegate,
                initialColorHex: PdfAnnotation.defaultColorHex,
                onDismiss: params.dismissContextMenu,
              ),
              label: 'Highlight',
            ),
            if (delegate.hasSelectedText)
              ContextMenuButtonItem(
                onPressed: () => delegate.copyTextSelection(),
                type: ContextMenuButtonType.copy,
              ),
          ];
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: TextSelectionToolbarAnchors(
              primaryAnchor: params.anchorA,
              secondaryAnchor: params.anchorB ?? params.anchorA,
            ),
            buttonItems: items,
          );
        };

    // Page overlays: semi-transparent highlight rectangles over each page,
    // wrapped in pointer-transparent interaction regions so taps are
    // classified by the viewer (pan/zoom/text selection never compete).
    // Rects are stored in PDF page coordinates and converted to the current
    // on-screen page rect via pdfrx's own coordinate helpers.
    _pageOverlays =
        (BuildContext context, Rect pageRectInViewer, PdfPage page) {
          // Night mode: only the PAGE pixels are night-rendered (the whole
          // viewer is wrapped in the soft warm-desaturated inversion filter).
          // Our overlay widgets are pre-compensated with that filter's exact
          // affine INVERSE below, so highlights net back to their authored
          // color instead of being darkened along with the page.
          final bool night = context.read<SettingsProvider>().isNightMode;
          // Slightly stronger band at night so highlights stay clearly
          // distinguishable against the now-dark pages.
          final double highlightAlpha = night ? 0.5 : 0.42;
          final List<PdfAnnotation> anns = _annotationsForFile
              .where((a) => a.pageNumber == page.pageNumber)
              .toList();
          // TEMPORARY DEBUG: proves the overlay layer actually sees the loaded
          // annotations per page (restored highlights previously never reached
          // this snapshot, so this printed 0).
          if (anns.isNotEmpty) {
            final int rects = anns.fold(0, (sum, a) => sum + a.rects.length);
            debugPrint(
              '[Overlay] page ${page.pageNumber}: drawing '
              '${anns.length} annotation(s), $rects rect(s) '
              '(snapshot has ${_annotationsForFile.length} total for file)',
            );
          }
          final List<Widget> widgets = <Widget>[];
          for (final PdfAnnotation annotation in anns) {
            final Color color = annotation.color.withValues(
              alpha: highlightAlpha,
            );
            for (var i = 0; i < annotation.rects.length; i++) {
              final AnnotationRect r = annotation.rects[i];
              final Rect rect = PdfRect(
                r.x,
                r.y,
                r.x + r.width,
                r.y - r.height,
              ).toRect(page: page, scaledPageSize: pageRectInViewer.size);
              if (rect.isEmpty) continue;
              final Widget highlight = ColoredBox(color: color);
              widgets.add(
                Positioned.fromRect(
                  key: ObjectKey('${annotation.id}:$i'),
                  rect: rect,
                  child: PdfOverlayInteractionRegion(
                    onTap: (_) {
                      _showAnnotationActions(annotation.id);
                      return true;
                    },
                    child: night ? NightMode.counterWrap(highlight) : highlight,
                  ),
                ),
              );
            }
          }

          // Floating Highlight toolbar, anchored to the LAST selected text
          // fragment on the page where the selection ends. Positioned in
          // viewer-local coordinates (converted from PDF coords like the
          // highlight rects above), so it follows zoom and layout changes.
          if (_selectionToolbarVisible &&
              _selectionToolbarEndRect != null &&
              page.pageNumber == _selectionToolbarPage) {
            final Rect endRectInPage = _selectionToolbarEndRect!.toRect(
              page: page,
              scaledPageSize: pageRectInViewer.size,
            );
            if (!endRectInPage.isEmpty) {
              widgets.add(
                _buildSelectionToolbar(
                  endRectInPage,
                  pageRectInViewer.size,
                  nightMode: night,
                ),
              );
            }
          }
          return widgets;
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
      debugPrint(
        '[PdfViewer] dispose "${widget.file.name}" → '
        'SAVING last page=$_currentPage',
      );
      _savePage();
    } else {
      // TEMPORARY DEBUG: confirm the save path is skipped when the setting is off.
      debugPrint(
        '[PdfViewer] dispose "${widget.file.name}" → '
        'save SKIPPED (Remember-last-page OFF)',
      );
    }
    _controller.removeListener(_onControllerUpdate);
    _annotationsProvider?.removeListener(_onAnnotationsChanged);
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

  /// Called whenever the annotations provider notifies (any file).
  ///
  /// Refreshes only when THIS file's annotation list actually changed;
  /// edits to other files' highlights are skipped so they can't trigger
  /// rebuilds here.
  void _onAnnotationsChanged() {
    if (!mounted || _annotationsProvider == null) return;
    final List<PdfAnnotation> fresh = _annotationsProvider!.annotationsForFile(
      widget.file.path,
    );
    if (_sameAnnotations(_annotationsForFile, fresh)) return;
    setState(() {
      _annotationsForFile
        ..clear()
        ..addAll(fresh);
    });
    if (_controller.isReady) _controller.invalidate();
  }

  /// Cheap content equality for the "should I redraw?" check above. Compares
  /// identity, color, note, and rect count — enough to detect any mutation
  /// that would change how overlays render, without deep-comparing rects.
  bool _sameAnnotations(List<PdfAnnotation> a, List<PdfAnnotation> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final PdfAnnotation x = a[i];
      final PdfAnnotation y = b[i];
      if (x.id != y.id ||
          x.colorHex != y.colorHex ||
          x.note != y.note ||
          x.rects.length != y.rects.length) {
        return false;
      }
    }
    return true;
  }

  // =========================================================================
  // Text selection → floating Highlight toolbar
  // =========================================================================

  /// Called by pdfrx on EVERY selection change — the definitive signal that
  /// text selection is happening. It fires even when the PDF disallows
  /// copying, which is exactly why it's the driver for our toolbar instead
  /// of the built-in context menu (which pdfrx silently suppresses entirely
  /// when the file has copying disabled).
  ///
  /// TEMPORARY DEBUG: logs selection state synchronously so we can tell
  /// "callback never fires" apart from "callback fires but toolbar doesn't
  /// render".
  void _onSelectionChanged(PdfTextSelection selection) {
    if (!mounted) return;
    _lastSelectionRange = selection.textSelectionPointRange;
    _selectionCallbackTs = DateTime.now();
    final PdfTextSelectionRange? range = _lastSelectionRange;
    final String pages = range == null
        ? 'none'
        : '${range.start.text.pageNumber}'
              '..${range.end.text.pageNumber}';
    debugPrint(
      '[Selection] callback fired → '
      'hasSelectedText=${selection.hasSelectedText} '
      'copyAllowed=${selection.isCopyAllowed} '
      'isSelectingAll=${selection.isSelectingAllText} '
      'pages=$pages',
    );

    // Anchor the toolbar WITHOUT waiting for the next frame or an async text
    // lookup: the end-point's char rect is already cached (a selection can
    // only exist once the page text is loaded), so we compute the anchor and
    // setState inline. That is legal — pdfrx only fires this callback from
    // gesture/action handlers, never during its own build phase.
    if (range == null || !selection.hasSelectedText) {
      _hideSelectionToolbar();
      return;
    }

    final PdfTextSelectionPoint end = range.end;
    final PdfRect? endRect = _endCharRectOf(range);
    if (endRect == null) {
      // Rare fallback: the text of the page the selection ends on isn't
      // cached yet; recompute asynchronously once it loads.
      _refreshSelectionToolbar(selection);
      return;
    }
    _showSelectionToolbar(end.text.pageNumber, endRect);
  }

  /// Synchronously locate the rect (in PDF page coordinates) of the character
  /// at the END of the selection — the toolbar's anchor. Scans back over a
  /// few (occasionally zero-width) trailing characters.
  PdfRect? _endCharRectOf(PdfTextSelectionRange range) {
    final List<PdfRect> rects = range.end.text.charRects;
    if (rects.isEmpty) return null; // page text not loaded → async fallback
    int idx = range.end.index.clamp(0, rects.length - 1);
    for (int guard = 0; guard < 8 && idx > 0; guard++) {
      final PdfRect r = rects[idx];
      if (r.isNotEmpty) return r;
      idx--;
    }
    return rects[idx];
  }

  void _showSelectionToolbar(int endPage, PdfRect endRect) {
    if (_selectionToolbarVisible &&
        _selectionToolbarPage == endPage &&
        _selectionToolbarEndRect == endRect) {
      return; // already showing at the same anchor — skip rebuild churn
    }
    setState(() {
      _selectionToolbarVisible = true;
      _selectionToolbarPage = endPage;
      _selectionToolbarEndRect = endRect;
    });
    if (_controller.isReady) _controller.invalidate();
  }

  /// Recompute the toolbar's anchor from the SELECTED FRAGMENTS (async — the
  /// rects live in the PDF engine) and re-show it. Guarded by a generation
  /// counter so a stale lookup can't fight a newer selection. Only used as a
  /// fallback when the end page's cached text wasn't available synchronously.
  Future<void> _refreshSelectionToolbar(PdfTextSelection selection) async {
    final int seq = ++_selectionChangeSeq;
    final List<PdfPageTextRange> ranges = await selection
        .getSelectedTextRanges();
    if (!mounted || seq != _selectionChangeSeq) return;
    if (ranges.isEmpty) {
      _hideSelectionToolbar();
      return;
    }

    var totalLength = 0;
    PdfRect? endRect;
    var endPage = 0;
    for (final PdfPageTextRange range in ranges) {
      totalLength += range.text.length;
      endPage = range.pageNumber;
      endRect = null;
      for (final PdfTextFragmentBoundingRect fragment
          in range.enumerateFragmentBoundingRects()) {
        final PdfRect bounds = fragment.bounds;
        if (bounds.isEmpty) continue;
        endRect = bounds; // last non-empty fragment == selection end
      }
    }

    // TEMPORARY DEBUG: the details that determine whether the toolbar can be
    // rendered at all (empty rect on the end page ⇒ nothing to anchor to).
    debugPrint(
      '[Selection] details → textLen=$totalLength endPage=$endPage '
      'endRect=$endRect',
    );
    if (endRect == null) {
      _hideSelectionToolbar();
      return;
    }

    setState(() {
      _selectionToolbarVisible = true;
      _selectionToolbarPage = endPage;
      _selectionToolbarEndRect = endRect;
    });
    if (_controller.isReady) _controller.invalidate();
  }

  void _hideSelectionToolbar() {
    _selectionChangeSeq++;
    if (!_selectionToolbarVisible && _selectionToolbarEndRect == null) return;
    setState(() {
      _selectionToolbarVisible = false;
      _selectionToolbarPage = 0;
      _selectionToolbarEndRect = null;
    });
  }

  /// Open the color-picker sheet from the floating toolbar.
  void _showHighlightCreationSheetForToolbar(String colorHex) {
    if (!_controller.isReady) return;
    final PdfTextSelectionDelegate delegate = _controller.textSelectionDelegate;
    if (!delegate.hasSelectedText) return;
    _showHighlightCreationSheet(delegate, initialColorHex: colorHex);
  }

  /// The floating toolbar, anchored to the END of the current selection and
  /// clamped inside the page's overlay bounds (the overlays are laid out in
  /// page-local space and clipped to the page, so staying in-bounds keeps it
  /// fully visible). If there isn't room below the selection it flips above.
  Widget _buildSelectionToolbar(
    Rect endRectInPage,
    Size pageSize, {
    bool nightMode = false,
  }) {
    const double toolbarW = 224;
    const double toolbarH = 44;
    const double pad = 6;

    // TEMPORARY DEBUG: how long the toolbar took to reach this render pass
    // after the selection callback fired (delay-bug diagnostics).
    final DateTime? ts = _selectionCallbackTs;
    if (ts != null) {
      debugPrint(
        '[Toolbar] rendered → delayFromCallback='
        '${DateTime.now().difference(ts).inMilliseconds}ms '
        'anchor=${endRectInPage.topLeft}→${endRectInPage.bottomRight}',
      );
    }

    double maxLeft = pageSize.width - toolbarW - pad;
    if (maxLeft < pad) maxLeft = pad;
    double left = (endRectInPage.center.dx - toolbarW / 2).clamp(pad, maxLeft);

    double top = endRectInPage.bottom + 8;
    if (top + toolbarH > pageSize.height) {
      double maxTop = pageSize.height - toolbarH - pad;
      if (maxTop < pad) maxTop = pad;
      top = (endRectInPage.top - toolbarH - 8).clamp(pad, maxTop);
    }

    return Positioned(
      key: const Key('selection-highlight-toolbar'),
      left: left,
      top: top,
      // Hit-transparent: the toolbar must NOT swallow Flutter's own hit test
      // (pdfrx dispatches taps via its overlay hit tester, which only runs
      // after a tap reaches the InteractiveViewer's GestureDetector below this
      // Stack). Ignoring pointers here is identical to how interactive
      // annotations work — the image renders, taps pass through and land on
      // the registered PdfOverlayInteractionRegion bounds.
      child: IgnorePointer(
        // Pre-compensate with the exact inverse of the night filter so the
        // toolbar keeps its authored colors while the page (and everything
        // else) is night-rendered around it.
        child: nightMode
            ? NightMode.counterWrap(
                _SelectionToolbar(
                  onHighlight: _showHighlightCreationSheetForToolbar,
                ),
              )
            : _SelectionToolbar(
                onHighlight: _showHighlightCreationSheetForToolbar,
              ),
      ),
    );
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
      _applyZoom(next);
    }
  }

  void _zoomOut() {
    if (!_controller.isReady) return;
    final double current = _zoomNotifier.value;
    final double next = (current - 0.25).clamp(_minZoom, _maxZoom);
    if (next != current) {
      _applyZoom(next);
    }
  }

  /// Applies a new zoom level while keeping the DOCUMENT POINT currently at the
  /// center of the view unmoved, so the current page and scroll position are
  /// preserved and only the zoom changes.
  ///
  /// IMPORTANT: [PdfViewerController.setZoom]'s `position` argument is a
  /// DOCUMENT coordinate, not a view coordinate. Passing the view center
  /// (`viewW/2, viewH/2`) as that argument made pdfrx re-center the document
  /// at that point — for any multi-page document that point sits near the top,
  /// so the view snapped back to page 1. [zoomOnLocalPosition] interprets its
  /// argument in LOCAL (view) coordinates and internally converts it to the
  /// document point under it, which is the semantics we actually want here.
  void _applyZoom(double next) {
    // TEMPORARY DEBUG: log the controller's live page immediately before and
    // after the zoom settles, to confirm the page number no longer changes.
    debugPrint(
      '[Zoom] before page=${_controller.pageNumber} '
      'zoom=${_controller.currentZoom.toStringAsFixed(2)}',
    );
    final Offset viewCenter = Offset(
      _controller.viewSize.width / 2,
      _controller.viewSize.height / 2,
    );
    _controller
        .zoomOnLocalPosition(localPosition: viewCenter, newZoom: next)
        .then((_) {
          // Log once the 200ms zoom animation completes + the next frame applies.
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            debugPrint(
              '[Zoom] after  page=${_controller.pageNumber} '
              'zoom=${_controller.currentZoom.toStringAsFixed(2)}',
            );
          });
        });
    // _onControllerUpdate → _zoomNotifier.value will fire from the listener.
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
                hintStyle: TextStyle(
                  color: AppColors.colorOf(context, 'textMuted'),
                ),
                filled: true,
                fillColor: AppColors.colorOf(context, 'inputFill'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.colorOf(context, 'primary'),
                  ),
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Enter a page number';
                }
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
                style: TextStyle(
                  color: AppColors.colorOf(context, 'textSecondary'),
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
  // Highlight annotations
  // =========================================================================

  /// Show the color-picker sheet for creating a highlight from the current
  /// text selection, then persist it. Can be opened from the floating toolbar
  /// or the (desktop) context menu; [onDismiss] closes whichever popup invoked
  /// it first so the selection handles don't overlap the sheet.
  Future<void> _showHighlightCreationSheet(
    PdfTextSelectionDelegate delegate, {
    String initialColorHex = PdfAnnotation.defaultColorHex,
    VoidCallback? onDismiss,
  }) async {
    onDismiss?.call();
    final TextEditingController noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.colorOf(context, 'surface'),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        String selectedColor = initialColorHex;
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Highlight selection',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.colorOf(ctx, 'textPrimary'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AnnotationColorRow(
                    selectedColor: selectedColor,
                    onColorSelected: (color) =>
                        setSheetState(() => selectedColor = color),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.colorOf(ctx, 'textPrimary'),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Optional note…',
                      hintStyle: TextStyle(
                        color: AppColors.colorOf(ctx, 'textMuted'),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppColors.colorOf(ctx, 'inputFill'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.colorOf(ctx, 'textSecondary'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: () {
                          final String note = noteController.text;
                          Navigator.of(ctx).pop();
                          _createHighlight(delegate, selectedColor, note);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.colorOf(ctx, 'primary'),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Add highlight'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  /// Capture the current selection as highlight annotation(s), one per
  /// selected page range, and persist them through the annotations provider.
  ///
  /// Per-line/per-word rectangles come from pdfrx's fragment bounding boxes
  /// (already in PDF page coordinates), so highlights stay aligned no matter
  /// the zoom level or layout mode.
  Future<void> _createHighlight(
    PdfTextSelectionDelegate delegate,
    String colorHex,
    String note,
  ) async {
    if (!delegate.hasSelectedText) return;
    final List<PdfPageTextRange> ranges = await delegate
        .getSelectedTextRanges();
    if (!mounted) return;

    var created = 0;
    for (var i = 0; i < ranges.length; i++) {
      final PdfPageTextRange range = ranges[i];
      final List<AnnotationRect> rects = <AnnotationRect>[];
      for (final PdfTextFragmentBoundingRect frame
          in range.enumerateFragmentBoundingRects()) {
        final PdfRect b = frame.bounds;
        if (b.isEmpty || b.width <= 0 || b.height <= 0) continue;
        rects.add(
          AnnotationRect(x: b.left, y: b.top, width: b.width, height: b.height),
        );
      }
      if (rects.isEmpty) continue;
      created++;
      final PdfAnnotation annotation = PdfAnnotation(
        id: '${DateTime.now().microsecondsSinceEpoch}-$i',
        filePath: widget.file.path,
        pageNumber: range.pageNumber,
        rects: rects,
        colorHex: colorHex,
        createdAt: DateTime.now().toIso8601String(),
        textSnippet: _cleanTextSnippet(range.text),
        note: note.trim().isEmpty ? null : note.trim(),
      );
      await context.read<AnnotationsProvider>().addAnnotation(annotation);
      if (!mounted) return;
    }

    // Selection is consumed once highlighted.
    await delegate.clearTextSelection();

    if (kDebugMode) {
      debugPrint(
        '[PdfViewer] created $created highlight(s) on "${widget.file.name}" '
        'across ${ranges.length} selection range(s)',
      );
    }
  }

  /// Collapse any whitespace runs (including the newlines PDFium injects at
  /// line breaks) into single spaces so snippets render on one line.
  String _cleanTextSnippet(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Bottom sheet for an existing highlight: change color, edit/delete note,
  /// or remove the highlight entirely.
  Future<void> _showAnnotationActions(String annotationId) async {
    final PdfAnnotation? annotation = context.read<AnnotationsProvider>().byId(
      annotationId,
    );
    if (annotation == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.colorOf(context, 'surface'),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return _AnnotationActionsSheet(
          annotation: annotation,
          onColorSelected: (colorHex) {
            context.read<AnnotationsProvider>().updateAnnotationColor(
              annotationId,
              colorHex,
            );
          },
          onNoteSaved: (String? note) {
            context.read<AnnotationsProvider>().updateAnnotationNote(
              annotationId,
              note,
            );
          },
          onDelete: () async {
            final bool confirmed = await showConfirmDialog(
              ctx,
              title: 'Remove highlight?',
              message: 'This removes the highlight. The PDF file itself is not modified.',
              confirmLabel: 'Remove',
            );
            if (confirmed && mounted) {
              context.read<AnnotationsProvider>().removeAnnotation(
                annotationId,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            }
          },
        );
      },
    );
  }

  /// Annotations panel — flat list of every highlight in this file, with the
  /// captured text snippet and page number, tapping jumps to the page.
  /// Mirrors _showBookmarksPanel's structure.
  void _showAnnotationsPanel() {
    final List<PdfAnnotation> annotations =
        _annotationsProvider?.annotationsForFile(widget.file.path) ??
        const <PdfAnnotation>[];

    showModalBottomSheet<void>(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Annotations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.colorOf(context, 'textPrimary'),
                      ),
                    ),
                  ),
                ),
                if (annotations.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No highlights in this file',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.colorOf(context, 'textMuted'),
                        ),
                      ),
                    ),
                  )
                else
                  Divider(
                    height: 1,
                    color: AppColors.colorOf(context, 'border'),
                  ),
                if (annotations.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: annotations.length,
                      itemBuilder: (BuildContext ctx, int index) {
                        final PdfAnnotation annotation = annotations[index];
                        final String snippet =
                            annotation.textSnippet ?? annotation.note ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 6,
                            backgroundColor: annotation.color,
                          ),
                          title: Text(
                            snippet.isEmpty ? 'Highlight' : snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.colorOf(context, 'textPrimary'),
                            ),
                          ),
                          subtitle: Text(
                            'Page ${annotation.pageNumber}'
                            '${annotation.hasNote ? '  •  ${annotation.note}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.colorOf(context, 'textMuted'),
                            ),
                          ),
                          trailing: annotation.hasNote
                              ? Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 18,
                                  color: AppColors.colorOf(
                                    context,
                                    'textMuted',
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _controller.goToPage(
                              pageNumber: annotation.pageNumber,
                            );
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
    // Watch night mode so toggling immediately re-wraps the page canvas in the
    // night filter (and re-runs the page overlays via the rebuild below).
    final bool nightMode = context.watch<SettingsProvider>().isNightMode;
    return Scaffold(
      backgroundColor: AppColors.colorOf(context, 'background'),
      appBar: AppBar(
        backgroundColor: AppColors.colorOf(context, 'surface'),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: MediaQuery.sizeOf(context).width < 420 ? 0 : 16,
        title: _buildTopBar(context, nightMode: nightMode),
      ),

      body: Column(
        children: [
          // -- Search bar (only visible when _searchActive is true) --
          if (_searchActive) _buildSearchBar(),

          // -- PDF viewer (fills remaining space) --
          Expanded(
            child: RepaintBoundary(
              // Night mode wraps ALL page rendering in the soft warm
              // night filter (pages + pdfrx selection/search highlights).
              // Our own overlays are individually pre-compensated with the
              // filter's inverse in the page-overlays builder so annotation
              // colors survive unchanged.
              child: nightMode
                  ? NightMode.wrap(
                      PdfViewer.file(
                        widget.file.path,
                        key: ValueKey(widget.file.path),
                        controller: _controller,
                        initialPageNumber: _currentPage,
                        params: PdfViewerParams(
                          textSelectionParams: _textSelectionParams,
                          buildContextMenu: _buildSelectionContextMenu,
                          pageOverlaysBuilder: _pageOverlays,
                          margin: 0,
                          pageDropShadow: null,
                          layoutPages: _useSinglePageLayout
                              ? _pagedLayout
                              : null,
                          onViewSizeChanged: _onViewSizeChanged,
                          pagePaintCallbacks: [
                            if (_textSearcher != null)
                              _textSearcher!.pageTextMatchPaintCallback,
                          ],
                          onPageChanged: _onPageChanged,
                          onDocumentLoadFinished: _onDocLoadFinished,
                          onViewerReady: _onViewerReady,
                        ),
                      ),
                    )
                  : PdfViewer.file(
                      widget.file.path,
                      key: ValueKey(widget.file.path),
                      controller: _controller,
                      initialPageNumber: _currentPage,
                      params: PdfViewerParams(
                        textSelectionParams: _textSelectionParams,
                        buildContextMenu: _buildSelectionContextMenu,
                        pageOverlaysBuilder: _pageOverlays,
                        margin: 0,
                        pageDropShadow: null,
                        layoutPages: _useSinglePageLayout ? _pagedLayout : null,
                        onViewSizeChanged: _onViewSizeChanged,
                        pagePaintCallbacks: [
                          if (_textSearcher != null)
                            _textSearcher!.pageTextMatchPaintCallback,
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
  // Responsive top toolbar
  // =========================================================================

  /// Toggle the viewer's night mode. The provider persists it and notifies;
  /// our `build()` re-wraps the page canvas via `context.watch` on the same
  /// provider, so the night mode applies to the currently open file instantly.
  Future<void> _toggleNightMode() async {
    await context.read<SettingsProvider>().toggleNightMode();
  }

  /// Responsive top toolbar. The filename (`Expanded` + ellipsis) absorbs the
  /// leftover width, so trailing controls never get squeezed out — instead
  /// they tier down on narrow screens before anything collides or overflows:
  ///
  ///   ≥500 : search · night · zoom− · NN% · zoom+ · share · [N/N] · ⋮
  ///   420–499: same, minus Share (moved into the ⋮ menu)
  ///   <420 : minus Share and the zoom-% label (shown inert in the ⋮ menu);
  ///          icons drop to 40×48 glyph hits with 20px icons, the page badge
  ///          pad/font shrink; the back button and filename stay as-is.
  ///
  /// Every control keeps at least a 40×48dp touch target (48×48 on regular
  /// widths). "999 / 1000"-style badges fit by construction at every tier
  /// because the indicator is a compact pill with its own padding.
  Widget _buildTopBar(BuildContext context, {required bool nightMode}) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool compact = width < 420;
    final bool hideShare = width < 500;

    final Color iconColor = AppColors.colorOf(context, 'textSecondary');
    final Color accentColor = AppColors.colorOf(context, 'primary');
    final double iconSize = compact ? 20 : 22;
    final BoxConstraints tapConstraints = compact
        ? const BoxConstraints(minWidth: 40, minHeight: 48)
        : const BoxConstraints(minWidth: 48, minHeight: 48);

    // Standard icon button with a consistent (≥40×48) touch target.
    Widget iconButton(IconData icon, VoidCallback? onPressed, String tooltip) {
      return IconButton(
        icon: Icon(icon, size: iconSize, color: iconColor),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: tapConstraints,
      );
    }

    return Row(
      children: [
        // Filename takes ALL leftover width so controls never overflow —
        // it ellipsizes first, long before the row can collide.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              widget.file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
          ),
        ),

        // -- Night Mode quick toggle (always visible) --
        IconButton(
          icon: Icon(
            nightMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: iconSize,
            color: nightMode ? accentColor : iconColor,
          ),
          onPressed: _toggleNightMode,
          tooltip: nightMode ? 'Turn off night mode' : 'Turn on night mode',
          padding: EdgeInsets.zero,
          constraints: tapConstraints,
        ),

        // -- Search --
        iconButton(
          _searchActive ? Icons.close : Icons.search,
          _searchActive ? _closeSearch : _openSearch,
          'Search',
        ),

        // -- Zoom out --
        iconButton(Icons.remove_circle_outline, _zoomOut, 'Zoom out'),

        // -- Zoom level label (only this widget rebuilds on zoom change).
        //    Hidden on very narrow screens (see compaction rules above). --
        if (!compact)
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
        iconButton(Icons.add_circle_outline, _zoomIn, 'Zoom in'),

        // -- Share (moved to the ⋮ menu on narrow screens) --
        if (!hideShare)
          iconButton(Icons.share_outlined, _shareFile, 'Share file'),

        // -- Page indicator badge --
        Center(
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.colorOf(context, 'inputFill'),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _totalPages > 0
                  ? '$_currentPage / $_totalPages'
                  : '$_currentPage',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: AppColors.colorOf(context, 'textSecondary'),
              ),
            ),
          ),
        ),

        // -- Overflow menu: dynamic entries + jump-to-page & bookmarks --
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: iconSize, color: iconColor),
          color: AppColors.colorOf(context, 'surface'),
          padding: EdgeInsets.zero,
          constraints: tapConstraints,
          tooltip: 'More options',
          onSelected: (String value) {
            switch (value) {
              case 'search':
                if (_searchActive) {
                  _closeSearch();
                } else {
                  _openSearch();
                }
              case 'share':
                _shareFile();
              case 'jump':
                _showJumpToPageDialog();
              case 'bookmarks':
                _showBookmarksPanel();
              case 'annotations':
                _showAnnotationsPanel();
            }
          },
          itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
            // Live zoom readout shown only when the bar dropped the label.
            if (compact)
              PopupMenuItem<String>(
                value: 'zoom-readout',
                enabled: false,
                child: Row(
                  children: [
                    Icon(
                      Icons.zoom_out_map,
                      size: 20,
                      color: AppColors.colorOf(context, 'textMuted'),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Zoom: ${(_zoomNotifier.value * 100).round()}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.colorOf(context, 'textMuted'),
                      ),
                    ),
                  ],
                ),
              ),
            if (hideShare)
              PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: AppColors.colorOf(context, 'textSecondary'),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Share file',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.colorOf(context, 'textPrimary'),
                      ),
                    ),
                  ],
                ),
              ),
            PopupMenuItem<String>(
              value: 'jump',
              child: Row(
                children: [
                  Icon(
                    Icons.numbers,
                    size: 20,
                    color: AppColors.colorOf(context, 'textSecondary'),
                  ),
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
                  Icon(
                    Icons.bookmark_outline,
                    size: 20,
                    color: AppColors.colorOf(context, 'textSecondary'),
                  ),
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
            PopupMenuItem<String>(
              value: 'annotations',
              child: Row(
                children: [
                  Icon(
                    Icons.highlight_alt,
                    size: 20,
                    color: AppColors.colorOf(context, 'textSecondary'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Annotations',
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
    final String counterText = (total > 0)
        ? '$current / $total'
        : (_searchInputController.text.isNotEmpty ? 'No results' : '');

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
                hintStyle: TextStyle(
                  color: AppColors.colorOf(context, 'textMuted'),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppColors.colorOf(context, 'inputFill'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.colorOf(context, 'primary'),
                  ),
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

// =========================================================================
// Shared annotation widgets
// =========================================================================

/// Horizontal row of highlight color swatches from [PdfAnnotation.colorPalette].
///
/// Basis for both the highlight creation sheet and the edit-highlight sheet:
/// taps report the chosen hex, the selected palette entry shows a check mark.
class _AnnotationColorRow extends StatelessWidget {
  const _AnnotationColorRow({
    required this.selectedColor,
    required this.onColorSelected,
  });

  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final String hex in PdfAnnotation.colorPalette)
          GestureDetector(
            key: ValueKey('annotation-color-$hex'),
            onTap: () => onColorSelected(hex),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PdfAnnotation.colorFromHex(hex),
                shape: BoxShape.circle,
                border: selectedColor == hex
                    ? Border.all(
                        color: AppColors.colorOf(context, 'textSecondary'),
                        width: 3,
                      )
                    : Border.all(
                        color: AppColors.colorOf(context, 'border'),
                        width: 1,
                      ),
              ),
              child: selectedColor == hex
                  ? const Icon(
                      Icons.check,
                      color: Color(0x8C000000), // visible on all pastels
                      size: 22,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Bottom-sheet body for managing a single existing highlight: change its
/// color, add/edit its note, or delete it. Stateful so the live note and
/// selected color display update without tearing down the sheet.
class _AnnotationActionsSheet extends StatefulWidget {
  const _AnnotationActionsSheet({
    required this.annotation,
    required this.onColorSelected,
    required this.onNoteSaved,
    required this.onDelete,
  });

  final PdfAnnotation annotation;
  final ValueChanged<String> onColorSelected;
  final ValueChanged<String?> onNoteSaved;
  final VoidCallback onDelete;

  @override
  State<_AnnotationActionsSheet> createState() =>
      _AnnotationActionsSheetState();
}

class _AnnotationActionsSheetState extends State<_AnnotationActionsSheet> {
  late String _selectedColor;
  late String? _note;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.annotation.colorHex;
    _note = widget.annotation.note;
  }

  Future<void> _editNote() async {
    final TextEditingController controller = TextEditingController(text: _note);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AppColors.colorOf(ctx, 'surface'),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Highlight note',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.colorOf(ctx, 'textPrimary'),
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.colorOf(ctx, 'textPrimary'),
            ),
            decoration: InputDecoration(
              hintText: 'Write a short note…',
              hintStyle: TextStyle(color: AppColors.colorOf(ctx, 'textMuted')),
              filled: true,
              fillColor: AppColors.colorOf(ctx, 'inputFill'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.colorOf(ctx, 'textSecondary'),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(
                'Save',
                style: TextStyle(
                  color: AppColors.colorOf(ctx, 'primary'),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null || !mounted) return;
    final String? trimmed = result.trim().isEmpty ? null : result.trim();
    setState(() => _note = trimmed);
    widget.onNoteSaved(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final PdfAnnotation annotation = widget.annotation;
    final String snippet =
        annotation.textSnippet ?? annotation.note ?? 'Highlight';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: annotation.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.colorOf(context, 'textPrimary'),
                  ),
                ),
              ),
              Text(
                'Page ${annotation.pageNumber}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.colorOf(context, 'textMuted'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Color',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.colorOf(context, 'textSecondary'),
            ),
          ),
          const SizedBox(height: 8),
          _AnnotationColorRow(
            selectedColor: _selectedColor,
            onColorSelected: (hex) {
              setState(() => _selectedColor = hex);
              widget.onColorSelected(hex);
            },
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: AppColors.colorOf(context, 'border')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.sticky_note_2_outlined,
              size: 20,
              color: _note != null
                  ? AppColors.colorOf(context, 'primary')
                  : AppColors.colorOf(context, 'textMuted'),
            ),
            title: Text(
              _note == null ? 'Add note' : 'Edit note',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
            subtitle: _note != null
                ? Text(
                    _note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.colorOf(context, 'textMuted'),
                    ),
                  )
                : null,
            onTap: _editNote,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.colorOf(context, 'brandRed'),
            ),
            title: Text(
              'Remove highlight',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.colorOf(context, 'brandRed'),
              ),
            ),
            onTap: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

/// The floating "Highlight" toolbar shown near an active text selection.
/// A compact pill: one tappable color swatch per palette color, plus the
/// app's primary highlight action. Either opens the color+note creation
/// sheet, preselected with the tapped (or default) color.
///
/// NOTE: every action is its own [PdfOverlayInteractionRegion] whose child is
/// pure VISUALS (the region wraps children in IgnorePointer). That is how
/// taps here avoid clearing the selection / starting a pan underneath —
/// pdfrx's overlay hit-tester intercepts the tap FIRST and, because the
/// callback returns true, the viewer's own gesture handling never runs.
class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({required this.onHighlight});

  final ValueChanged<String> onHighlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.colorOf(context, 'surface'),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final String hex in PdfAnnotation.colorPalette)
              PdfOverlayInteractionRegion(
                key: ValueKey('selection-toolbar-color-$hex'),
                onTap: (_) {
                  debugPrint('[Toolbar] region tap → color $hex');
                  onHighlight(hex);
                  return true;
                },
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: PdfAnnotation.colorFromHex(hex),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Container(
              width: 1,
              height: 20,
              color: AppColors.colorOf(context, 'border'),
            ),
            const SizedBox(width: 2),
            PdfOverlayInteractionRegion(
              key: const Key('selection-toolbar-highlight'),
              onTap: (_) {
                debugPrint('[Toolbar] region tap → Highlight default');
                onHighlight(PdfAnnotation.defaultColorHex);
                return true;
              },
              child: Container(
                width: 78,
                height: 34,
                alignment: Alignment.center,
                child: Text(
                  'Highlight',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorOf(context, 'primary'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
