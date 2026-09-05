import 'package:flutter_test/flutter_test.dart';
import 'package:folia/main.dart';
import 'package:folia/providers/theme_provider.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      FoliaApp(themeProvider: ThemeProvider()),
    );
    expect(find.text('XPDF', findRichText: true), findsOneWidget);
  });
}