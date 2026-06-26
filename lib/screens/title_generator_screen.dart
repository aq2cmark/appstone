import 'package:flutter/material.dart';

import '../app_colors.dart';

// Simple title generator mockup.
// It lets students select filters and shows sample/generated placeholder titles.
class TitleGeneratorScreen extends StatefulWidget {
  const TitleGeneratorScreen({super.key});

  @override
  State<TitleGeneratorScreen> createState() => _TitleGeneratorScreenState();
}

class _TitleGeneratorScreenState extends State<TitleGeneratorScreen> {
  final Set<String> selected = {};

  // Edit these lists to change the available filter chips.
  final List<String> projectTypes = [
    'Mobile Application',
    'Web Application',
    'Desktop Software',
    'IoT System',
  ];

  final List<String> targetUsers = [
    'Students',
    'Teachers',
    'Administrators',
    'Healthcare Workers',
  ];

  final List<String> problemAreas = [
    'Education',
    'Healthcare',
    'E-Commerce',
    'Agriculture',
  ];

  final List<String> technologies = [
    'Artificial Intelligence',
    'Machine Learning',
    'Blockchain',
    'Computer Vision',
  ];

  void toggle(String value) {
    // ChoiceChip selection is stored in a Set so each option is unique.
    setState(() {
      if (selected.contains(value)) {
        selected.remove(value);
      } else {
        selected.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Title Generator'),
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
                    'Select filters to get capstone title ideas.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  buildSection('PROJECT TYPE', projectTypes),
                  buildSection('TARGET USERS', targetUsers),
                  buildSection('PROBLEM AREA', problemAreas),
                  buildSection('TECHNOLOGY', technologies),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: showTitles,
                    icon: const Icon(Icons.bolt),
                    label: const Text('Generate Titles'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: randomTitle,
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Generate Random'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSection(String title, List<String> options) {
    // Reusable section builder for each filter group.
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in options)
                    ChoiceChip(
                      label: Text(option),
                      selected: selected.contains(option),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected.contains(option)
                            ? Colors.white
                            : AppColors.textDark,
                      ),
                      onSelected: (_) => toggle(option),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showTitles() {
    final text = selected.isEmpty
        ? 'Select at least one filter first.'
        : 'Sample title: ${selected.first} for Capstone Project Management';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generated Title'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void randomTitle() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Random Title'),
        content: const Text(
          'Mobile-Based Capstone Monitoring System for Students and Advisers',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
