import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../providers/recent_files_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../models/recent_file.dart';
import '../widgets/confirm_dialog.dart';
import 'pro_screen.dart';


const String kPrivacyPolicyUrl = 'https://example.com/privacy';

const Color _grantedGreen = Color(0xFF3BA776);

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with WidgetsBindingObserver {
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

  Future<void> _refreshStorageStats() async {
    if (_docsPath.isEmpty) return;

    final imported = _importedFiles();
    var total = 0;
    for (final file in imported) {
      try {
        total += await File(file.path).length();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _importedCount = imported.length;
      _importedBytes = total;
    });
  }

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
      } catch (_) {}
    }
    if (!mounted) return;

    await context.read<RecentFilesProvider>().removePaths(
      imported.map((f) => f.path),
    );
    await _refreshStorageStats();

    if (!mounted) return;
    _showSnack('$deleted imported ${deleted == 1 ? 'file' : 'files'} deleted');
  }

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

  Future<void> _openPrivacyPolicy() async {
    try {
      final ok = await launchUrl(
        Uri.parse(kPrivacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        _showSnack('Could not open the privacy policy link');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not open the privacy policy link');
    }
  }

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
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }

  Widget _card(List<Widget> rows) {
    final colors = null;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTokens.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(children: rows),
    );
  }

  Widget _rowDivider() {
    final colors = null;
    return Divider(height: 1, thickness: 1, indent: 58, color: colors.border);
  }

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final colors = null;
    final resolvedIconColor = iconColor ?? colors.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.accentTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: resolvedIconColor),
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
                      color: titleColor ?? colors.textPrimary,
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
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }

  Widget _proCard() {
    final colors = null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(AppTokens.card),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'XPDF Pro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unlimited merge, split & scans',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colors = null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Reading'),
          _card([
            _row(
              icon: Icons.view_day_outlined,
              title: 'Page layout',
              subtitle: 'Applies to newly opened files',
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'single', label: Text('Single')),
                  ButtonSegment(value: 'continuous', label: Text('Scroll')),
                ],
                selected: {settings.pageLayoutMode},
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -2,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? colors.accent
                        : Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? Colors.white
                        : colors.textSecondary;
                  }),
                  side: WidgetStateBorderSide.resolveWith((states) {
                    return BorderSide(
                      color: states.contains(WidgetState.selected)
                          ? colors.accent
                          : colors.border,
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
                onChanged: settings.setRememberLastPage,
              ),
            ),
          ]),

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

          _sectionHeader('Privacy'),
          _card([
            _row(
              icon: Icons.cloud_off_rounded,
              title: 'Works fully offline',
              subtitle:
                  'Everything happens on your device — nothing is sent '
                  'to any server.',
            ),
            _rowDivider(),
            _row(
              icon: Icons.wifi_off_rounded,
              title: 'Only URL downloads use data',
              subtitle:
                  'Downloading a PDF from a link is the one feature that '
                  'uses the internet — and only when you choose to.',
            ),
            _rowDivider(),
            _row(
              icon: Icons.visibility_off_rounded,
              title: 'No ads, no tracking',
              subtitle: 'No analytics, no trackers, nothing sold.',
            ),
            _rowDivider(),
            _row(
              icon: Icons.no_accounts_rounded,
              title: 'No account needed',
              subtitle: 'Just open the app and read — no sign-up.',
            ),
            _rowDivider(),
            _row(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy policy',
              subtitle: 'The full policy, when you want more detail',
              trailing: Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: context.appColors.textSecondary,
              ),
              onTap: _openPrivacyPolicy,
            ),
          ]),

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
              iconColor: colors.accent,
              titleColor: colors.accent,
              onTap: _clearAllImportedFiles,
            ),
            _rowDivider(),
            _row(
              icon: Icons.history_rounded,
              title: 'Clear recent list',
              subtitle:
                  'Removes list entries only — files stay on your device',
              iconColor: colors.accent,
              titleColor: colors.accent,
              onTap: _clearRecentList,
            ),
          ]),

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
              iconColor: _cameraGranted ? _grantedGreen : colors.accent,
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
                    color: colors.accent,
                  ),
                ),
              ),
            ),
          ]),

          _sectionHeader('About'),
          _card([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.accentTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: colors.accent,
                      size: 24,
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
                                color: colors.textPrimary,
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
                                  color: colors.secondarySurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'v$_version',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.appColors.textSecondary,
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
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),

          _proCard(),
        ],
      ),
    );
  }
}
