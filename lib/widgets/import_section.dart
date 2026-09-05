import 'package:flutter/material.dart';
import '../colors.dart';

/// Callback fired when an import source is tapped.
typedef ImportSourceCallback = VoidCallback;

/// The "Import from" section with circular icon buttons:
/// Files, Drive, Scan, URL.
class ImportSection extends StatelessWidget {
  final ImportSourceCallback onFilesTap;
  final ImportSourceCallback onDriveTap;
  final ImportSourceCallback onScanTap;
  final ImportSourceCallback onUrlTap;

  const ImportSection({
    super.key,
    required this.onFilesTap,
    required this.onDriveTap,
    required this.onScanTap,
    required this.onUrlTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Text(
          'Import from',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.colorOf(context, 'textPrimary'),
          ),
        ),
        const SizedBox(height: 14),

        // Row of four circular buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ImportButton(
              icon: Icons.folder_open_rounded,
              label: 'Files',
              onTap: onFilesTap,
            ),
            _ImportButton(
              icon: Icons.cloud_rounded,
              label: 'Drive',
              onTap: onDriveTap,
            ),
            _ImportButton(
              icon: Icons.document_scanner_rounded,
              label: 'Scan',
              onTap: onScanTap,
            ),
            _ImportButton(
              icon: Icons.link_rounded,
              label: 'URL',
              onTap: onUrlTap,
            ),
          ],
        ),
      ],
    );
  }
}

/// A single circular icon button with a label underneath.
class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImportButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.colorOf(context, 'inputFill'),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 24,
              color: AppColors.colorOf(context, 'textSecondary'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.colorOf(context, 'textSecondary'),
            ),
          ),
        ],
      ),
    );
  }
}
