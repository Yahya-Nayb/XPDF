import 'dart:async';

import 'package:flutter/material.dart';

/// Displays the XPDF logo briefly before replacing itself with [destination].
class SplashScreen extends StatefulWidget {
  final Widget destination;
  final Duration displayDuration;

  const SplashScreen({
    super.key,
    required this.destination,
    this.displayDuration = const Duration(milliseconds: 2500),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // The shared logo asset is a 1152px (@4x) transparent canvas. Rendering it
  // at 288 logical pixels exactly matches the native Android/iOS scale.
  static const double _logoCanvasSize = 288;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Keep the Flutter splash visible long enough for the branding to be seen.
    _navigationTimer = Timer(widget.displayDuration, _openDestination);
  }

  void _openDestination() {
    if (!mounted) return;

    // Replace the splash route so pressing Back cannot return to it. A short
    // fade keeps the hand-off to the home screen smooth.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => widget.destination,
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    // Cancel the delayed navigation if the splash leaves the tree early.
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep this identical to both native splash variants in pubspec.yaml.
      backgroundColor: const Color(0xFF0E0E10),
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          key: const Key('splash-logo'),
          width: _logoCanvasSize,
          height: _logoCanvasSize,
          fit: BoxFit.contain,
          semanticLabel: 'XPDF logo',
        ),
      ),
    );
  }
}
