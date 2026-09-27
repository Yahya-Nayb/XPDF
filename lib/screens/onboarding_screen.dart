import 'package:flutter/material.dart';

import '../colors.dart';
import '../services/storage_service.dart';

/// One page of the first-launch tour.
///
/// Icon and badge colors are stored as [AppColors.colorOf][] keys so they
/// resolve to the correct light/dark variant at build time (the list itself is
/// `const`, so it can't hold `BuildContext`-dependent colors). Icon sits in a
/// soft tinted circle (matching [EmptyState]'s treatment), with a bold title
/// and a short friendly line underneath. Kept deliberately free of legal
/// language — this is a reassurance, not a policy.
class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String body;
  final String iconColorKey;
  final String badgeColorKey;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.iconColorKey,
    required this.badgeColorKey,
  });
}

/// Minimal first-launch onboarding — three skippable pages that introduce the
/// app and, crucially, its private-by-design / fully-offline nature.
///
/// Shown only on first install: [HomeScreen] pushes this route over itself
/// when [`StorageService.loadHasSeenOnboarding`][] returns false. Finishing
/// (or skipping) persists the flag and simply pops back — the home screen is
/// already sitting underneath, so no route juggling is needed.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.picture_as_pdf_rounded,
      title: 'Welcome to XPDF',
      body: 'Read, annotate, merge, and split your PDFs —'
          '\neverything in one place.',
      iconColorKey: 'pdfIcon',
      badgeColorKey: 'pdfBadgeBg',
    ),
    _OnboardingPageData(
      icon: Icons.shield_outlined,
      title: 'Private by design',
      body: 'Your files and annotations stay on your device.'
          '\nNothing is ever uploaded anywhere.',
      iconColorKey: 'primary',
      badgeColorKey: 'inputFill',
    ),
    _OnboardingPageData(
      icon: Icons.wifi_off_rounded,
      title: 'Works fully offline',
      body: 'No ads, no tracking, no account. The only exception:'
          '\ndownloading a PDF from a link.',
      iconColorKey: 'primary',
      badgeColorKey: 'inputFill',
    ),
  ];

  final PageController _controller = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Mark onboarding as seen (Skip or Get Started) and return to the home
  /// screen underneath. Persisted so the tour never shows again.
  Future<void> _finish() async {
    await StorageService.saveHasSeenOnboarding(true);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorOf(context, 'background'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Top row: "Skip" (except on the last page, where the action is
              // just "Get Started").
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLastPage ? null : _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isLastPage
                            ? AppColors.colorOf(context, 'textMuted')
                            : AppColors.colorOf(context, 'textSecondary'),
                      ),
                    ),
                  ),
                ),
              ),

              // The paged content.
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) => _buildPage(_pages[index]),
                ),
              ),

              // Page dots + primary action.
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _currentPage ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? AppColors.colorOf(context, 'primary')
                            : AppColors.colorOf(context, 'border'),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLastPage ? _finish : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.colorOf(context, 'primary'),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLastPage ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData page) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon badge — same soft tinted circle as the empty-state.
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.colorOf(context, page.badgeColorKey),
            shape: BoxShape.circle,
          ),
          child: Icon(
            page.icon,
            size: 46,
            color: AppColors.colorOf(context, page.iconColorKey),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.colorOf(context, 'textPrimary'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          page.body,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.colorOf(context, 'textMuted'),
          ),
        ),
      ],
    );
  }
}