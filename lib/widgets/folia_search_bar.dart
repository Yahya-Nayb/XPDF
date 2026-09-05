import 'package:flutter/material.dart';
import '../colors.dart';

/// The search bar at the top of the home screen.
///
/// This is a **stateless** widget — the search query and controller live in
/// `HomeScreen` (the parent StatefulWidget) because that's where the filtering
/// logic and setState live. This widget just renders the visual input.
class FoliaSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const FoliaSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.colorOf(context, 'inputFill'),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 15,
          color: AppColors.colorOf(context, 'textPrimary'),
        ),
        decoration: InputDecoration(
          hintText: 'Search files',
          hintStyle: TextStyle(
            fontSize: 15,
            color: AppColors.colorOf(context, 'textMuted'),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.colorOf(context, 'textMuted'),
            size: 22,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 48,
          ),
          // Show a clear button only when there's text
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.colorOf(context, 'textMuted'),
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onClear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
