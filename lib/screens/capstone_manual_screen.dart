import 'package:flutter/material.dart';

import '../app_colors.dart';

class CapstoneManualScreen extends StatelessWidget {
  const CapstoneManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sections = [
      ('01', 'Introduction', 'Overview and purpose'),
      ('02', 'Objectives', 'Goals and outcomes'),
      ('03', 'Scope and Limitations', 'Boundaries and constraints'),
      ('04', 'Guidelines and Procedures', 'Rules and submission steps'),
      ('05', 'Defense Preparation', 'Presentation tips and format'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Capstone Manual'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TextField(
            decoration: InputDecoration(
              hintText: 'Search manual...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'CONTENTS',
            style: TextStyle(
              color: AppColors.textGrey,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          for (final section in sections)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    section.$1,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(section.$2),
                subtitle: Text(section.$3),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${section.$2} content coming soon.'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
