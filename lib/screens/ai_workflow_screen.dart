import 'package:flutter/material.dart';

import '../app_colors.dart';

class AIWorkflowScreen extends StatefulWidget {
  const AIWorkflowScreen({super.key});

  @override
  State<AIWorkflowScreen> createState() => _AIWorkflowScreenState();
}

class _AIWorkflowScreenState extends State<AIWorkflowScreen> {
  final List<String> tasks = [
    'Chapter 1 - Introduction',
    'Chapter 2 - Review of Related Literature',
    'Chapter 3 - Methodology',
    'Prototype Development',
    'Final Defense Preparation',
  ];

  final Set<String> done = {};

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
          const Text(
            'Plan and track your capstone timeline.',
            style: TextStyle(fontSize: 16),
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
              child: CheckboxListTile(
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI suggestions coming soon.')),
              );
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Workflow Suggestions'),
          ),
        ],
      ),
    );
  }
}
