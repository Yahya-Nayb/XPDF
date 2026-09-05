import 'package:flutter/material.dart';
import '../colors.dart';

/// Small message shown when the search query matches no files.
class NoSearchResults extends StatelessWidget {
  final String query;

  const NoSearchResults({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.colorOf(context, 'textMuted'),
            ),
            const SizedBox(height: 16),
            Text(
              'No files match your search',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.colorOf(context, 'textSecondary'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '"$query"',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.colorOf(context, 'textMuted'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
