import 'pump_ui.dart';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpdf/main.dart';
import 'package:xpdf/providers/settings_provider.dart';
import 'package:xpdf/providers/theme_provider.dart';
import 'package:xpdf/theme/app_colors.dart';
import 'package:xpdf/theme/brand_gradient.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps [child] in a minimal app so [BrandGradient] can read the brightness.
Widget _host(Widget child, {required Brightness brightness}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: child),
  );
}

Text _wordmarkText(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(
      of: find.byType(ShaderMask),
      matching: find.text('XPDF'),
    ));

void main() {
  // The Caveat faces are static instances cut from the upstream variable font.
  // Reading them from disk proves they ship with the app and need no network.
  const regularPath = 'assets/fonts/Caveat-Regular.ttf';
  const boldPath = 'assets/fonts/Caveat-Bold.ttf';

  test('Caveat faces are bundled assets and load without network', () async {
    for (final path in [regularPath, boldPath]) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path must ship with the app');
      expect(file.lengthSync(), greaterThan(0));
    }

    final loader = FontLoader(BrandGradient.wordmarkFont);
    for (final path in [regularPath, boldPath]) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(
        Future<ByteData>.value(ByteData.sublistView(Uint8List.fromList(bytes))),
      );
    }

    // Throws if the .ttf files are unreadable or not valid font data.
    await loader.load();
  });

  testWidgets('home app bar renders the gradient XPDF wordmark', (
    tester,
  ) async {
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
    // Clear the splash so the home app bar is on screen.
    await tester.pump(const Duration(milliseconds: 2500));
    await pumpUi(tester);

    // The former coral wordmark image is gone from the header.
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.text('XPDF'), findsOneWidget);

    final text = _wordmarkText(tester);
    final style = text.style!;
    expect(style.fontFamily, 'Caveat');
    expect(style.fontWeight, FontWeight.w700);
    expect(style.fontSize, 32);
  });

  testWidgets('gradient swaps stops for light and dark surfaces', (
    tester,
  ) async {
    Future<List<Color>> stopsFor(Brightness brightness) async {
      final holder = <List<Color>>[];
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              holder
                ..clear()
                ..add(BrandGradient.stopsFor(context));
              return const SizedBox.shrink();
            },
          ),
          brightness: brightness,
        ),
      );
      // MaterialApp animates theme changes, so settle before sampling the
      // brightness the gradient actually resolved.
      await pumpUi(tester);
      return holder.single;
    }

    final dark = await stopsFor(Brightness.dark);
    final light = await stopsFor(Brightness.light);

    // Brand order: coral red -> amber -> magenta -> blue.
    expect(dark, [
      const Color(0xFFFF4D5E),
      const Color(0xFFFFA94D),
      const Color(0xFFC6469C),
      const Color(0xFF4D9FFF),
    ]);

    // The light set is depth-adjusted so amber and blue clear 3:1 on the
    // off-white app bar; magenta was already legible and is unchanged.
    expect(light, [
      const Color(0xFFFF4759),
      const Color(0xFFD97000),
      const Color(0xFFC6469C),
      const Color(0xFF2A8CFF),
    ]);
    expect(light, isNot(equals(dark)));
  });

  test('light-mode stops stay legible on the light app bar', () {
    // Mirrors WCAG relative-luminance contrast so a future palette tweak that
    // breaks readability of the wordmark or CTA fails here first.
    double luminance(Color c) {
      // Read the packed ARGB so this works regardless of whether Color.r/g/b
      // are normalised 0..1 doubles or 0..255 ints across Flutter versions.
      final argb = c.toARGB32();
      double channel(int v) {
        final x = v / 255.0;
        return x <= 0.04045
            ? x / 12.92
            : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
      }

      return 0.2126 * channel((argb >> 16) & 0xFF) +
          0.7152 * channel((argb >> 8) & 0xFF) +
          0.0722 * channel(argb & 0xFF);
    }

    double contrast(Color a, Color b) {
      final la = luminance(a), lb = luminance(b);
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    // 3.0:1 is the AA threshold for large text; the wordmark is 32px bold.
    for (final stop in BrandGradient.lightStops) {
      expect(
        contrast(stop, AppColors.background),
        greaterThanOrEqualTo(3.0),
        reason: '$stop is too faint on the light app bar',
      );
    }

    for (final stop in BrandGradient.darkStops) {
      expect(
        contrast(stop, AppColors.darkBackground),
        greaterThanOrEqualTo(3.0),
        reason: '$stop is too faint on the dark app bar',
      );
    }
  });
}
