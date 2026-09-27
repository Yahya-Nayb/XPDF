import 'pump_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpdf/main.dart';
import 'package:xpdf/providers/recent_files_provider.dart';
import 'package:xpdf/providers/settings_provider.dart';
import 'package:xpdf/providers/theme_provider.dart';
import 'package:xpdf/widgets/pdf_grid_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a recent-files list long enough that the recents section scrolls.
String _recentFilesJson(int count) {
  final entries = List.generate(count, (i) {
    return '{"path":"/docs/file$i.pdf","name":"Document number $i.pdf",'
        '"size":1024,"lastOpened":"2026-09-0${(i % 9) + 1}T10:00:00.000",'
        '"lastPage":1,"isFavorite":false,"folderId":null}';
  });
  return '[${entries.join(',')}]';
}

Future<void> _pumpHome(WidgetTester tester, {int files = 24}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({
    'recent_files': _recentFilesJson(files),
    'sort_mode': 'name_asc',
  });
  final settings = SettingsProvider();
  await settings.loadSettings();

  await tester.pumpWidget(
    XpdfApp(themeProvider: ThemeProvider(), settingsProvider: settings),
  );
  await tester.pump(const Duration(milliseconds: 2500));
  await pumpUi(tester);
}

void main() {
  final fab = find.byTooltip('Add document');

  testWidgets('add action is a circular icon-only FAB in the Scaffold slot', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(fab, findsOneWidget);

    // Material's regular FAB diameter.
    expect(tester.getSize(fab), const Size(56, 56));

    // Icon only: a white "+" and no text label.
    final icon = tester.widget<Icon>(
      find.descendant(of: fab, matching: find.byIcon(Icons.add_rounded)),
    );
    expect(icon.color, Colors.white);
    expect(find.descendant(of: fab, matching: find.byType(Text)), findsNothing);

    // Circular surface carrying the brand gradient.
    final material = tester.widget<Material>(
      find.descendant(of: fab, matching: find.byType(Material)).first,
    );
    expect(material.shape, isA<CircleBorder>());
    expect(material.elevation, 6);

    final ink = tester.widget<Ink>(find.descendant(of: fab, matching: find.byType(Ink)));
    final decoration = ink.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.gradient, isA<LinearGradient>());
    expect((decoration.gradient! as LinearGradient).colors.length, 4);
  });

  testWidgets('FAB lives in the floatingActionButton slot, not the list', (
    tester,
  ) async {
    await _pumpHome(tester);

    // Inside the Scaffold, but not inside the scrolling content.
    expect(
      find.descendant(of: find.byType(Scaffold), matching: fab),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(CustomScrollView), matching: fab),
      findsNothing,
    );
  });

  testWidgets('FAB stays pinned while the recents scroll', (tester) async {
    await _pumpHome(tester);
    final before = tester.getTopLeft(fab);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await pumpUi(tester);
    final after = tester.getTopLeft(fab);

    expect(after, before);
  });

  testWidgets('FAB clears the bottom navigation bar', (tester) async {
    await _pumpHome(tester);

    // Scaffold floats the action above bottomNavigationBar on its own.
    expect(
      tester.getBottomLeft(fab).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byType(BottomNavigationBar)).dy,
      ),
    );
  });

  testWidgets('FAB keeps the last recent file clear of its own footprint', (
    tester,
  ) async {
    await _pumpHome(tester);

    // Checked against the sliver list rather than the element tree: the spacer
    // is the final sliver, so it has no element until the list is scrolled.
    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    final lastSliver = scrollView.slivers.last;
    expect(lastSliver, isA<SliverToBoxAdapter>());
    // Scaffold's 16dp FAB margin + 56dp FAB + a further 16dp so the final row
    // settles fully above the button rather than flush against it.
    expect(
      ((lastSliver as SliverToBoxAdapter).child! as SizedBox).height,
      16 + 56 + 16,
    );

    // Scrolled to the very end, the last card sits above the FAB's top edge.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await pumpUi(tester);

    final fabTop = tester.getTopLeft(fab).dy;
    // Recent items are PdfGridCard widgets (a GestureDetector over a
    // Container), so target those rather than Card.
    final lastCard = find.byType(PdfGridCard);
    expect(lastCard, findsWidgets);
    expect(
      tester.getBottomLeft(lastCard.last).dy,
      lessThanOrEqualTo(fabTop),
    );
  });

  testWidgets('FAB is hidden on the non-home tabs, as before', (tester) async {
    await _pumpHome(tester);
    expect(fab, findsOneWidget);

    await tester.tap(find.byIcon(Icons.folder_rounded));
    await pumpUi(tester);
    expect(fab, findsNothing);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await pumpUi(tester);
    expect(fab, findsNothing);
  });

  testWidgets('FAB tap still routes through the recent-files import flow', (
    tester,
  ) async {
    await _pumpHome(tester);

    final provider = Provider.of<RecentFilesProvider>(
      tester.element(find.byType(CustomScrollView)),
      listen: false,
    );
    expect(provider.files, isNotEmpty);

    // The InkWell must be wired to the same handler the old button used.
    final well = tester.widget<InkWell>(
      find.descendant(of: fab, matching: find.byType(InkWell)),
    );
    expect(well.onTap, isNotNull);
  });
}
