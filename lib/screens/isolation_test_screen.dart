import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Bare-minimum PDF viewer for isolation testing.
/// No providers, no listeners, no custom AppBar, no page tracking.
/// Used to determine whether lag is inherent to the viewer or caused
/// by surrounding app code.
class IsolationTestScreen extends StatelessWidget {
  final String filePath;
  const IsolationTestScreen({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PdfViewer.file(filePath),
    );
  }
}
