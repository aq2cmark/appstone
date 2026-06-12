import 'package:flutter/material.dart';

import '../app_colors.dart';

class PaperCheckerScreen extends StatefulWidget {
  const PaperCheckerScreen({super.key});

  @override
  State<PaperCheckerScreen> createState() => _PaperCheckerScreenState();
}

class _PaperCheckerScreenState extends State<PaperCheckerScreen> {
  bool checked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Paper Checker'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Upload and check your capstone paper format.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.upload_file,
                    color: AppColors.primary,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap to select document',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PDF, DOC, DOCX - Max 10MB',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('File picker not connected yet.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select File'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              setState(() => checked = true);
            },
            icon: const Icon(Icons.fact_check),
            label: const Text('Run Basic Check'),
          ),
          if (checked) ...[
            const SizedBox(height: 16),
            const Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Title page'),
                    subtitle: Text('Ready for review'),
                  ),
                  ListTile(
                    leading: Icon(Icons.warning, color: Colors.orange),
                    title: Text('Margins and spacing'),
                    subtitle: Text('Manual checking still needed'),
                  ),
                  ListTile(
                    leading: Icon(Icons.warning, color: Colors.orange),
                    title: Text('References'),
                    subtitle: Text('Manual checking still needed'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
