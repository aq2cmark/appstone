import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../app_colors.dart';

// Simple workflow tracker screen.
// This is local-only for now; checked tasks reset when the screen is reopened.
class AIWorkflowScreen extends StatefulWidget {
  const AIWorkflowScreen({super.key});

  @override
  State<AIWorkflowScreen> createState() => _AIWorkflowScreenState();
}

class _AIWorkflowScreenState extends State<AIWorkflowScreen> {
  // Edit this list to change the default capstone timeline steps.
  final List<String> tasks = [
    'Chapter 1 - Introduction',
    'Chapter 2 - Review of Related Literature',
    'Chapter 3 - Methodology',
    'Prototype Development',
    'Final Defense Preparation',
  ];

  final Set<String> done = {};
  PlatformFile? selectedPaper;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('AI Workflow'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Plan and track your capstone timeline.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Paper',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            selectedPaper?.name ??
                                'Add your current paper so workflow suggestions can be based on it later.',
                            style: const TextStyle(color: AppColors.textGrey),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: pickPaper,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Select Paper'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: done.length / tasks.length,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text('${done.length} of ${tasks.length} tasks completed'),
                  const SizedBox(height: 16),
                  for (final task in tasks)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        activeColor: AppColors.primary,
                        value: done.contains(task),
                        title: Text(task),
                        subtitle: const Text('Tap to mark as done'),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              done.add(task);
                            } else {
                              done.remove(task);
                            }
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedPaper == null
                                ? 'AI suggestions coming soon. You can also upload a paper first.'
                                : 'AI suggestions for ${selectedPaper!.name} coming soon.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate Workflow Suggestions'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> pickPaper() async {
    // This only stores the selected filename for now.
    // Later you can upload the file to Firebase Storage or send it to an AI API.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;
    setState(() => selectedPaper = result.files.single);
  }
}
