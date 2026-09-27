import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:xpdf/providers/settings_provider.dart';

/// Regression guard for the "Looking up a deactivated widget's ancestor is
/// unsafe" crash that broke "Remember last page".
///
/// Before the fix, `_PdfViewerScreenState.dispose()` called
/// `context.read<SettingsProvider>()` / `context.read<RecentFilesProvider>()`
/// directly. dispose() runs while the element is already deactivated, so that
/// ancestor lookup throws and aborts the whole dispose body — silently
/// killing the page-position save. The fix caches the provider handles in
/// initState (context is valid there) and reuses them on the way out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child) => MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => SettingsProvider())],
    child: MaterialApp(home: child),
  );

  testWidgets('pre-fix pattern: context.read<>() in dispose() throws '
      '"deactivated widget\'s ancestor is unsafe"', (tester) async {
    late StateSetter setStateHost;
    bool showChild = true;

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setStateHost = setState;
            return Column(
              children: [
                if (showChild) const _BrokenDisposeView(),
                const SizedBox(),
              ],
            );
          },
        ),
      ),
    );

    // Unmount the child — this calls its dispose() while it is deactivated.
    setStateHost(() => showChild = false);
    await tester.pump();

    final Object? error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(
      error.toString(),
      contains("Looking up a deactivated widget's ancestor is unsafe"),
    );
  });

  testWidgets('fixed pattern: cached provider handle in dispose() unmounts '
      'cleanly', (tester) async {
    late StateSetter setStateHost;
    bool showChild = true;

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setStateHost = setState;
            return Column(
              children: [
                if (showChild) const _FixedDisposeView(),
                const SizedBox(),
              ],
            );
          },
        ),
      ),
    );

    setStateHost(() => showChild = false);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

/// Simulates the PRE-fix viewer dispose(): calls `context.read` during
/// teardown. Mirror of the old
/// `_PdfViewerScreenState.dispose()` line:
///
/// ```dart
/// final bool liveRemember = context.read<SettingsProvider>().rememberLastPage;
/// ```
class _BrokenDisposeView extends StatefulWidget {
  const _BrokenDisposeView();

  @override
  State<_BrokenDisposeView> createState() => _BrokenDisposeViewState();
}

class _BrokenDisposeViewState extends State<_BrokenDisposeView> {
  @override
  void dispose() {
    // The pre-fix line. Throws during route teardown.
    context.read<SettingsProvider>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Simulates the FIXED viewer dispose(): the provider handle is captured in
/// initState and reused in dispose(), so teardown never touches context.
/// Mirror of `_PdfViewerScreenState` after the fix.
class _FixedDisposeView extends StatefulWidget {
  const _FixedDisposeView();

  @override
  State<_FixedDisposeView> createState() => _FixedDisposeViewState();
}

class _FixedDisposeViewState extends State<_FixedDisposeView> {
  SettingsProvider? _settingsProvider;

  @override
  void initState() {
    super.initState();
    // Captured now (context is valid in initState) for use at dispose time.
    _settingsProvider = context.read<SettingsProvider>();
  }

  @override
  void dispose() {
    // Cached handle — NO context lookup during teardown.
    _settingsProvider?.rememberLastPage;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}