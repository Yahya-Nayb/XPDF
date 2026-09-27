import 'package:flutter_test/flutter_test.dart';

/// Pumps a bounded window of frames.
///
/// The home screen's "Add document" FAB runs a looping gradient shimmer, so a
/// tree containing it never reaches an idle frame and `pumpAndSettle` always
/// times out. Tests that pump [HomeScreen] only need the transient animations
/// to finish — the splash fade, the bottom-nav cross-fade, theme tweening — so
/// they advance a fixed window instead of waiting for quiescence.
Future<void> pumpUi(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
