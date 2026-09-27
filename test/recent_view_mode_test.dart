import 'pump_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpdf/main.dart';
import 'package:xpdf/models/recent_file.dart';
import 'package:xpdf/providers/settings_provider.dart';
import 'package:xpdf/providers/theme_provider.dart';
import 'package:xpdf/widgets/pdf_grid_card.dart';
import 'package:xpdf/widgets/recent_file_list_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<RecentFile> _twoFiles() => [
      RecentFile(
        path: '/storage/doc1.pdf',
        name: 'Quarterly Report.pdf',
        size: 2048,
        lastOpened: '2026-09-05T10:00:00.000',
        lastPage: 12,
      ),
      RecentFile(
        path: '/storage/doc2.pdf',
        name: 'Invoice 42.pdf',
        size: 5120,
        lastOpened: '2026-09-06T08:30:00.000',
        lastPage: 1,
        isFavorite: true,
      ),
    ];

Future<SettingsProvider> _settings() async {
  final settings = SettingsProvider();
  await settings.loadSettings();
  return settings;
}

Future<ThemeProvider> _theme() async {
  final theme = ThemeProvider();
  await theme.loadTheme();
  return theme;
}

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(
    XpdfApp(
      themeProvider: await _theme(),
      settingsProvider: await _settings(),
    ),
  );
  // Advance through the app's timed splash before exercising the home screen.
  await tester.pump(const Duration(milliseconds: 2500));
  await pumpUi(tester);
}

void main() {
  testWidgets('Default is grid; toggle switches to list and persists',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'recent_files': RecentFile.encodeList(_twoFiles()),
    });

    await _boot(tester);

    expect(find.byType(PdfGridCard), findsNWidgets(2));
    expect(find.byType(RecentFileListRow), findsNothing);

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await pumpUi(tester);

    expect(find.byType(PdfGridCard), findsNothing);
    expect(find.byType(RecentFileListRow), findsNWidgets(2));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recent_view_mode'), 'list');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await _boot(tester);

    expect(find.byType(RecentFileListRow), findsNWidgets(2));
    expect(find.byType(PdfGridCard), findsNothing);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
  });
}
