import 'package:flutter/material.dart';
import '../colors.dart';

/// Reusable confirmation dialog in Folia's dialog style (rounded corners,
/// AppColors palette, Cancel + filled Confirm actions).
///
/// Resolves to `true` when the user confirms, `false` otherwise.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.colorOf(context, 'surface'),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.colorOf(context, 'textPrimary'),
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.colorOf(context, 'textSecondary'),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.colorOf(context, 'textSecondary'),
                ),
              ),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.colorOf(context, 'primary'),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ],
    ),
  ).then((value) => value ?? false);
}
