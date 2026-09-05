import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/recent_file.dart';
import '../providers/recent_files_provider.dart';
import '../screens/pdf_viewer_screen.dart';

/// Root-level listener that catches PDFs opened through Android's
/// "Open with" dialog (ACTION_VIEW on `application/pdf`) and routes them
/// into the in-app PDF viewer.
///
/// Two delivery paths are covered:
///  * cold start — the app is launched by the intent; the plugin caches it
///    and [ReceiveSharingIntent.getInitialMedia] returns it once;
///  * warm start — the app is already running and a new intent arrives,
///    delivered through the [ReceiveSharingIntent.getMediaStream] stream.
///
/// The plugin already resolves `content://` URIs into a real local cache file,
/// so the viewer can open it directly. We still copy that file into the app
/// documents directory so the recent-list entry survives system cache
/// cleanup, matching how downloaded/scanned PDFs are persisted.
class OpenWithListener extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const OpenWithListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  State<OpenWithListener> createState() => _OpenWithListenerState();
}

class _OpenWithListenerState extends State<OpenWithListener> {
  late final RecentFilesProvider _recentFiles;
  StreamSubscription<List<SharedMediaFile>>? _mediaSub;
  String? _lastHandledPath;

  @override
  void initState() {
    super.initState();
    _recentFiles = context.read<RecentFilesProvider>();

    // Cold start: the launch intent that brought the app into existence.
    // Handled first so its file is the one opened on the initial screen.
    _handleInitialMedia();

    // Warm start: intents delivered while the app is already in memory.
    _mediaSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          _handleSharedFiles,
          onError: (Object error) =>
              debugPrint('[OpenWith] media stream error: $error'),
        );
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }

  /// The listener is non-visual — it just wraps the app's root screen and
  /// never needs a rebuild of its own.
  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _handleInitialMedia() async {
    try {
      final media = await ReceiveSharingIntent.instance.getInitialMedia();
      await _handleSharedFiles(media);
      // Tell the plugin the initial intent is consumed so it is never
      // re-delivered on a later re-subscription.
      await ReceiveSharingIntent.instance.reset();
    } catch (error) {
      debugPrint('[OpenWith] initial media error: $error');
    }
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    final pdfs = files.where(_isPdf).toList();
    if (pdfs.isEmpty) return;

    // The recent list must be hydrated before we inject a new entry —
    // otherwise HomeScreen's pending loadFiles() could overwrite it.
    if (!_recentFiles.isLoaded) {
      await _recentFiles.loadFiles();
    }

    RecentFile? toOpen;
    for (final shared in pdfs) {
      try {
        final localPath = await _copyToAppStorage(shared);
        if (localPath == null || localPath == _lastHandledPath) continue;
        _lastHandledPath = localPath;

        final recent = await _recentFiles.addLocalFile(
          path: localPath,
          name: _displayName(shared),
          size: await File(localPath).length(),
        );
        toOpen ??= recent;
      } catch (error) {
        debugPrint('[OpenWith] failed to open shared PDF: $error');
      }
    }

    // Push the viewer for the first successfully imported PDF.
    final target = toOpen;
    if (target != null) {
      widget.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => PdfViewerScreen(file: target)),
      );
    }
  }

  /// True when the shared entry is a PDF (checked by mime type or extension).
  static bool _isPdf(SharedMediaFile file) {
    final mime = (file.mimeType ?? '').toLowerCase();
    final path = file.path.toLowerCase();
    return mime == 'application/pdf' ||
        mime.contains('pdf') ||
        path.endsWith('.pdf');
  }

  /// Copy the plugin-resolved local file into persistent app storage.
  ///
  /// The plugin caches `content://` URIs into a real file path, so [shared]
  /// is almost always already local. We copy it into the app documents
  /// directory with a unique name so the viewer always has a stable real path
  /// and recent entries survive cache cleanup. Returns the new path, or `null`
  /// if only a bare `content://` URI is available (should never happen).
  Future<String?> _copyToAppStorage(SharedMediaFile shared) async {
    final source = shared.path;
    if (source.isEmpty || source.startsWith('content://')) return null;

    final dir = await getApplicationDocumentsDirectory();
    final name = _displayName(shared);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final target = '${dir.path}/shared_${stamp}_$name';

    await File(source).copy(target);
    return target;
  }

  /// A safe `<name>.pdf` display name derived from the shared file's name.
  static String _displayName(SharedMediaFile shared) {
    var name = shared.path.split('/').last.trim();
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
    if (!name.toLowerCase().endsWith('.pdf')) name = '$name.pdf';
    if (name.isEmpty || name == '.pdf') {
      name = 'shared_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
    return name;
  }
}