import 'package:flutter/material.dart';
import '../colors.dart';

/// Friendly message shown when there are no recent files yet.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in a soft circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.colorOf(context, 'pdfBadgeBg'),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                size: 40,
                color: AppColors.colorOf(context, 'pdfIcon'),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Open your first PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the + button or use "Files" to\npick a document from your device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.colorOf(context, 'textMuted'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
