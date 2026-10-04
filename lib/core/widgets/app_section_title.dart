import 'package:flutter/material.dart';

/// A consistent section header title.
///
/// Use [AppSectionTitle] for section headers to maintain
/// uniform typography across the app.
class AppSectionTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const AppSectionTitle({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}