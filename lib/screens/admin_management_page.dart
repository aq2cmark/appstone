import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';
import '../services/functions_service.dart';
import 'owner_transfer_confirm_page.dart';

// Owner-only page to manage who has admin access. Owners can invite new admins
// (by email), turn access on/off, change roles, and remove records. Deactivating
// is the normal way to remove someone - it revokes access instantly without
// touching their Firebase Auth login.
class AdminManagementPage extends StatelessWidget {
  const AdminManagementPage({
    super.key,
    required this.repo,
    required this.currentEmail,
  });

  final AdminRepository repo;
  // The signed-in owner's email, so their own row can't be self-deactivated.
  final String currentEmail;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminAccount>>(
      stream: repo.adminsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final admins = snapshot.data!;
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
                      'Admin access',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Invite an admin by email. They then open "Invited as an '
                      'admin? Create your account" on the login screen, verify '
                      'the email via a link we send them, and set their '
                      'password. To remove someone, deactivate them - that '
                      'cuts off access immediately without deleting anything.',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () => _invite(context),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Invite Admin'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final admin in admins) _buildAdminCard(context, admin),
          ],
        );
      },
    );
  }

  Widget _buildAdminCard(BuildContext context, AdminAccount admin) {
    final isSelf = admin.email == currentEmail.toLowerCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  admin.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isSelf) _chip('You', AppColors.grey),
                _chip(
                  admin.isOwner ? 'Owner' : 'Admin',
                  admin.isOwner ? AppColors.gold : AppColors.primary,
                ),
                if (!admin.active)
                  _chip('Deactivated', Colors.red)
                else if (admin.isPending)
                  _chip('Invited - not signed up', AppColors.grey)
                else
                  _chip('Active', Colors.green),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              admin.email,
              style: const TextStyle(color: AppColors.textGrey),
            ),
            if (!isSelf) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Only one owner can exist, and it is always the caller
                  // viewing this owner-only page - so any other row here is
                  // never already an owner, and this only ever offers to
                  // transfer ownership away, never to demote one.
                  OutlinedButton.icon(
                    onPressed: () => _transferOwnership(context, admin),
                    icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                    label: const Text('Make Owner'),
                  ),
                  if (admin.active)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () => _setActive(context, admin, false),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Deactivate'),
                    )
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                      onPressed: () => _setActive(context, admin, true),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Reactivate'),
                    ),
                  IconButton(
                    tooltip: 'Remove record',
                    onPressed: () => _delete(context, admin),
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _invite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    // Invites are always plain admins - only the ownership-transfer flow
    // below can ever produce an owner, so there is no role picker here.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    nameController.dispose();
    emailController.dispose();
    if (confirmed != true) return;

    try {
      await FunctionsService().inviteAdmin(email: email, name: name);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Invited $email. They will get an email with a link to set their password.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  // Ownership can only move via this confirmed, email-verified handoff:
  // an "are you sure" dialog here, then a Firebase sign-in link emailed to
  // the CURRENT owner's own inbox that must be opened and confirmed before
  // the role swap actually happens (see OwnerTransferConfirmPage). That way
  // neither a stolen nor a merely-left-open owner session is enough on its
  // own to hand off ownership.
  Future<void> _transferOwnership(BuildContext context, AdminAccount admin) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await _confirm(
      context,
      title: 'Transfer ownership to ${admin.name}?',
      body: 'Only one owner can exist at a time. You will move to the Admin '
          'role and ${admin.email} will become the new owner. We will email '
          'you (the current owner) a confirmation link first - the transfer '
          'only happens once you open it and confirm.',
      action: 'Send Confirmation Email',
    );
    if (!confirm) return;

    try {
      await repo.requestOwnershipTransfer(
        ownerEmail: currentEmail,
        toEmail: admin.email,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ownerTransferEmailPrefsKey,
        currentEmail.toLowerCase(),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Check $currentEmail for a confirmation link to finish the transfer.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _setActive(
    BuildContext context,
    AdminAccount admin,
    bool active,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!active) {
      final confirm = await _confirm(
        context,
        title: 'Deactivate ${admin.name}?',
        body: 'They will lose admin access immediately. You can reactivate them '
            'later. Their Firebase login is not deleted.',
        action: 'Deactivate',
      );
      if (!confirm) return;
    }
    try {
      await repo.setAdminActive(email: admin.email, active: active);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            active ? 'Reactivated ${admin.name}.' : 'Deactivated ${admin.name}.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _delete(BuildContext context, AdminAccount admin) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await _confirm(
      context,
      title: 'Remove ${admin.name}?',
      body: 'This deletes their admin record. If they already have a Firebase '
          'login, you also need to delete it in the Firebase console to fully '
          'remove them. Deactivating is usually enough.',
      action: 'Remove',
    );
    if (!confirm) return;
    try {
      await repo.deleteAdmin(admin.email);
      messenger.showSnackBar(SnackBar(content: Text('Removed ${admin.name}.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
