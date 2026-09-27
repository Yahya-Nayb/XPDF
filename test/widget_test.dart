import 'pump_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpdf/main.dart';
import 'package:xpdf/providers/settings_provider.dart';
import 'package:xpdf/providers/theme_provider.dart';
import 'package:xpdf/screens/home_screen.dart';
import 'package:xpdf/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App replaces splash with home screen', (
    WidgetTester tester,
  ) async {
    // Use a phone-sized viewport so the full home layout has room to render.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.loadSettings();
    await tester.pumpWidget(
      XpdfApp(themeProvider: ThemeProvider(), settingsProvider: settings),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.bySemanticsLabel('XPDF logo'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    final logo = tester.widget<Image>(find.byKey(const Key('splash-logo')));
    expect((logo.image as AssetImage).assetName, 'assets/images/logo.png');
    expect(logo.width, 288);
    expect(logo.height, 288);

    // The splash remains for 2.5 seconds, then fades into the home screen.
    await tester.pump(const Duration(milliseconds: 2500));
    await pumpUi(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);

    // pushReplacement removes the splash from the navigation history.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });
}
