import 'package:flutter/material.dart';

import '../app_colors.dart';

class DefensePracticeScreen extends StatelessWidget {
  const DefensePracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Defense Practice'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose a mode and practice your defense.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          PracticeModeCard(
            title: 'Title Defense',
            subtitle: 'Practice defending your proposal and research plan.',
            details: '15-20 min | 5-8 questions',
            icon: Icons.chat_bubble_outline,
            color: AppColors.primary,
            onTap: () => Navigator.pushNamed(context, '/title-defense'),
          ),
          PracticeModeCard(
            title: 'Oral Defense',
            subtitle: 'Practice presenting your system design.',
            details: '30-45 min | 10-15 questions',
            icon: Icons.mic_none,
            color: AppColors.grey,
          ),
          PracticeModeCard(
            title: 'Final Defense',
            subtitle: 'Practice your full final presentation.',
            details: '45-60 min | 15-20 questions',
            icon: Icons.emoji_events_outlined,
            color: AppColors.gold,
          ),
        ],
      ),
    );
  }
}

class PracticeModeCard extends StatelessWidget {
  const PracticeModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String details;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          '$subtitle\n$details',
          style: const TextStyle(color: Colors.white70),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        onTap:
            onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title is not ready yet.')),
              );
            },
      ),
    );
  }
}
