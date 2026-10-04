import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

import '../theme/app_tokens.dart';
import '../theme/context_extension.dart';

/// Width, in pixels, that a page is rasterized at before it is shown.
///
/// Deliberately low: a thumbnail is 48 logical pixels wide, so anything past
/// ~2x that is invisible pixels being pushed through the GPU. The raster keeps
/// the page's own aspect ratio, so no page is ever squashed.
const double _renderWidthPx = 96;

/// How many rasters are kept in memory at once.
///
/// The cache stores raw BGRA bytes rather than decoded [ui.Image]s on purpose:
/// decoded images are GPU resources with a disposal contract, and a cached one
/// can outlive the widget that painted it. Bytes have no such hazard, so
/// evicting an entry can never blow up a frame. A 96x128 raster is ~48 KB, so
/// the cap is only a few megabytes.
const int _cacheCapacity = 64;

/// A first-page thumbnail of a PDF, with a themed icon fallback.
///
/// The page is rendered by pdfrx at [_renderWidthPx] and shared between every
/// thumbnail that points at the same file — including the ones rebuilt by a
/// scroll, a rebuild or a theme change — so the document is parsed and
/// rasterized at most once per file revision.
///
/// Until the raster arrives, and whenever rendering fails (a missing file, an
/// encrypted document, an undecodable page), [fallback] is painted instead, so
/// the box is never empty.
class PdfPageThumbnail extends StatefulWidget {
  final String path;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Widget? fallback;

  const PdfPageThumbnail({
    super.key,
    required this.path,
    this.width = 48,
    this.height = 64,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.fallback,
  });

  @override
  State<PdfPageThumbnail> createState() => _PdfPageThumbnailState();
}

class _PdfPageThumbnailState extends State<PdfPageThumbnail> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(PdfPageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path == widget.path) return;
    // The row now points at a different file: drop the old page before asking
    // for the new one, or the row briefly shows the previous document.
    _retire(_image);
    _image = null;
    unawaited(_load());
  }

  @override
  void dispose() {
    _retire(_image);
    super.dispose();
  }

  Future<void> _load() async {
    final path = widget.path;
    final raster = await _PageRasterCache.rasterize(path);
    if (raster == null) {
      // Failure: stay on the fallback and do not retry — a file that cannot be
      // rasterized will not rasterize on the next rebuild either.
      return;
    }

    final image = await PdfImage.createFromBgraData(
      raster.pixels,
      width: raster.width,
      height: raster.height,
    ).createImage();

    // The row may have been recycled onto another file, or unmounted, while the
    // page was rendering: this image then belongs to a row that is gone.
    if (!mounted || widget.path != path) {
      _retire(image);
      return;
    }

    _retire(_image);
    setState(() => _image = image);
  }

  /// Frees a decoded page once the frame that last painted it is done.
  ///
  /// A [ui.Image] that is disposed while a layer still references it makes the
  /// raster task throw, so disposal waits for the end of the frame.
  static void _retire(ui.Image? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final content = image != null
        ? RawImage(image: image, fit: BoxFit.contain)
        : (widget.fallback ?? _IconFallback());

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: widget.borderRadius,
            side: BorderSide(
              color: context.appColors.border,
              width: AppTokens.hairline,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: content,
        ),
      ),
    );
  }
}

/// The themed stand-in shown while the page renders, or if it cannot.
///
/// Same language as the old flat icon box — a soft primary tint behind the
/// accent-coloured glyph — so a failed render looks like the rest of the list
/// rather than like a hole in it.
class _IconFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ext = context.appColors;

    return ColoredBox(
      color: ext.primaryContainer,
      child: Center(
        child: Icon(
          Icons.description_rounded,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// One rendered page, still in pdfrx's BGRA layout.
class _PageRaster {
  final Uint8List pixels;
  final int width;
  final int height;

  const _PageRaster(this.pixels, this.width, this.height);
}

/// Renders page 1 of a file once per revision and shares the result.
///
/// Two maps back this: [_entries] is the LRU of finished rasters, and
/// [_inFlight] collapses concurrent requests for the same file so a list that
/// builds ten rows at once parses the document once instead of ten times.
abstract final class _PageRasterCache {
  static final Map<String, _PageRaster> _entries = <String, _PageRaster>{};
  static final Map<String, Future<_PageRaster?>> _inFlight =
      <String, Future<_PageRaster?>>{};

  static Future<_PageRaster?> rasterize(String path) {
    final key = _key(path);
    final hit = _entries[key];
    if (hit != null) {
      _entries.remove(key);
      _entries[key] = hit;
      return Future<_PageRaster?>.value(hit);
    }

    return _inFlight[key] ??= _render(path, key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  static Future<_PageRaster?> _render(String path, String key) async {
    PdfDocument? document;
    PdfImage? rendered;
    try {
      await pdfrxFlutterInitialize();
      document = await PdfDocument.openFile(path);
      if (document.pages.isEmpty) return null;

      final page = document.pages.first;
      if (page.width <= 0 || page.height <= 0) return null;

      rendered = await page.render(
        fullWidth: _renderWidthPx,
        fullHeight: _renderWidthPx * (page.height / page.width),
      );
      if (rendered == null || rendered.width <= 0 || rendered.height <= 0) {
        return null;
      }

      // Copied, not aliased: `pixels` belongs to the PdfImage and is released
      // with it in the `finally` below.
      final raster = _PageRaster(
        Uint8List.fromList(rendered.pixels),
        rendered.width,
        rendered.height,
      );

      _entries.remove(key);
      _entries[key] = raster;
      while (_entries.length > _cacheCapacity) {
        _entries.remove(_entries.keys.first);
      }
      return raster;
    } catch (_) {
      // Missing, locked, encrypted or otherwise undecodable — every one of
      // these is a reason to show the fallback, not to throw at a list row.
      return null;
    } finally {
      rendered?.dispose();
      await document?.dispose();
    }
  }

  /// Key on the file's revision, not just its path: re-scanning, re-splitting
  /// or re-downloading overwrites a file in place, and the old page must not
  /// survive it.
  static String _key(String path) {
    try {
      final stat = File(path).statSync();
      return '$path|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
    } catch (_) {
      return path;
    }
  }
}