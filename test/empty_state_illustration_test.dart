import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xpdf/main.dart';
import 'package:xpdf/providers/recent_files_provider.dart';
import 'package:xpdf/providers/settings_provider.dart';
import 'package:xpdf/providers/theme_provider.dart';
import 'package:xpdf/screens/home_screen.dart';
import 'package:xpdf/theme/brand_gradient.dart';
import 'package:xpdf/widgets/empty_state.dart';
import 'package:xpdf/widgets/floating_papers.dart';
import 'package:xpdf/widgets/pdf_grid_card.dart';

import 'pump_ui.dart';

/// The illustration's float period, mirrored from the widget as a literal so a
/// change to the cadence fails here first.
const Duration kFloatPeriod = Duration(milliseconds: 3600);

/// The smallest peak-to-peak gap between two sheets, in logical pixels, that
/// still reads as a loose stack rather than four sheets moving in lockstep.
///
/// The widget spaces its phases 1.1 rad apart with travels between 6 and 8, so
/// the gap never drops below ~6.5px anywhere in the cycle. The floor sits well
/// under that on purpose: it guards the property, not the exact number, and
/// bunching the phases back together is what it catches.
const double kPhaseSpreadFloor = 4;

/// Tolerance for the seamlessness check — `cos(2 * pi)` lands a few ULPs off
/// exactly 1.0.
const double kEpsilon = 1e-6;

final illustration = find.byType(FloatingPapers);
final emptyState = find.byType(EmptyState);

/// The four sheets, back to front. A [Transform.translate] is a pure
/// translation matrix; the interleaved [Transform.rotate] widgets are not, so
/// this picks out exactly one matrix per sheet without depending on tree order.
bool _isTranslation(Matrix4 m) =>
    m.storage[0] == 1.0 &&
    m.storage[5] == 1.0 &&
    m.storage[10] == 1.0 &&
    m.storage[1] == 0.0;

/// Each sheet's live vertical offset, in tree order.
List<double> drifts(WidgetTester tester) => tester
    .widgetList<Transform>(
      find.descendant(of: illustration, matching: find.byType(Transform)),
    )
    .where((t) => _isTranslation(t.transform))
    .map((t) => t.transform.storage[13])
    .toList();

/// Each sheet's live tilt, in radians, read back off its rotation matrix.
List<double> sheetAngles(WidgetTester tester) => tester
    .widgetList<Transform>(
      find.descendant(of: illustration, matching: find.byType(Transform)),
    )
    .where((t) => !_isTranslation(t.transform))
    .map((t) => math.atan2(t.transform.storage[1], t.transform.storage[0]))
    .toList();

/// The gradient painted on each sheet, back to front. The hero carries the
/// whole brand ramp; the three behind it are two-stop slices of it.
List<LinearGradient> sheetGradients(WidgetTester tester) => tester
    .widgetList<Container>(
      find.descendant(of: illustration, matching: find.byType(Container)),
    )
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.gradient)
    .whereType<LinearGradient>()
    .toList();

/// Each sheet's decoration, back to front.
List<BoxDecoration> sheetDecorations(WidgetTester tester) => tester
    .widgetList<Container>(
      find.descendant(of: illustration, matching: find.byType(Container)),
    )
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.gradient != null)
    .toList();

/// The hero sheet's gradient — the only one spanning the full ramp.
LinearGradient heroGradient(WidgetTester tester) => sheetGradients(tester).last;

Future<void> _pumpEmptyHome(
  WidgetTester tester, {
  bool darkTheme = true,
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // An empty recents list is what puts the empty state on screen at all.
  SharedPreferences.setMockInitialValues({
    'recent_files': '[]',
    'sort_mode': 'recent',
    'dark_mode': darkTheme,
  });
  final settings = SettingsProvider();
  await settings.loadSettings();
  // ThemeProvider defaults to dark; it only honours the stored preference once
  // it has loaded, so the sheets resolve the right stops per theme.
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
  testWidgets('the empty state is the illustration and nothing else', (
    tester,
  ) async {
    await _pumpEmptyHome(tester);

    expect(emptyState, findsOneWidget);
    expect(illustration, findsOneWidget);
    // Four sheets, each floating under its own transform.
    expect(drifts(tester), hasLength(4));

    // The old icon badge is gone, and with it every word and every control:
    // the FAB beside the state is the only call to action.
    expect(find.byIcon(Icons.picture_as_pdf_rounded), findsNothing);
    expect(find.text('Open your first PDF'), findsNothing);
    expect(find.textContaining('pick a document'), findsNothing);
    expect(
      find.descendant(of: emptyState, matching: find.byType(Text)),
      findsNothing,
    );
    expect(
      find.descendant(of: emptyState, matching: find.byType(Icon)),
      findsNothing,
    );
    for (final control in [
      InkWell,
      TextButton,
      ElevatedButton,
      GestureDetector,
    ]) {
      expect(
        find.descendant(of: emptyState, matching: find.byType(control)),
        findsNothing,
        reason: 'the empty state should offer no $control',
      );
    }
  });

  testWidgets('the sheets drift, and one period returns them to the start', (
    tester,
  ) async {
    await _pumpEmptyHome(tester);

    final start = drifts(tester);
    final startRotations = sheetAngles(tester);

    // A quarter period in, the stack has visibly moved.
    await tester.pump(kFloatPeriod ~/ 4);
    final quarter = drifts(tester);
    expect(quarter, isNot(equals(start)));

    // Three quarters later, every sheet is back where it began. Without this
    // the loop would show a jump at the seam.
    await tester.pump(kFloatPeriod * 3 ~/ 4);
    final afterOnePeriod = drifts(tester);

    for (var i = 0; i < start.length; i++) {
      expect(
        afterOnePeriod[i],
        closeTo(start[i], kEpsilon),
        reason: 'sheet $i jumped at the loop seam',
      );
      expect(
        sheetAngles(tester)[i],
        closeTo(startRotations[i], kEpsilon),
        reason: 'sheet $i jumped at the loop seam',
      );
    }
  });

  testWidgets('the sheets move out of phase, not as one rigid block', (
    tester,
  ) async {
    await _pumpEmptyHome(tester);

    // Sample a whole period, because the phase the tree happens to be pumped
    // at is arbitrary — and a property that only holds at one phase is not a
    // property.
    const steps = 12;
    var narrowestSpread = double.infinity;
    for (var i = 0; i < steps; i++) {
      final now = drifts(tester);
      await tester.pump(kFloatPeriod ~/ steps);
      narrowestSpread = math.min(
        narrowestSpread,
        now.reduce(math.max) - now.reduce(math.min),
      );
    }

    // If the four sheets travelled in lockstep this gap would be zero at every
    // phase. It is what makes the stack look like loose paper.
    expect(
      narrowestSpread,
      greaterThan(kPhaseSpreadFloor),
      reason:
          'the sheets are only $narrowestSpread px out of step at their '
          'closest',
    );
  });

  testWidgets('the artwork is not rebuilt per frame', (tester) async {
    await _pumpEmptyHome(tester);

    final sheetsBefore = sheetGradients(tester).length;
    final heroBefore = heroGradient(tester);
    final allBefore = sheetGradients(tester).toList();

    // Advance a dozen frames of drift.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // The per-frame rebuild wraps the already-built sheets in new transforms
    // and nothing else: the same Container instances come back out.
    final allAfter = sheetGradients(tester);
    expect(allAfter, hasLength(sheetsBefore));
    for (var i = 0; i < allBefore.length; i++) {
      expect(identical(allAfter[i], allBefore[i]), isTrue);
    }
    expect(identical(heroGradient(tester), heroBefore), isTrue);
  });

  testWidgets('both themes resolve the brand ramp', (tester) async {
    const expected = {
      Brightness.dark: BrandGradient.darkStops,
      Brightness.light: BrandGradient.lightStops,
    };

    for (final entry in expected.entries) {
      await _pumpEmptyHome(tester, darkTheme: entry.key == Brightness.dark);

      final gradients = sheetGradients(tester);
      // The hero sheet carries the whole ramp, so the empty state is anchored
      // to the same four colours as the wordmark and the FAB.
      expect(
        gradients.last.colors,
        entry.value,
        reason: 'wrong brand stops for ${entry.key}',
      );
      // And it animates without disturbing them.
      await tester.pump(kFloatPeriod ~/ 3);
      expect(heroGradient(tester).colors, entry.value, reason: '${entry.key}');

      // Each receding sheet is a different position along that ramp: two stops
      // pulled toward the surface for depth. So no sheet behind the hero is a
      // raw brand colour, and no two of them repeat.
      final receded = gradients.take(gradients.length - 1).toList();
      expect(receded, hasLength(3));
      for (final slice in receded) {
        expect(slice.colors, hasLength(2));
        for (final stop in slice.colors) {
          expect(
            entry.value,
            isNot(contains(stop)),
            reason: '${entry.key}: $stop was not pulled back for depth',
          );
        }
      }
      for (var i = 0; i < receded.length; i++) {
        for (var j = i + 1; j < receded.length; j++) {
          expect(
            receded[i].colors,
            isNot(equals(receded[j].colors)),
            reason: 'sheets $i and $j share a slice in ${entry.key}',
          );
        }
      }

      // A fill that has been pulled back for depth can only reach ~2.1:1 on the
      // light page, which is why each receding sheet is outlined in its
      // un-tinted stop: the edge is what stays visible, at the >= 3:1 the brand
      // stop set guarantees. The hero is painted at full strength and needs no
      // outline of its own.
      final decorations = sheetDecorations(tester);
      final outlines = [
        for (final d in decorations.take(decorations.length - 1))
          d.border?.top.color,
      ];
      for (final outline in outlines) {
        expect(outline, isNotNull, reason: '${entry.key}: an edge is missing');
        expect(
          entry.value,
          contains(outline),
          reason: '${entry.key}: $outline is not on the brand ramp',
        );
      }
      expect(
        outlines.toSet(),
        hasLength(3),
        reason: 'the three edges should sit at three different ramp positions',
      );
      expect(decorations.last.border, isNull, reason: 'the hero is outlined');
    }
  });

  testWidgets('the controller stops when the first file arrives', (
    tester,
  ) async {
    await _pumpEmptyHome(tester);

    // While the state is up, its ticker is live and keeps requesting frames.
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    // Adding a file swaps the state for the recents grid mid-animation. The
    // controller has to be disposed with it — if it were not, `flutter_test`
    // fails this test with "was disposed with an active Ticker", which is the
    // leak this guards.
    final provider = Provider.of<RecentFilesProvider>(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );
    await provider.addLocalFile(
      path: '/docs/first.pdf',
      name: 'First.pdf',
      size: 1024,
    );
    await pumpUi(tester);

    expect(illustration, findsNothing);
    expect(emptyState, findsNothing);
    expect(find.byType(PdfGridCard), findsOneWidget);

    // The illustration is really gone from the tree, not merely repainting
    // offscreen.
    await tester.pump(kFloatPeriod);
    expect(illustration, findsNothing);
  });
}
