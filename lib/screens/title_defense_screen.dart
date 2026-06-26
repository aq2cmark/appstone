import 'package:flutter/material.dart';

import '../app_colors.dart';

// Basic title defense practice flow.
// Students answer sample panel questions one by one.
class TitleDefenseScreen extends StatefulWidget {
  const TitleDefenseScreen({super.key});

  @override
  State<TitleDefenseScreen> createState() => _TitleDefenseScreenState();
}

class _TitleDefenseScreenState extends State<TitleDefenseScreen> {
  final answerController = TextEditingController();
  int questionIndex = 0;

  // Edit these questions if the panel practice needs different prompts.
  final List<String> questions = [
    'What is the main problem your capstone project aims to solve?',
    'How is your project different from existing solutions?',
    'What technology stack will you use and why?',
    'What are the scope and limitations of your project?',
    'What is your expected timeline?',
  ];

  // Shared tips shown under every question.
  final List<String> tips = [
    'Be specific.',
    'Explain who is affected.',
    'Give real-world examples.',
  ];

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questionNumber = questionIndex + 1;
    final progress = questionNumber / questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Title Defense'),
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
                  Text('Question $questionNumber of ${questions.length}'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          'DS',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text('Dr. Santos'),
                      subtitle: Text('Panel Member'),
                    ),
                  ),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PANEL QUESTION',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            questions[questionIndex],
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    color: const Color(0xFFFFF8E7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tips for answering',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          for (final tip in tips) Text('- $tip'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: answerController,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText:
                          'Your answer (${answerController.text.length} chars)',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: nextQuestion,
                    child: Text(
                      questionIndex == questions.length - 1
                          ? 'Finish'
                          : 'Next Question',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void nextQuestion() {
    // Move to the next question until the final one, then show completion.
    if (questionIndex < questions.length - 1) {
      setState(() {
        questionIndex++;
        answerController.clear();
      });
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Practice Complete'),
        content: const Text('You finished the Title Defense practice.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
