import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';
import '../theme/context_extension.dart';

/// One destination on the [FloatingPillNav].
///
/// [label] is never painted — the reference design has the live tab marked by a
/// white disc behind its icon and nothing else — but it is what the destination
/// is announced as, so it stays.
@immutable
class FloatingPillNavItem {
  final IconData icon;
  final String label;

  const FloatingPillNavItem({required this.icon, required this.label});
}

/// The app's main navigation: a dark pill floating clear of the screen edges,
/// with the live destination marked by a white disc behind its icon.
///
/// Meant to sit in a [Scaffold]'s `bottomNavigationBar` slot alongside
/// `extendBody: true`, so page content scrolls *under* the glass. Because of
/// that, every scroll view in the shell needs `barHeight + bottomMargin` of
/// bottom padding — see [scrollClearance].
///
/// Each destination owns its own disc rather than sharing one that slides
/// between them. The slots are already there, laid out for the icons, so a disc
/// that belongs to a destination is both simpler and exact: it cannot drift from
/// the icon it is marking, and the pill needs no second pass of layout to place
/// it.
class FloatingPillNav extends StatelessWidget {
  /// Height of the pill itself, excluding its margins.
  static const double barHeight = 64;

  /// Gap between the pill and the left and right screen edges. Non-zero on
  /// purpose: a bar that touches the edge reads as a page background, not as a
  /// floating object.
  static const double horizontalMargin = 28;

  /// Gap between the pill and the bottom of the screen, before the system inset
  /// is added.
  static const double bottomMargin = 10;

  /// Padding inside the pill, left and right. Symmetric, so the four slots are
  /// centred on the pill as a whole.
  static const double innerPadding = 10;

  /// The live destination's white disc, and the box every slot centres.
  static const double indicatorSize = 46;

  /// How far the disc travels from rest to full size. Small: it is a circle
  /// arriving under an icon that never moves, not a launch.
  static const double indicatorRestScale = 0.6;

  /// Destination icons, active or not.
  static const double iconSize = 24;

  /// How far a destination shrinks under the finger.
  static const double pressScale = 0.95;

  /// [pressScale]'s counterpart in time: quicker than [AppTokens.press], because
  /// the destination is a small target and the press has to register at once.
  static const Duration pressDuration = Duration(milliseconds: 100);

  /// How long the disc takes to reach full size, and how long an icon takes to
  /// change colour. The disc moves on [AppTokens.nav] so it matches the rest of
  /// the navigation's timing; the tint is [AppTokens.fast], a shade quicker
  /// because nothing about it has distance to cover.
  static const Duration indicatorDuration = AppTokens.nav;
  static const Duration tintDuration = AppTokens.fast;

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<FloatingPillNavItem> items;

  const FloatingPillNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.items,
  });

  /// The height a scroll view must reserve at its bottom so its last item
  /// clears the pill: the bar itself plus the margin it keeps off the screen
  /// edge.
  ///
  /// The body runs behind the bar (`extendBody`), so this is scrollable space
  /// rather than layout the bar consumes. The system inset is deliberately
  /// absent — it is already handled by the pill's own margin.
  static double get scrollClearance => barHeight + bottomMargin;

  @override
  Widget build(BuildContext context) {
    final ext = context.appColors;

    return Stack(
      children: [
        // Painted first, so the pill covers all but the sliver of it that shows
        // below: that sliver is what keeps list content from sliding out under
        // the bar and sitting on the bare page.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(child: _BottomFade()),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalMargin,
            0,
            horizontalMargin,
            bottomMargin + MediaQuery.paddingOf(context).bottom,
          ),
          child: Container(
            height: barHeight,
            padding: const EdgeInsets.symmetric(horizontal: innerPadding),
            decoration: BoxDecoration(
              color: ext.navBarBg,
              borderRadius: BorderRadius.circular(AppTokens.pill),
              // The bar is near-black in both themes, so in light mode its own
              // fill separates it from the page. In dark mode the page is
              // near-black too and that stops being enough — a hairline has to.
              border: Theme.of(context).brightness == Brightness.dark
                  ? Border.all(
                      // White at 8%: the same hairline the glass tiles use.
                      color: ext.glassBorder,
                      width: AppTokens.hairline,
                    )
                  : null,
              boxShadow: const [
                // Black at 25%: the pill has to read as lifted from the page in
                // light mode, where there is no surface ramp to do it for it.
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            // `expand` because the Container's own height is only a cap: without
            // something claiming all of it the Row would size to its icons and
            // the pill would shrink to the size of the largest one.
            child: SizedBox.expand(
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavItem(
                        item: items[i],
                        active: i == currentIndex,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One destination: its own disc, its own icon, its own press.
class _NavItem extends StatefulWidget {
  final FloatingPillNavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    // A tick, not an impact: this is a discrete choice between known
    // destinations, and re-tapping the live one is not a change at all.
    if (!widget.active) HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.appColors;

    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.item.label,
      // Outermost, so the tap target is the whole slot at full size: the scale
      // below shrinks the icon, not the area the finger has to find.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? FloatingPillNav.pressScale : 1,
          duration: FloatingPillNav.pressDuration,
          curve: AppTokens.defaultCurve,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The disc, behind the icon. It scales and fades rather than
                // appearing: a circle that pops into existence reads as an
                // overlay, one that grows into place reads as this tab's own.
                AnimatedScale(
                  scale: widget.active ? 1 : FloatingPillNav.indicatorRestScale,
                  duration: FloatingPillNav.indicatorDuration,
                  curve: AppTokens.defaultCurve,
                  child: AnimatedOpacity(
                    opacity: widget.active ? 1 : 0,
                    duration: FloatingPillNav.tintDuration,
                    curve: AppTokens.defaultCurve,
                    child: Container(
                      width: FloatingPillNav.indicatorSize,
                      height: FloatingPillNav.indicatorSize,
                      decoration: BoxDecoration(
                        color: ext.navIndicator,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                // The icon, which changes colour but never shape: the outlined
                // glyph is the same one whether or not the disc is there.
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: widget.active ? ext.navIconActive : ext.navIconInactive,
                  ),
                  duration: FloatingPillNav.tintDuration,
                  curve: AppTokens.defaultCurve,
                  builder: (context, color, _) => Icon(
                    widget.item.icon,
                    size: FloatingPillNav.iconSize,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip of page behind the pill's bottom edge: clear at the top, opaque
/// scaffold background at the bottom.
///
/// It exists because the page runs behind the bar — without it, a file row that
/// scrolls under the pill's bottom margin would hang visible over the bare
/// screen edge. 32dp covers that margin plus the system inset on a device that
/// has one.
class _BottomFade extends StatelessWidget {
  static const double height = 32;

  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [background.withValues(alpha: 0), background],
          ),
        ),
      ),
    );
  }
}