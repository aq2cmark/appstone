import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';

// Owner-only page showing a newest-first history of admin actions (who did
// what, and when) recorded by AdminRepository into the append-only
// `audit_logs` collection. It mirrors the AdminManagementPage layout: a live
// StreamBuilder over the repository, an intro card, then one row per entry.
class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key, required this.repo});

  final AdminRepository repo;

  // Formats an entry timestamp like "Jul 9, 2026 · 2:41 PM". Entries whose
  // server timestamp hasn't resolved yet (a brief moment right after the
  // action) show a placeholder instead.
  static final _dateFormat = DateFormat('MMM d, y · h:mm a');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AuditLogEntry>>(
      stream: repo.auditLogStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity log',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A record of admin actions - group and student changes, '
                      'password resets, and admin access changes - with who '
                      'made each change and when. Newest actions appear first. '
                      'Entries cannot be edited or removed.',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No admin activity recorded yet.'),
                ),
              )
            else
              for (final entry in entries) _buildEntryCard(entry),
          ],
        );
      },
    );
  }

  Widget _buildEntryCard(AuditLogEntry entry) {
    final (icon, color) = _visualsFor(entry.category);
    final when = entry.createdAt == null
        ? 'Just now'
        : _dateFormat.format(entry.createdAt!.toLocal());

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
                      _meta(Icons.person_outline, entry.actorEmail),
                      _meta(Icons.schedule, when),
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

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textGrey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
        ),
      ],
    );
  }

  // Maps an action category to a row icon + colour so scanning the log by
  // kind of change is easy. Unknown categories fall back to a neutral icon.
  (IconData, Color) _visualsFor(String category) {
    switch (category) {
      case 'group':
        return (Icons.groups, AppColors.primary);
      case 'student':
        return (Icons.person, AppColors.gold);
      case 'admin':
        return (Icons.admin_panel_settings, AppColors.primaryDark);
      default:
        return (Icons.history, AppColors.grey);
    }
  }
}
