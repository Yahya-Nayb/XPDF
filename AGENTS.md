# XPDF Design Rules (must be followed for every new screen)

- Never use hard-coded colors, radii, spacing, or durations. Use Theme.of(context), context.appColors, and AppTokens only.
- Primary red is the action color: one primary action per screen.
- The signature gradient (AppGradients.signature) is reserved for: logo, the main FAB, splash/loaders, and success moments. Do not use it on ordinary buttons or backgrounds.
- Each feature has its own color (scan/split/merge/images). New features must pick a color derived from the signature gradient and add it to AppColors and AppThemeExtension.
- Use AppCard / FeatureTile / EmptyState / GradientFab / GradientLoader instead of building custom ones. If a new reusable pattern is needed, add it to lib/core/widgets first.
- Radii: tile 16, card 20, button 14. Spacing scale: 4/8/12/16/24/32. Page padding: 16.
- Dark mode: no elevation, use a 1px border. Light mode: soft shadow.
- Every new screen must be verified in both light and dark mode, and must include a proper empty state and loading state.
- Animations: 200-300ms, Curves.easeOut.
- Run flutter analyze before finishing any task.
