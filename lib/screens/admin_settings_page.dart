import 'package:flutter/material.dart';

import '../services/admin_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/states/app_states.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({
    super.key,
    required this.repo,
    required this.maxGroupMembers,
    required this.onMaxGroupMembersChanged,
  });

  final AdminRepository repo;
  final int maxGroupMembers;
  final ValueChanged<int> onMaxGroupMembersChanged;

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.maxGroupMembers}',
  );
  bool _saving = false;

  @override
  void didUpdateWidget(covariant AdminSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxGroupMembers != widget.maxGroupMembers && !_saving) {
      _controller.text = '${widget.maxGroupMembers}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(_controller.text.trim());
    if (value == null ||
        value < AdminRepository.minimumMaxGroupMembers ||
        value > AdminRepository.maximumMaxGroupMembers) {
      showMessageSnack(
        context,
        'Enter a whole number from ${AdminRepository.minimumMaxGroupMembers} '
        'to ${AdminRepository.maximumMaxGroupMembers}.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repo.setMaxGroupMembers(value);
      if (!mounted) return;
      widget.onMaxGroupMembersChanged(value);
      showMessageSnack(context, 'Maximum group size updated.');
    } catch (error) {
      if (mounted) showMessageSnack(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group capacity',
                  style: AppTypography.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                AppSpacing.vSm,
                Text(
                  'Set the maximum number of students allowed in each group. '
                  'This applies to new registrations and bulk imports. '
                  'Existing groups above a lowered limit remain unchanged, '
                  'but cannot accept more students until they are below it.',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                AppSpacing.vLg,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: TextField(
                    controller: _controller,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Maximum members per group',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                AppSpacing.vMd,
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving...' : 'Save setting'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
