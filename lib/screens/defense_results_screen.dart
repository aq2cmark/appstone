import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/defense_ai_service.dart';
import 'title_defense_screen.dart';

// Shown after a defense practice session ends.
// Score comes from DefenseAiService.scoreSession, computed once all
// questions (generic + any AI follow-ups) have been answered.
class DefenseResultsScreen extends StatelessWidget {
  const DefenseResultsScreen({
    super.key,
    required this.title,
    required this.questions,
    required this.maxQuestions,
    required this.secondsPerQuestion,
    required this.questionsAnswered,
    required this.score,
  });

  final String title;
  final List<String> questions;
  final int maxQuestions;
  // Carried through so "Practice Again" starts with the same question timer.
  final int secondsPerQuestion;
  final int questionsAnswered;
  final DefenseScore score;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Session Complete'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: AppColors.gold,
                    size: 56,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scoreHeadline(score.overall),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You've completed the $title practice.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'OVERALL PERFORMANCE SCORE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${score.overall}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$questionsAnswered questions answered',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(title),
                            backgroundColor: Colors.white24,
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EVALUATION METRICS',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          buildMetricRow('Clarity', score.clarity),
                          buildMetricRow('Technical', score.technical),
                          buildMetricRow('Confidence', score.confidence),
                          buildMetricRow('Completeness', score.completeness),
                          buildMetricRow('Presentation', score.presentation),
                        ],
                      ),
                    ),
                  ),
                  if (score.insights.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Card(
                      color: const Color(0xFFFFF8E7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI INSIGHTS',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(score.insights),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GRADING RUBRIC',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          buildRubricRow(
                            'Clarity',
                            'How clear and easy to understand your answers were.',
                          ),
                          buildRubricRow(
                            'Technical',
                            'The depth and accuracy of your technical explanations.',
                          ),
                          buildRubricRow(
                            'Confidence',
                            'How confident and decisive you sounded while answering.',
                          ),
                          buildRubricRow(
                            'Completeness',
                            'Whether your answers fully addressed each question asked.',
                          ),
                          buildRubricRow(
                            'Presentation',
                            'The structure and professionalism of your answers overall.',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => practiceAgain(context),
                    icon: const Icon(Icons.replay),
                    label: const Text('Practice Again'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String scoreHeadline(int overall) {
    if (overall >= 85) return 'Great Job!';
    if (overall >= 70) return 'Good Effort!';
    return 'Keep Practicing!';
  }

  void practiceAgain(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DefensePracticeSessionScreen(
          title: title,
          questions: questions,
          maxQuestions: maxQuestions,
          secondsPerQuestion: secondsPerQuestion,
        ),
      ),
    );
  }

  Widget buildMetricRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('$value%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              color: AppColors.primary,
              backgroundColor: AppColors.background,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRubricRow(String label, String description, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(description, style: const TextStyle(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
