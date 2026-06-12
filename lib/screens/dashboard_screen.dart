import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';
import 'login_page.dart' hide AppColors;

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.studentName,
    required this.groupName,
  });

  final String studentName;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('AppStone'),
        actions: [
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
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$groupName - 2026-2027',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'EXPLORE FEATURES',
            style: TextStyle(
              color: AppColors.textGrey,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          FeatureTile(
            title: 'Capstone Manual',
            subtitle: 'Read guidelines and requirements',
            icon: Icons.menu_book_outlined,
            color: AppColors.primary,
            route: '/capstone-manual',
          ),
          FeatureTile(
            title: 'Title Generator',
            subtitle: 'AI-powered topic ideas',
            icon: Icons.lightbulb_outline,
            color: AppColors.grey,
            route: '/title-generator',
          ),
          FeatureTile(
            title: 'Defense Practice',
            subtitle: 'Practice your capstone defense',
            icon: Icons.shield_outlined,
            color: AppColors.primary,
            route: '/defense-practice',
          ),
          FeatureTile(
            title: 'AI Workflow',
            subtitle: 'Plan and track your timeline',
            icon: Icons.calendar_month_outlined,
            color: AppColors.grey,
            route: '/ai-workflow',
          ),
          FeatureTile(
            title: 'Paper Checker',
            subtitle: 'Check compliance and format',
            icon: Icons.description_outlined,
            color: AppColors.gold,
            route: '/paper-checker',
          ),
        ],
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (route == null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$title is not ready yet.')));
            return;
          }
          Navigator.pushNamed(context, route!);
        },
      ),
    );
  }
}
