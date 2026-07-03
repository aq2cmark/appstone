import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';
import 'login_page.dart' hide AppColors;

// Student dashboard after login.
// It receives the student and group names from LoginPage after credentials pass.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.studentName,
    required this.groupName,
    required this.isPremium,
    required this.groupId,
    required this.studentId,
  });

  final String studentName;
  final String groupName;
  final bool isPremium;
  final String groupId;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXPLORE FEATURES',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FeatureTile(
                            title: 'Capstone Manual',
                            subtitle: 'Read guidelines and requirements',
                            icon: Icons.menu_book_outlined,
                            color: AppColors.primary,
                            route: '/capstone-manual',
                            isPremiumAccount: isPremium,
                          ),
                          FeatureTile(
                            title: 'Title Generator',
                            subtitle: 'AI-powered topic ideas',
                            icon: Icons.lightbulb_outline,
                            color: AppColors.grey,
                            route: '/title-generator',
                            isPremiumAccount: isPremium,
                          ),
                          FeatureTile(
                            title: 'Defense Practice',
                            subtitle: 'Gamified simulation mode',
                            icon: Icons.shield_outlined,
                            color: AppColors.primary,
                            route: '/defense-practice',
                            isPremiumAccount: isPremium,
                            requiresPremium: true,
                          ),
                          FeatureTile(
                            title: 'AI Workflow',
                            subtitle: 'Plan and track your timeline',
                            icon: Icons.calendar_month_outlined,
                            color: AppColors.grey,
                            route: '/ai-workflow',
                            isPremiumAccount: isPremium,
                            requiresPremium: true,
                          ),
                          FeatureTile(
                            title: 'Paper Checker',
                            subtitle: 'Check compliance and format',
                            icon: Icons.description_outlined,
                            color: AppColors.gold,
                            route: '/paper-checker',
                            isPremiumAccount: isPremium,
                            requiresPremium: true,
                          ),
                        ],
                      ),
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

  Widget buildHeader(BuildContext context) {
    // The header is intentionally just a Container plus a few Text widgets.
    // This keeps the student landing page close to the mockup but easy to edit.
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Change password',
                      onPressed: () => showChangePasswordDialog(context),
                      icon: const Icon(Icons.lock_reset, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: () async {
                        await AdminRepository().signOut();
                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                studentName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  buildPill(groupName),
                  buildPill('DCT'),
                  buildPill('2026-2027'),
                  if (isPremium) buildPill('Premium'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
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
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldChange != true) {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
      return;
    }

    final currentPassword = currentController.text;
    final newPassword = newController.text;
    final confirmPassword = confirmController.text;
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (newPassword != confirmPassword) {
      showMessage(context, 'New passwords do not match.');
      return;
    }

    try {
      await AdminRepository().changeStudentPassword(
        groupId: groupId,
        studentId: studentId,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!context.mounted) return;
      showMessage(context, 'Password changed.');
    } catch (error) {
      if (!context.mounted) return;
      showMessage(context, error.toString());
    }
  }

  void showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  // Reusable dashboard row.
  // Premium-only features call showPremiumMessage instead of opening a page.
  const FeatureTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isPremiumAccount,
    this.route,
    this.requiresPremium = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isPremiumAccount;
  final bool requiresPremium;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final locked = requiresPremium && !isPremiumAccount;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (locked) {
            showPremiumMessage(context);
            return;
          }
          if (route == null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$title is not ready yet.')));
            return;
          }
          Navigator.pushNamed(context, route!);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (locked)
                          const Icon(
                            Icons.lock_outline,
                            size: 30,
                            color: AppColors.gold,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.background,
                child: Icon(
                  Icons.chevron_right,
                  color: locked ? AppColors.gold : AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showPremiumMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avail premium to access this feature.')),
    );
  }
}
