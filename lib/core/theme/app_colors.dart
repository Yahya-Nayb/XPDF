import 'package:flutter/material.dart';

abstract final class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFFFF4757);

  // Gradient colors
  static const Color gradStart = Color(0xFFF5A623);
  static const Color gradMid1 = Color(0xFFE8456B);
  static const Color gradMid2 = Color(0xFF9B59B6);
  static const Color gradEnd = Color(0xFF4A90E2);

  // Feature colors
  static const Color scan = Color(0xFFF5A623);
  static const Color split = Color(0xFF9B59B6);
  static const Color merge = Color(0xFF4A90E2);
  static const Color images = Color(0xFFFF4757);

  // Dark palette
  static const Color darkBg = Color(0xFF0F0F11);
  static const Color darkSurface = Color(0xFF1A1A1D);
  static const Color darkSurfaceHigh = Color(0xFF232327);
  static const Color darkBorder = Color(0xFF2A2A2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkPrimaryContainer = Color(0xFF3A1C21);

// The soft lift a raised light-mode surface casts on what is behind it.
  //
  // Light mode only: AGENTS.md reserves elevation for light mode, where the
  // surface ramp tops out at white and depth has to come from a shadow. Dark mode
  // gets a genuine third surface step instead, so it uses none.
  static const Color lightShadow = Color(0x14000000);

  // The floating navigation pill's fill, on light pages.
  //
  // The pill is the one chrome element that stays dark in both themes — a white
  // one disappears into a light background. It borrows the dark palette's base
  // surface so the two themes agree on what the bar looks like; dark mode uses
  // its own `surfaceHigh` instead, where the page beneath it is already dark.
  static const Color navBarBg = darkSurface;

  // Warm gold for the favorite star. Shared by the Home header and the recent
  // rows so the one accent that is not a feature color is still defined once.
  static const Color favorite = Color(0xFFF6B93B);

  // Light palette
  static const Color lightBg = Color(0xFFF4F2F0);
  static const Color lightSurface = Color(0xFFFFFFFF);

  // The third surface level, on light surfaces.
  //
  // White is the ceiling of a light palette, so there is no colour *above*
  // [lightSurface] to fill a raised surface with — [lightSurfaceHigh] is white
  // itself and the third level is carried by the soft shadow that light mode
  // prescribes instead of by elevation (see AGENTS.md and [AppCard]). Dark mode
  // gets a genuine third step, [darkSurfaceHigh], because near-black has the
  // headroom for one.
  static const Color lightSurfaceHigh = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8E5E1);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF7A7A7A);
  static const Color lightPrimaryContainer = Color(0xFFFCE4E7);
}