import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xpdf/main.dart';
import 'package:xpdf/providers/settings_provider.dart';
import 'package:xpdf/providers/theme_provider.dart';
import 'package:xpdf/widgets/pdf_grid_card.dart';

import 'pump_ui.dart';

/// The FAB's shimmer period, mirrored from the widget as a literal so a change
/// to the animation cadence fails here first.
const Duration kShimmerPeriod = Duration(seconds: 5);

/// Tolerance for the seamlessness check. `cos(2 * pi)` lands a few ULPs off
/// exactly 1.0, so one period later the axis differs by ~1e-16 — far below a
/// pixel, but enough to fail a bare `==`.
const double kAxisEpsilon = 1e-6;

final fab = find.byTooltip('Add document');

LinearGradient _gradient(WidgetTester tester) {
  final ink = tester.widget<Ink>(
    find.descendant(of: fab, matching: find.byType(Ink)),
  );
  return (ink.decoration as BoxDecoration).gradient! as LinearGradient;
}

double _axisX(LinearGradient g) => (g.begin as Alignment).x;

Future<void> _pumpHome(WidgetTester tester, {bool darkTheme = true}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final entries = List.generate(
    24,
    (i) =>
        '{"path":"/docs/f$i.pdf","name":"Document $i.pdf",'
        '"size":1024,"lastOpened":"2026-09-0${(i % 9) + 1}T10:00:00.000",'
        '"lastPage":1,"isFavorite":false,"folderId":null}',
  );
  SharedPreferences.setMockInitialValues({
    'recent_files': '[${entries.join(',')}]',
    'sort_mode': 'name_asc',
    'dark_mode': darkTheme,
  });
  final settings = SettingsProvider();
  await settings.loadSettings();
  // ThemeProvider defaults to dark; it only honours the stored preference once
  // it has loaded, so the FAB resolves the right stops per theme.
  final theme = ThemeProvider();
  await theme.loadTheme();

  await tester.pumpWidget(
    XpdfApp(themeProvider: theme, settingsProvider: settings),
  );
  // Clear the splash, then let the transient animations finish.
  await tester.pump(const Duration(milliseconds: 2500));
  await pumpUi(tester);
}

void main() {
  testWidgets('gradient axis drifts over time while the FAB stays put', (
    tester,
  ) async {
    await _pumpHome(tester);

    final origin = tester.getTopLeft(fab);
    final start = _gradient(tester);

    // A quarter period in, the ramp has visibly moved.
    await tester.pump(kShimmerPeriod ~/ 4);
    final quarter = _gradient(tester);

    expect(_axisX(quarter), isNot(closeTo(_axisX(start), kAxisEpsilon)));

    // The circle itself never moves, resizes or re-lays out.
    expect(tester.getTopLeft(fab), origin);
    expect(tester.getSize(fab), const Size(56, 56));
  });

  testWidgets('the loop is seamless: one period returns to the start', (
    tester,
  ) async {
    await _pumpHome(tester);

    final start = _gradient(tester);

    // A full period later the phase, and so the axis, must be back where it
    // began; otherwise the loop visibly jumps.
    await tester.pump(kShimmerPeriod);
    final afterOnePeriod = _gradient(tester);

    expect(_axisX(afterOnePeriod), closeTo(_axisX(start), kAxisEpsilon));
    expect(
      (afterOnePeriod.end as Alignment).y,
      closeTo((start.end as Alignment).y, kAxisEpsilon),
    );
  });

  testWidgets('shimmer only moves the axis; the palette never changes', (
    tester,
  ) async {
    await _pumpHome(tester);

    final start = _gradient(tester);
    await tester.pump(const Duration(milliseconds: 1370));
    final later = _gradient(tester);

    // Same four brand colours throughout, in the same order...
    expect(later.colors, start.colors);
    expect(later.colors.length, 4);
    // ...and no new colour stops introduced.
    expect(later.stops, start.stops);

    // The ramp is translated, not rotated or rescaled: both ends move by the
    // same amount, and only a small amount.
    final beginShift = _axisX(later) - _axisX(start);
    final endShift = (later.end as Alignment).x - (start.end as Alignment).x;
    expect(beginShift, closeTo(endShift, kAxisEpsilon));
    // Peak-to-peak the ramp travels 2 * the widget's 0.16 drift, so no two
    // phases can be further apart than that.
    expect(beginShift.abs(), lessThanOrEqualTo(2 * 0.16 + kAxisEpsilon));
    // ...and it is never a whole ramp width, which would be a colour swap.
    expect(beginShift.abs(), lessThan(2 * 0.16));
  });

  testWidgets('both themes animate and keep the brand palette', (tester) async {
    // The gradient resolves from the ambient brightness, so the FAB must pick
    // up the right stop set in each theme and animate in both.
    const expected = {
      Brightness.dark: [
        Color(0xFFFF4D5E),
        Color(0xFFFFA94D),
        Color(0xFFC6469C),
        Color(0xFF4D9FFF),
      ],
      Brightness.light: [
        Color(0xFFFF4759),
        Color(0xFFD97000),
        Color(0xFFC6469C),
        Color(0xFF2A8CFF),
      ],
    };

    for (final entry in expected.entries) {
      await _pumpHome(tester, darkTheme: entry.key == Brightness.dark);

      final start = _gradient(tester);
      await tester.pump(const Duration(milliseconds: 1250));
      final later = _gradient(tester);

      expect(
        start.colors,
        entry.value,
        reason: 'wrong brand stops for ${entry.key}',
      );
      // Animated...
      expect(
        _axisX(later),
        isNot(closeTo(_axisX(start), kAxisEpsilon)),
        reason: 'not animating in ${entry.key}',
      );
      // ...without altering them.
      expect(later.colors, entry.value, reason: '${entry.key}');
    }
  });

  testWidgets('the ripple target and glyph are not rebuilt per frame', (
    tester,
  ) async {
    await _pumpHome(tester);

    final iconBefore = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
    final wellBefore = tester.widget<InkWell>(
      find.descendant(of: fab, matching: find.byType(InkWell)),
    );

    // Advance a dozen frames of shimmer.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Identical widget instances, which is only possible if the AnimatedBuilder
    // passed them through as its `child`: the per-frame rebuild touches the
    // gradient layer and nothing else.
    expect(
      identical(
        tester.widget<Icon>(find.byIcon(Icons.add_rounded)),
        iconBefore,
      ),
      isTrue,
    );
    expect(
      identical(
        tester.widget<InkWell>(
          find.descendant(of: fab, matching: find.byType(InkWell)),
        ),
        wellBefore,
      ),
      isTrue,
    );
  });

  testWidgets('the controller stops when the FAB leaves the screen', (
    tester,
  ) async {
    await _pumpHome(tester);

    // While the FAB is up, its ticker is live and keeps requesting frames.
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    // Switching tab unmounts the FAB mid-animation. The controller must be
    // disposed with it — if it were not, `flutter_test` fails this test with
    // "was disposed with an active Ticker", which is the leak this guards.
    await tester.tap(find.byIcon(Icons.folder_rounded));
    await pumpUi(tester);
    expect(fab, findsNothing);

    // The gradient really is frozen now, not merely repainting offscreen.
    await tester.pump(kShimmerPeriod);
    expect(fab, findsNothing);
  });

  testWidgets('scrolling the recents behind the animated FAB stays smooth', (
    tester,
  ) async {
    await _pumpHome(tester);

    final fabBefore = tester.getTopLeft(fab);
    final listBefore = tester.getTopLeft(find.byType(PdfGridCard).first);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    // One frame mid-scroll, with the shimmer also mid-sweep.
    await tester.pump(const Duration(milliseconds: 32));

    // The list moved; the FAB did not.
    expect(
      tester.getTopLeft(find.byType(PdfGridCard).first),
      isNot(listBefore),
    );
    expect(tester.getTopLeft(fab), fabBefore);
    expect(fab, findsOneWidget);
  });
}
