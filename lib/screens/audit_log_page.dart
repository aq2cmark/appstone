import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/states/app_states.dart';
import '../widgets/states/skeleton.dart';
import '../services/admin_repository.dart';

/// Owner-only history of admin actions, recorded by AdminRepository into the
/// append-only `audit_logs` collection.
///
/// Entries arrive newest-first. They are grouped under day headings and can be
/// narrowed by category, because a flat list of up to 200 rows made "what
/// changed this week" almost impossible to answer by eye.
class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key, required this.repo});

  final AdminRepository repo;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  /// Formats an entry time like "2:41 PM". The date lives in the day heading,
  /// so repeating it on every row would be noise.
  static final _timeFormat = DateFormat('h:mm a');
  static final _dayFormat = DateFormat('EEEE, MMM d, y');

  /// null = every category.
  String? _category;

  static const _categories = <String, String>{
    'group': 'Groups',
    'student': 'Students',
    'admin': 'Admins',
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return StreamBuilder<List<AuditLogEntry>>(
      stream: widget.repo.auditLogStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppErrorView(
            error: snapshot.error,
            title: 'Could not load the activity log',
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return Skeleton(
            child: ListView(
              padding: EdgeInsets.all(AppSpacing.xl),
              children: const [
                SkeletonCard(lines: 2, showTile: false),
                SizedBox(height: AppSpacing.lg),
                SkeletonList(count: 6, lines: 2),
              ],
            ),
          );
        }

        final all = snapshot.data!;
        final entries = _category == null
            ? all
            : all.where((e) => e.category == _category).toList();

        return ListView(
          padding: EdgeInsets.all(AppSpacing.xl),
          children: [
            _buildIntro(colors, all),
            AppSpacing.vLg,
            _buildFilters(colors, all),
            AppSpacing.vLg,
            if (all.isEmpty)
              AppEmptyView(
                icon: Icons.history_rounded,
                accent: colors.admin,
                title: 'No activity yet',
                body: 'Group and student changes, password resets and admin '
                    'access changes will appear here as they happen.',
              )
            else if (entries.isEmpty)
              AppEmptyView(
                icon: Icons.filter_alt_off_rounded,
                accent: colors.admin,
                title: 'Nothing in this category',
                body: 'No ${_categories[_category]?.toLowerCase()} activity has '
                    'been recorded yet.',
              )
            else
              ..._buildGroupedEntries(colors, entries),
          ],
        );
      },
    );
  }

  Widget _buildIntro(AppColors colors, List<AuditLogEntry> all) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_rounded, color: colors.admin),
            AppSpacing.hLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity log',
                    style: AppTypography.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  AppSpacing.vXs,
                  Text(
                    'Who changed what, and when. Entries are append-only - they '
                    'cannot be edited or removed, including by an owner.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(AppColors colors, List<AuditLogEntry> all) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ChoiceChip(
          label: Text('All (${all.length})'),
          selected: _category == null,
          onSelected: (_) => setState(() => _category = null),
        ),
        for (final entry in _categories.entries)
          ChoiceChip(
            label: Text(
              '${entry.value} '
              '(${all.where((e) => e.category == entry.key).length})',
            ),
            selected: _category == entry.key,
            onSelected: (_) => setState(() => _category = entry.key),
          ),
      ],
    );
  }

  /// Entries under "Today" / "Yesterday" / full-date headings.
  ///
  /// The stream is already newest-first, so a single pass preserves order
  /// without re-sorting.
  List<Widget> _buildGroupedEntries(
    AppColors colors,
    List<AuditLogEntry> entries,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final widgets = <Widget>[];
    String? currentHeading;

    for (final entry in entries) {
      final at = entry.createdAt?.toLocal();
      final String heading;
      if (at == null) {
        // A server timestamp that has not resolved yet - the action happened
        // moments ago.
        heading = 'Just now';
      } else {
        final day = DateTime(at.year, at.month, at.day);
        final diff = today.difference(day).inDays;
        heading = diff == 0
            ? 'Today'
            : diff == 1
                ? 'Yesterday'
                : _dayFormat.format(at);
      }

      if (heading != currentHeading) {
        currentHeading = heading;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: widgets.isEmpty ? 0 : AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              heading.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(color: colors.admin),
            ),
          ),
        );
      }

      widgets.add(_buildEntryCard(colors, entry));
    }

    return widgets;
  }

  Widget _buildEntryCard(AppColors colors, AuditLogEntry entry) {
    final (icon, color) = _visualsFor(colors, entry.category);
    // Time only - the date is carried by the day heading above this row.
    final when = entry.createdAt == null
        ? 'Just now'
        : _timeFormat.format(entry.createdAt!.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _meta(colors, Icons.person_outline, entry.actorEmail),
                      _meta(colors, Icons.schedule_rounded, when),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(AppColors colors, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  // Maps an action category to a row icon + colour so scanning the log by
  // kind of change is easy. Unknown categories fall back to a neutral icon.
  (IconData, Color) _visualsFor(AppColors colors, String category) {
    switch (category) {
      case 'group':
        return (Icons.groups_rounded, colors.brand);
      case 'student':
        return (Icons.person_rounded, colors.premium);
      case 'admin':
        return (Icons.admin_panel_settings_rounded, colors.brandStrong);
      default:
        return (Icons.history_rounded, colors.textSecondary);
    }
  }
}
