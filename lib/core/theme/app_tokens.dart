import 'package:flutter/material.dart';

abstract final class AppTokens {
  const AppTokens._();

  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Radii
  static const double tile = 16;
  static const double card = 20;
  static const double button = 14;
  static const double pill = 999;

  // Strokes
  //
  // [hairline] is the app's only border weight: it has to separate a surface
  // from the surface behind it without drawing a frame around it. [ring] is the
  // one deliberate exception, the accent ring on the primary action tile.
  static const double hairline = 1;
  static const double ring = 1.5;

  // Interaction
  //
  // How far a tappable surface shrinks under the finger, and how long it takes
  // to get there and back. Short enough to feel like the finger rather than an
  // animation, and it runs alongside the Material ink ripple.
  static const double pressScale = 0.97;
  static const Duration press = Duration(milliseconds: 120);

  // Durations
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);

  // Navigation
  //
  // Shared by the M3 [NavigationBar]'s indicator tween and the Home screen's
  // gradient underline, so the two never drift apart.
  static const Duration nav = Duration(milliseconds: 250);

  // Curves
  static const Curve defaultCurve = Curves.easeOut;
}