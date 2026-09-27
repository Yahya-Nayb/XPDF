/// Backward-compatible export — prefer `theme/app_colors.dart` in new code.
library;

export 'theme/app_colors.dart';

import 'package:flutter/material.dart';

/// Night-mode page rendering: a "comfortable reading" color filter that turns
/// white PDF pages into a warm dark gray (≈#221e16) and black ink into warm
/// off-white (≈#e9e5dd), with colored content kept recognizable (its hue is
/// preserved) but muted — the opposite of the harsh "accessibility invert",
/// which flips every pixel to full-contrast complements.
///
/// The filter is a single affine [ColorFilter.matrix] that composes four
/// linear operations, applied to page pixels on the GPU:
///
/// 1. **Hue-preserving luminance flip** `I` — replaces each pixel's luma
///    `L = 0.299R + 0.587G + 0.114B` (Rec.601/sRGB-ish weights, matching the
///    original flip) with `1 - L` while leaving its chroma untouched:
///    `R' = R + 1 - 2L`, likewise G'/B'. White→black, black→white, but a red
///    logo stays red (just lighter) instead of turning cyan.
/// 2. **Tonal contraction** `C` — leans every channel toward mid-gray,
///    `C(x) = k·x + (1-k)·127.5` with `k = 0.78`. This is what softens the
///    harsh 0↔255 extremes: paper lands at ≈#221e16 and ink at ≈#e9e5dd
///    instead of pure black/white. (A linear stand-in for gamma; true
///    per-pixel s-curves would require a custom shader, which we avoid for
///    performance and because ColorFilter.matrix is linear.)
/// 3. **Desaturation** `S` — mixes each channel toward the pixel's own luma by
///    `s = 0.70` (1.0 = unchanged), so saturated logos/text/chart cells lose
///    the neon edge while keeping their identity.
/// 4. **Warm cast** `W` — adds a small constant offset `(+6, +2, -6)` to R/G/B
///    (a gentle sepia warmth) so near-monochrome reading pages don't feel
///    sterile.
///
/// All four are affine, so they collapse into ONE 4×5 matrix — a single GPU
/// pass and no per-pixel Dart work. The result is deliberately NOT an
/// involution (every involutive affine map must send grays to `c - g`, i.e.
/// a full-contrast inversion — exactly what we are softening). Overlay
/// compensation therefore uses the exact affine INVERSE filter (composed of
/// the same two trivial matrix steps below) rather than applying the same
/// filter twice.
///
/// [wrap] applies the night filter to the whole viewer subtree. Our app-level
/// overlays (annotation highlights, the floating selection toolbar) sit inside
/// that subtree and must be individually pre-compensated with [counterWrap],
/// which applies the inverse matrix `G = F⁻¹` (A_G = A_F⁻¹, b_G = −A_G·b_F).
/// Because F is globally affine and never clips in-range colors, `F(G(c)) ≈ c`
/// returns overlays to their authored colors — exact except where G would push
/// an overlay color outside [0,255] (e.g. pure white pre-distorts below 0 and
/// lands on the nearest representable warm white ≈#e9e5dd, which reads as a
/// soft light surface rather than an error).
class NightMode {
  NightMode._();

  static const List<double> nightMatrix = <double>[
    0.1495, -0.7784, -0.1512, 0, 232.950,
    -0.3965, -0.2324, -0.1512, 0, 228.950,
    -0.3965, -0.7784, 0.3948, 0, 220.950,
    0, 0, 0, 1, 0,
  ];

  static const List<double> compensationMatrix = <double>[
    0.9005, -1.8277, -0.3549, 0, 287.084,
    -0.9310, 0.0038, -0.3549, 0, 294.410,
    -0.9310, -1.8277, 1.4766, 0, 309.062,
    0, 0, 0, 1, 0,
  ];

  static ColorFilter get colorFilter => ColorFilter.matrix(nightMatrix);

  static ColorFilter get compensationColorFilter =>
      ColorFilter.matrix(compensationMatrix);

  static Widget wrap(Widget child) =>
      ColorFiltered(colorFilter: colorFilter, child: child);

  static Widget counterWrap(Widget child) =>
      ColorFiltered(colorFilter: compensationColorFilter, child: child);
}
