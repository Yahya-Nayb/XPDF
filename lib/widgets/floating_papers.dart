import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/brand_gradient.dart';

/// The empty-state illustration: a loose stack of four sheets of paper,
/// floating.
///
/// It replaces the old single-icon badge entirely, and it carries the whole
/// message — "no documents yet" reads off the stack, and the "Add document" FAB
/// beside it is the only call to action, so there is no title, body or button
/// to repeat what the artwork and the FAB already say.
///
/// Everything is drawn from plain containers: a `Stack` of rounded
/// [Container]s, no asset and no [CustomPainter]. That keeps the illustration
/// offline, theme-aware and free of a decode step, and it means the only pixels
/// that change per frame are the transforms in the [AnimatedBuilder] below.
///
/// The colours come from [BrandGradient] so the stack reads as the same brand
/// as the header wordmark and the FAB. The hero sheet carries the full
/// four-stop ramp; the three behind it take consecutive two-stop slices of it,
/// walked round to the start so the stack as a whole spans coral → amber →
/// magenta → blue. They are mixed toward the theme's surface by [lightDepth] /
/// [darkDepth] so they recede as depth rather than competing with the hero, and
/// outlined in their un-tinted stop so their edges still read on the light
/// page, where a tint cannot clear 3:1 however hard it is pushed.
class FloatingPapers extends StatefulWidget {
  const FloatingPapers({super.key});

  @override
  State<FloatingPapers> createState() => _FloatingPapersState();
}

class _FloatingPapersState extends State<FloatingPapers>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------------------

  /// One full there-and-back float.
  ///
  /// Slower than the "Add document" FAB's 3.2s shimmer, and deliberately so:
  /// the sheets are the largest thing on an otherwise empty screen, so a faster
  /// cadence would read as "attention" rather than "ambient". At 3.6s the hero
  /// sheet's peak speed is about 10 dp/s — a drift, not a bob.
  static const Duration _floatPeriod = Duration(milliseconds: 3600);

  /// The stack's paint box.
  ///
  /// Deliberately larger than the resting sheets: the transforms in the
  /// [AnimatedBuilder] paint outside the layout box (that is what
  /// [Transform.translate] does), so the canvas has to hold a sheet at either
  /// end of its drift or the stack clips it mid-sweep. The stack therefore
  /// clips nothing ([Clip.none]) and the slack in these numbers is the margin.
  static const double _canvasWidth = 180;
  static const double _canvasHeight = 164;

  static const double _sheetWidth = 78;
  static const double _sheetHeight = 100;
  static const double _sheetRadius = 10;

  /// Hairline that draws the edge of a receding sheet. Deliberately thin — at
  /// 2.4 physical px on a 2x screen it reads as a drawn edge rather than a
  /// frame, and it is light enough not to compete with the hero's fill.
  static const double _outlineWidth = 1.2;

  // ---------------------------------------------------------------------------
  // Depth
  // ---------------------------------------------------------------------------

  /// How much of the brand colour each receding sheet keeps, on light surfaces.
  ///
  /// The background is `#F4F3F1`, so a sheet mixed this far toward white still
  /// reads as a coloured field (measured around 2.1:1, which is why
  /// [_outlineWidth] exists) while leaving the hero the only fully saturated
  /// object on screen. Pushing this higher buys contrast the page cannot give:
  /// a tint can only ever reach the hero's own weight.
  static const double lightDepth = 0.62;

  /// The same, on dark surfaces.
  ///
  /// Higher than [lightDepth] because mixing a vivid hue toward a near-black
  /// surface desaturates it hard: at the light value the coral and amber sheets
  /// turn to mud on `#0E0E10`. Against a dark page the hues can carry more of
  /// themselves and still stay behind the hero.
  static const double darkDepth = 0.92;

  /// Sheet drop shadow on light surfaces: a plain black shadow reads against
  /// `#F4F3F1`.
  static const List<BoxShadow> lightShadows = [
    BoxShadow(color: Color(0x1F161516), blurRadius: 14, offset: Offset(0, 8)),
  ];

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: _floatPeriod,
  );

  @override
  void initState() {
    super.initState();
    _float.repeat();
  }

  @override
  void dispose() {
    // Unmounted as soon as the first file replaces the empty state with the
    // recents grid, so nothing keeps requesting frames behind the list.
    _float.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Built once per build of this widget, not once per frame. The per-frame
    // rebuild below closes over the same [Widget] instances, so each sheet's
    // element is reused untouched and only its transforms change — the same
    // trick `_AddDocumentFab` uses to keep its shimmer off the home screen.
    final sheets = _sheets(context);

    return RepaintBoundary(
      child: SizedBox(
        width: _canvasWidth,
        height: _canvasHeight,
        child: AnimatedBuilder(
          animation: _float,
          builder: (context, _) {
            return Stack(
              // See [_canvasWidth]: the transforms paint outside this box.
              clipBehavior: Clip.none,
              children: [
                for (final sheet in sheets)
                  Positioned(
                    left: sheet.left,
                    top: sheet.top,
                    child: Transform.translate(
                      offset: sheet.offsetAt(_float.value),
                      child: Transform.rotate(
                        angle: sheet.angleAt(_float.value),
                        child: sheet.child,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The sheets in paint order, back to front.
  ///
  /// Each one is offset up and to the right of the hero and rotated a little
  /// further, so the stack fans out instead of reading as a rigid block. The
  /// three behind the hero are two-stop slices of the brand ramp; the hero is
  /// the whole ramp plus the ruled lines that make a rectangle read as a page.
  List<_Sheet> _sheets(BuildContext context) {
    final surface = AppColors.schemeOf(context).surface;
    final depth = AppColors.isDark(context) ? darkDepth : lightDepth;

    // The three receding sheets, each walked one step further along the ramp.
    final coral = _receded(context, surface, depth, 3);
    final azure = _receded(context, surface, depth, 2);
    final amber = _receded(context, surface, depth, 1);

    return [
      // Furthest back: blue → coral, closing the loop on the ramp.
      _Sheet(
        left: 86,
        top: 18,
        rotation: 0.15,
        travel: 8,
        sway: 3,
        turn: 0.024,
        phase: 3.3,
        child: _sheet(context, gradient: coral.fill, outline: coral.outline),
      ),
      _Sheet(
        left: 66,
        top: 28,
        rotation: 0.095,
        travel: 6.5,
        sway: 2.2,
        turn: 0.02,
        phase: 2.2,
        child: _sheet(context, gradient: azure.fill, outline: azure.outline),
      ),
      _Sheet(
        left: 46,
        top: 38,
        rotation: 0.035,
        travel: 7,
        sway: 2.8,
        turn: 0.022,
        phase: 1.1,
        child: _sheet(context, gradient: amber.fill, outline: amber.outline),
      ),
      // The hero carries the whole four-stop ramp, plus the ruled lines that
      // make a rectangle read as a page.
      _Sheet(
        left: 26,
        top: 48,
        rotation: -0.03,
        travel: 6,
        sway: 2.5,
        turn: 0.018,
        phase: 0,
        child: _sheet(
          context,
          gradient: BrandGradient.linearFor(
            context,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          lines: _rules(const Color(0xB3FFFFFF)),
        ),
      ),
    ];
  }

  /// One sheet: a rounded rectangle filled with [gradient] and shadowed so the
  /// stack separates into layers.
  ///
  /// [outline] is passed only by the receding sheets, and it is what makes them
  /// visible on a light page: a tint pulled toward the surface cannot clear
  /// 3:1 against `#F4F3F1` however hard it is pushed — at full strength it just
  /// becomes as loud as the hero. A hairline in the un-tinted stop draws the
  /// edge instead, at the >= 3.0:1 the [BrandGradient] stop set already
  /// guarantees. The hero needs no outline: it is painted at full strength.
  Widget _sheet(
    BuildContext context, {
    required LinearGradient gradient,
    Color? outline,
    Widget? lines,
  }) {
    final shadows = AppColors.isDark(context)
        ? <BoxShadow>[
            // Black is nearly invisible on `#0E0E10`, so most of the depth
            // comes from a soft halo of the sheet's own colour instead.
            const BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 16,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: gradient.colors.last.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ]
        : lightShadows;

    return Container(
      width: _sheetWidth,
      height: _sheetHeight,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(_sheetRadius),
        border: outline == null
            ? null
            : Border.all(color: outline, width: _outlineWidth),
        boxShadow: shadows,
      ),
      child: lines,
    );
  }

  /// The ruled lines that make the hero sheet read as a page rather than a
  /// tile. White at partial opacity, so the same bars work on the light and
  /// the dark stop set without the theme having to be consulted.
  Widget _rules(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _bar(32, 6, color),
          const SizedBox(height: 9),
          _bar(50, 5, color),
          const SizedBox(height: 9),
          _bar(50, 5, color),
          const SizedBox(height: 9),
          _bar(24, 5, color),
        ],
      ),
    );
  }

  Widget _bar(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }

  /// The two-stop slice of the brand ramp starting at [from], wrapped back
  /// around to the first stop, plus the un-tinted stop that draws that sheet's
  /// edge. See [_sheet] for why the fill is pulled back but the edge is not.
  ({LinearGradient fill, Color outline}) _receded(
    BuildContext context,
    Color surface,
    double depth,
    int from,
  ) {
    final stops = BrandGradient.stopsFor(context);
    return (
      fill: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _tint(stops[from], surface, depth),
          _tint(stops[(from + 1) % stops.length], surface, depth),
        ],
      ),
      outline: stops[from],
    );
  }

  /// [color] with [strength] of its own hue left in, the rest mixed toward
  /// [surface].
  static Color _tint(Color color, Color surface, double strength) =>
      Color.lerp(color, surface, 1 - strength)!;
}

/// One sheet's resting geometry, plus the motion that keeps it out of step
/// with its neighbours.
class _Sheet {
  const _Sheet({
    required this.left,
    required this.top,
    required this.rotation,
    required this.travel,
    required this.sway,
    required this.turn,
    required this.phase,
    required this.child,
  });

  /// Resting offset within the stack's canvas. These are layout, not motion, so
  /// they are fed to [Positioned] and the drift below is free to overshoot.
  final double left;
  final double top;

  /// Resting tilt, in radians.
  final double rotation;

  /// Vertical travel at the extremes, in logical pixels.
  final double travel;

  /// Horizontal sway at the extremes, in logical pixels.
  final double sway;

  /// Tilt added at the extremes, in radians.
  final double turn;

  /// This sheet's offset into the cycle, in radians. The four are spaced 1.1
  /// rad apart, which is what stops the stack moving as one rigid block: at
  /// any instant some sheets are near the top of their drift and some near the
  /// bottom, and the gap between the highest and lowest never closes below
  /// ~6.5px anywhere in the cycle. Closer spacing bunches the sheets into the
  /// same part of the cosine together — at 0.6rad they nearly coincide twice
  /// per loop and the stack reads as rigid for a moment each time.
  final double phase;

  /// The sheet itself. Held as an already-built widget so the per-frame rebuild
  /// only wraps it in transforms.
  final Widget child;

  /// Drift at [t], a fraction of one period.
  ///
  /// Both terms run on the same frequency, so the value at `t == 1` equals the
  /// value at `t == 0` and the loop has no seam. A sine on the horizontal sway
  /// against a cosine on the vertical travel traces an ellipse, and both ease
  /// through their extremes rather than reversing at speed.
  Offset offsetAt(double t) {
    final theta = t * 2 * math.pi + phase;
    return Offset(sway * math.sin(theta), -travel * math.cos(theta));
  }

  /// Tilt at [t]. Shares the phase with [offsetAt], so a sheet is never flat
  /// while it is also stationary.
  double angleAt(double t) =>
      rotation + turn * math.sin(t * 2 * math.pi + phase);
}
