import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'states/app_states.dart';

/// One credential value with a copy button.
///
/// Admins read these out to students or paste them into a message. They were
/// previously plain selectable text, which meant drag-selecting an 8-character
/// password without catching the surrounding words - easy to get wrong, and the
/// temporary password cannot be retrieved again once the student changes it.
///
/// The value is rendered in a monospaced face so 0/O and 1/l/I are
/// distinguishable, which matters when the string is being transcribed.
class CredentialValue extends StatelessWidget {
  const CredentialValue({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;

  /// Renders larger, for the one value on screen that matters most.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: AppTypography.eyebrow.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
                AppSpacing.vXs,
                SelectableText(
                  value,
                  style: AppTypography.numeric.copyWith(
                    fontSize: emphasis ? 20 : 16,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.hSm,
          IconButton(
            tooltip: 'Copy $label',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => copyToClipboard(context, value, label: label),
          ),
        ],
      ),
    );
  }
}

/// Copies [text] and confirms it, so the admin knows the click registered.
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  String label = 'Value',
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  showMessageSnack(context, '$label copied.');
}
