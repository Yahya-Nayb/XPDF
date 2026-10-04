import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';

/// A preview screen showing all reusable design system widgets
/// in both light and dark modes.
class DesignPreviewScreen extends StatelessWidget {
  const DesignPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Design Preview'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Light'),
              Tab(text: 'Dark'),
            ],
          ),
        ),
        floatingActionButton: const GradientFab(tooltip: 'Add'),
        body: TabBarView(
          children: [
            _PreviewContent(brightness: Brightness.light),
            _PreviewContent(brightness: Brightness.dark),
          ],
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  final Brightness brightness;

  const _PreviewContent({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
      child: Builder(
        builder: (context) {
          final ext = context.appColors;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle(title: 'Cards'),
                AppCard(
                  child: const Text('This is an AppCard with surface styling'),
                ),
                const SizedBox(height: AppTokens.lg),
                const AppSectionTitle(title: 'Primary Action'),
                PrimaryActionTile(
                  icon: Icons.file_download_outlined,
                  title: 'Import PDF',
                  onTap: () {},
                ),
                const SizedBox(height: AppTokens.lg),
                const AppSectionTitle(title: 'Feature Tiles'),
                FeatureTile(
                  icon: Icons.crop,
                  title: 'Split PDF',
                  subtitle: 'Split into multiple files',
                  featureColor: ext.split,
                ),
                const SizedBox(height: AppTokens.md),
                FeatureTile(
                  icon: Icons.merge_type,
                  title: 'Merge PDF',
                  subtitle: 'Combine multiple files',
                  featureColor: ext.merge,
                ),
                const SizedBox(height: AppTokens.md),
                FeatureTile(
                  icon: Icons.image_outlined,
                  title: 'Images to PDF',
                  subtitle: 'Convert images',
                  featureColor: ext.images,
                ),
                const SizedBox(height: AppTokens.md),
                FeatureTile(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scan PDF',
                  subtitle: 'Scan documents',
                  featureColor: ext.scan,
                ),
                const SizedBox(height: AppTokens.lg),
                const AppSectionTitle(title: 'Empty State'),
                const SizedBox(
                  height: 250,
                  child: EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'No Files Yet',
                    message: 'Import your first PDF to get started',
                  ),
                ),
                const SizedBox(height: AppTokens.lg),
                const AppSectionTitle(title: 'Loading'),
                const Center(child: GradientLoader(size: 48)),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}