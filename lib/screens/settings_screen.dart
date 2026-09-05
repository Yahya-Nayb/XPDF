import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../colors.dart';
import '../models/recent_file.dart';
import '../providers/recent_files_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/confirm_dialog.dart';

/// Red used for destructive actions — matches the app's PDF-badge red so it
/// reads as "warning" without introducing a new palette color.
const Color _destructiveRed = Color(0xFFE0473C);

/// Green used for the "Granted" permission status — matches the folder
/// palette green.
const Color _grantedGreen = Color(0xFF3BA776);

/// The Settings tab content — grouped sections for Appearance, Reading,
/// Storage, Recent List, Permissions and About.
///
/// Embedded inside [HomeScreen]'s scroll view (nav index 3), like the
/// Library view. Because it's built conditionally, entering the tab
/// re-runs [initState] — storage stats and permission status are always
/// fresh on entry.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with WidgetsBindingObserver {
  // App documents directory prefix — files under it are local copies the
  // app created (URL downloads and scans); anything else is just referenced
  // from elsewhere on the device.
  String _docsPath = '';

  int _importedCount = 0;
  int _importedBytes = 0;

  PermissionStatus _cameraStatus = PermissionStatus.denied;
  String _version = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAsync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check camera status when returning from the system settings app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCameraStatus();
    }
  }

  Future<void> _initAsync() async {
    final docsDir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    setState(() => _docsPath = docsDir.path);

    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);

    await _refreshCameraStatus();
    await _refreshStorageStats();
  }

  Future<void> _refreshCameraStatus() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() => _cameraStatus = status);
  }

  bool get _cameraGranted =>
      _cameraStatus == PermissionStatus.granted ||
      _cameraStatus == PermissionStatus.limited;

  bool _isImported(RecentFile file) =>
      _docsPath.isNotEmpty && file.path.startsWith(_docsPath);

  List<RecentFile> _importedFiles() =>
      context.read<RecentFilesProvider>().files.where(_isImported).toList();

  /// Sum the real on-disk size of every imported file via File.length().
  /// Missing files (already deleted externally) are skipped silently.
  Future<void> _refreshStorageStats() async {
    if (_docsPath.isEmpty) return;

    final imported = _importedFiles();
    var total = 0;
    for (final file in imported) {
      try {
        total += await File(file.path).length();
      } catch (_) {
        // File missing or unreadable — contributes nothing to the total.
      }
    }

    if (!mounted) return;
    setState(() {
      _importedCount = imported.length;
      _importedBytes = total;
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Permanently delete the physical imported files (URL downloads and
  /// scans living in the app's documents directory), then drop their list
  /// entries. Files referenced from elsewhere on the device are untouched.
  Future<void> _clearAllImportedFiles() async {
    final imported = _importedFiles();
    if (imported.isEmpty) {
      _showSnack('No imported files to delete');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear all files?',
      message:
          'This permanently deletes ${imported.length} imported '
          '${imported.length == 1 ? 'file' : 'files'} (URL downloads and '
          'scans stored inside the app) from your device — not just the '
          'list. This cannot be undone.',
      confirmLabel: 'Delete Files',
    );
    if (!confirmed || !mounted) return;

    var deleted = 0;
    for (final file in imported) {
      try {
        await File(file.path).delete();
        deleted++;
      } catch (_) {
        // Already gone (or unreadable) — skip it, don't crash.
      }
    }
    if (!mounted) return;

    await context.read<RecentFilesProvider>().removePaths(
      imported.map((f) => f.path),
    );
    await _refreshStorageStats();

    if (!mounted) return;
    _showSnack('$deleted imported ${deleted == 1 ? 'file' : 'files'} deleted');
  }

  /// Empty the recent list WITHOUT touching any files on disk.
  Future<void> _clearRecentList() async {
    final count = context.read<RecentFilesProvider>().files.length;
    if (count == 0) {
      _showSnack('Recent list is already empty');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear recent list?',
      message:
          'This removes all $count ${count == 1 ? 'file' : 'files'} '
          'from your recent list. The files themselves won\'t be deleted '
          'from your device.',
      confirmLabel: 'Clear List',
    );
    if (!confirmed || !mounted) return;

    await context.read<RecentFilesProvider>().clearAll();
    if (!mounted) return;
    _showSnack('Recent list cleared');
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.colorOf(context, 'textMuted'),
        ),
      ),
    );
  }

  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorOf(context, 'card'),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.colorOf(context, 'border')),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(children: rows),
    );
  }

  Widget _rowDivider() => Divider(
    height: 1,
    thickness: 1,
    indent: 62,
    color: AppColors.colorOf(context, 'border'),
  );

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    (iconColor ?? AppColors.colorOf(context, 'textSecondary'))
                        .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? AppColors.colorOf(context, 'textSecondary'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          titleColor ??
                          AppColors.colorOf(context, 'textPrimary'),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.colorOf(context, 'textMuted'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Own header (the shared Home header is hidden on this tab) --
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
            ),
          ),

          // -- Appearance ---------------------------------------------------
          _sectionHeader('Appearance'),
          _card([
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return _row(
                  icon: themeProvider.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: 'Dark mode',
                  subtitle: 'Use the dark theme across the app',
                  trailing: Switch(
                    value: themeProvider.isDark,
                    onChanged: (_) => themeProvider.toggleTheme(),
                  ),
                );
              },
            ),
          ]),

          // -- Reading ------------------------------------------------------
          _sectionHeader('Reading'),
          _card([
            _row(
              icon: Icons.menu_book_rounded,
              title: 'Page layout',
              subtitle: 'Applies to newly opened files',
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'single', label: Text('Single')),
                  ButtonSegment(value: 'continuous', label: Text('Scroll')),
                ],
                selected: {settings.pageLayoutMode},
                showSelectedIcon: false,
                // M3's default selected color comes from
                // colorScheme.secondary, which this app never overrides —
                // that's why it rendered as framework teal. Pin every
                // selected state to AppColors.primary; colorOf() picks the
                // correct variant for dark mode automatically.
                style: ButtonStyle(
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -2,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? AppColors.colorOf(context, 'primary')
                        : Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? Colors.white
                        : AppColors.colorOf(context, 'textMuted');
                  }),
                  side: WidgetStateBorderSide.resolveWith((states) {
                    return BorderSide(
                      color: states.contains(WidgetState.selected)
                          ? AppColors.colorOf(context, 'primary')
                          : AppColors.colorOf(context, 'border'),
                    );
                  }),
                ),
                onSelectionChanged: (selection) =>
                    settings.setPageLayoutMode(selection.first),
              ),
            ),
            _rowDivider(),
            _row(
              icon: Icons.bookmark_added_rounded,
              title: 'Remember last page',
              subtitle: 'Reopen files where you left off',
              trailing: Switch(
                value: settings.rememberLastPage,
                onChanged: (value) => settings.setRememberLastPage(value),
              ),
            ),
          ]),

          // -- Storage ------------------------------------------------------
          _sectionHeader('Storage'),
          _card([
            _row(
              icon: Icons.folder_copy_rounded,
              title: 'Imported files',
              subtitle: _docsPath.isEmpty
                  ? 'Calculating…'
                  : _importedCount == 0
                  ? 'No imported files yet'
                  : '${_formatBytes(_importedBytes)} · '
                        '$_importedCount '
                        '${_importedCount == 1 ? 'file' : 'files'} stored '
                        'in the app',
            ),
            _rowDivider(),
            _row(
              icon: Icons.delete_sweep_rounded,
              title: 'Clear all imported files',
              subtitle: 'Permanently deletes downloaded & scanned copies',
              iconColor: _destructiveRed,
              titleColor: _destructiveRed,
              onTap: _clearAllImportedFiles,
            ),
          ]),

          // -- Recent list ----------------------------------------------------
          _sectionHeader('Recent List'),
          _card([
            _row(
              icon: Icons.history_rounded,
              title: 'Clear recent list',
              subtitle:
                  'Removes list entries only — files stay on your '
                  'device',
              iconColor: _destructiveRed,
              titleColor: _destructiveRed,
              onTap: _clearRecentList,
            ),
          ]),

          // -- Permissions ----------------------------------------------------
          _sectionHeader('Permissions'),
          _card([
            _row(
              icon: Icons.photo_camera_rounded,
              title: 'Camera',
              subtitle: _cameraGranted
                  ? 'Granted'
                  : _cameraStatus == PermissionStatus.permanentlyDenied
                  ? 'Denied permanently'
                  : 'Denied',
              iconColor: _cameraGranted ? _grantedGreen : _destructiveRed,
              titleColor: _cameraGranted
                  ? null
                  : AppColors.colorOf(context, 'textPrimary'),
              trailing: TextButton(
                onPressed: openAppSettings,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Open Settings',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorOf(context, 'primary'),
                  ),
                ),
              ),
            ),
          ]),

          // -- About ----------------------------------------------------------
          _sectionHeader('About'),
          _card([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.colorOf(context, 'pdfBadgeBg'),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.colorOf(context, 'pdfIcon'),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'XPDF',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.colorOf(
                                  context,
                                  'textPrimary',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_version.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.colorOf(
                                    context,
                                    'inputFill',
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'v$_version',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.colorOf(
                                      context,
                                      'textSecondary',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A minimal, ad-free PDF reader.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.colorOf(context, 'textMuted'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
