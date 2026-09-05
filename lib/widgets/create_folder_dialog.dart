import 'package:flutter/material.dart';
import '../colors.dart';
import '../models/folder.dart';

/// Simple result of the create/rename folder dialog.
class FolderDraft {
  final String name;
  final String colorHex;
  const FolderDraft({required this.name, required this.colorHex});
}

/// Dialog for creating (or renaming/recoloring) a folder.
///
/// Shows a name field plus a fixed row of six color swatches from
/// [Folder.colorPalette] — no full color picker by design. Pass
/// [initialName]/[initialColorHex] to reuse it as a rename dialog, or
/// [showNameField]: false for a color-only picker (e.g. "Change color").
/// Pops with a [FolderDraft] on submit, or `null` when cancelled.
Future<FolderDraft?> showFolderDialog(
  BuildContext context, {
  String title = 'New Folder',
  String confirmLabel = 'Create',
  String? initialName,
  String? initialColorHex,
  bool showNameField = true,
}) {
  return showDialog<FolderDraft>(
    context: context,
    barrierDismissible: true,
    builder: (_) => FolderDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialColorHex: initialColorHex,
      showNameField: showNameField,
    ),
  );
}

class FolderDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String? initialName;
  final String? initialColorHex;

  /// When false the name field is hidden and the dialog acts purely as a
  /// color picker; [initialName] is echoed back unchanged in the result.
  final bool showNameField;

  const FolderDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialName,
    this.initialColorHex,
    this.showNameField = true,
  });

  @override
  State<FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<FolderDialog> {
  late final TextEditingController _controller;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _selectedColor =
        widget.initialColorHex ?? Folder.colorPalette.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Submit is allowed when the name field is hidden (name is carried over
  /// unchanged) or when it holds non-blank text.
  bool get _canSubmit =>
      !widget.showNameField || _controller.text.trim().isNotEmpty;

  void _submit() {
    final name = widget.showNameField
        ? _controller.text.trim()
        : (widget.initialName ?? '').trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      FolderDraft(name: name, colorHex: _selectedColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.colorOf(context, 'surface'),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        widget.title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.colorOf(context, 'textPrimary'),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showNameField) ...[
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 15,
                color: AppColors.colorOf(context, 'textPrimary'),
              ),
              decoration: InputDecoration(
                hintText: 'Folder name',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.colorOf(context, 'textMuted'),
                ),
                prefixIcon: Icon(
                  Icons.folder_rounded,
                  color: AppColors.colorOf(context, 'textMuted'),
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.colorOf(context, 'inputFill'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Color swatches — tap to pick, ring marks the selection.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: Folder.colorPalette.map((hex) {
              final isSelected = hex == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.colorOf(context, 'textPrimary')
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Folder.colorFromHex(hex),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.colorOf(context, 'textSecondary'),
                ),
              ),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.colorOf(context, 'primary'),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.colorOf(context, 'primary').withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ],
    );
  }
}
