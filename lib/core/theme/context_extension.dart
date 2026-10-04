import 'package:flutter/material.dart';

import 'app_theme_extension.dart';

extension AppThemeContext on BuildContext {
  AppThemeExtension get appColors {
    final extension = Theme.of(this).extension<AppThemeExtension>();
    if (extension == null) {
      throw FlutterError(
        'AppThemeExtension is not registered in ThemeData.\n'
        'context.appColors was read from a context whose ThemeData has no '
        'AppThemeExtension, so theme-aware colors cannot be resolved.\n'
        'Register it on every ThemeData used by the app, e.g.:\n'
        '  theme: AppTheme.light().copyWith(\n'
        '    extensions: const [AppThemeExtension.light],\n'
        '  ),',
      );
    }
    return extension;
  }
}