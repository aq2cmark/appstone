import 'package:appstone/screens/login_page.dart';
import 'package:appstone/services/admin_repository.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final features = [
      ('Capstone Manual', 'Read guidelines and requirements', Icons.menu_book),
      ('Title Generator', 'Coming soon', Icons.lightbulb_outline),
      ('Defense Practice', 'Coming soon', Icons.shield_outlined),
      ('AI Workflow', 'Coming soon', Icons.calendar_month),
      ('Paper Checker', 'Coming soon', Icons.description_outlined),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        title: const Text('Student Dashboard'),
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
          const Text(
            'AppStone',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('Dominican College of Tarlac'),
          const SizedBox(height: 20),
          for (final feature in features)
            Card(
              child: ListTile(
                leading: Icon(feature.$3, color: AppColors.red),
                title: Text(feature.$1),
                subtitle: Text(feature.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${feature.$1} is not ready yet.')),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
