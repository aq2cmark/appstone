import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

import '../app_colors.dart';
import '../services/defense_ai_service.dart';
import 'defense_results_screen.dart';

// These small wrapper screens keep routes simple in main.dart.
// Each one reuses the same voice-enabled practice session below.
class TitleDefenseScreen extends StatelessWidget {
  const TitleDefenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefensePracticeSessionScreen(
      title: 'Title Defense',
      panelName: 'Dr. Santos',
      panelRole: 'Panel Member',
      questions: [
        'What is the main problem your capstone project aims to solve?',
        'How is your project different from existing solutions?',
        'What technology stack will you use and why?',
        'What are the scope and limitations of your project?',
        'What is your expected timeline?',
      ],
    );
  }
}

class OralDefenseScreen extends StatelessWidget {
  const OralDefenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefensePracticeSessionScreen(
      title: 'Oral Defense',
      panelName: 'Prof. Reyes',
      panelRole: 'Technical Panel',
      questions: [
        'Can you explain your system architecture?',
        'Why did you choose your database structure?',
        'How will users navigate the main workflow?',
        'What are the possible security risks?',
        'How will you test if the system works correctly?',
      ],
    );
  }
}

class FinalDefenseScreen extends StatelessWidget {
  const FinalDefenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefensePracticeSessionScreen(
      title: 'Final Defense',
      panelName: 'Dr. Mendoza',
      panelRole: 'Final Panel',
      questions: [
        'What did your group complete in the final system?',
        'Can you demonstrate the most important feature?',
        'What feedback did you apply after previous defenses?',
        'What are the final limitations of your system?',
        'What future improvements would you recommend?',
      ],
    );
  }
}

// One reusable defense practice flow.
// Students can type answers or press the mic button to dictate an answer.
class DefensePracticeSessionScreen extends StatefulWidget {
  const DefensePracticeSessionScreen({
    super.key,
    required this.title,
    required this.panelName,
    required this.panelRole,
    required this.questions,
  });

  final String title;
  final String panelName;
  final String panelRole;
  final List<String> questions;

  @override
  State<DefensePracticeSessionScreen> createState() =>
      _DefensePracticeSessionScreenState();
}

class _DefensePracticeSessionScreenState
    extends State<DefensePracticeSessionScreen> {
  final answerController = TextEditingController();
  final speechToText = speech.SpeechToText();
  final ai = DefenseAiService();

  // The AI asks the fixed questions in order, but can insert a follow-up
  // question when it spots a gap in an answer instead of moving on. Once
  // satisfied, it resumes the fixed list rather than drifting off-topic.
  static const maxQuestions = 8;
  int genericIndex = 0;
  String? pendingFollowUp;
  int totalAsked = 1;
  bool isEvaluating = false;
  final List<QaExchange> exchanges = [];

  bool speechReady = false;
  bool listening = false;
  String voiceBaseAnswer = '';
  String speechStatus = 'Tap the mic and start speaking.';
  String lastRecognizedWords = '';

  String get currentQuestion => pendingFollowUp ?? widget.questions[genericIndex];
  bool get isFollowUp => pendingFollowUp != null;

  // Shared tips shown under every question.
  final List<String> tips = [
    'Be specific.',
    'Explain who is affected.',
    'Give real-world examples.',
  ];

  @override
  void dispose() {
    speechToText.stop();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalAsked / maxQuestions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(widget.title),
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
                  Text('Question $totalAsked (of up to $maxQuestions)'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    color: AppColors.primary,
                  ),
                  if (lastRecognizedWords.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Heard: $lastRecognizedWords',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          'PM',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(widget.panelName),
                      subtitle: Text(widget.panelRole),
                    ),
                  ),
                  buildQuestionCard(),
                  buildTipsCard(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: answerController,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'Your answer (${answerController.text.length} chars)',
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isEvaluating ? null : toggleListening,
                    icon: Icon(listening ? Icons.stop : Icons.mic),
                    label: Text(
                      listening ? 'Stop Listening' : 'Answer with Voice',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    speechStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: listening ? AppColors.primary : AppColors.textGrey,
                      fontWeight: listening
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isEvaluating ? null : submitAnswer,
                    child: isEvaluating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Submit Answer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildQuestionCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFollowUp ? 'FOLLOW-UP QUESTION' : 'PANEL QUESTION',
              style: TextStyle(
                color: isFollowUp ? AppColors.gold : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentQuestion,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTipsCard() {
    return Card(
      color: const Color(0xFFFFF8E7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
    );
  }

  Future<void> toggleListening() async {
    if (listening) {
      await speechToText.stop();
      setState(() {
        listening = false;
        speechStatus = 'Voice answer stopped.';
      });
      return;
    }

    if (!speechReady) {
      speechReady = await speechToText.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => speechStatus = 'Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() => listening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          final message = speechErrorMessage(error.errorMsg);
          setState(() {
            listening = false;
            speechStatus = message;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
      );
    }

    if (!speechReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission was not granted.')),
      );
      return;
    }

    voiceBaseAnswer = answerController.text.trim();
    lastRecognizedWords = '';
    setState(() {
      listening = true;
      speechStatus = 'Listening... speak now.';
    });
    await speechToText.listen(
      listenOptions: speech.SpeechListenOptions(
        partialResults: true,
        onDevice: !kIsWeb,
        listenMode: speech.ListenMode.dictation,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 8),
        cancelOnError: false,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          lastRecognizedWords = result.recognizedWords;
          speechStatus = result.finalResult
              ? 'Final voice result received.'
              : 'Writing your voice answer...';
        });
        writeVoiceWords(result.recognizedWords);
      },
    );
  }

  void writeVoiceWords(String words) {
    // Speech results arrive while the user is still talking.
    // This copies them into the answer box immediately.
    final spokenWords = words.trim();
    final text = voiceBaseAnswer.isEmpty
        ? spokenWords
        : spokenWords.isEmpty
        ? voiceBaseAnswer
        : '$voiceBaseAnswer $spokenWords';

    setState(() {
      answerController.text = text;
      answerController.selection = TextSelection.fromPosition(
        TextPosition(offset: answerController.text.length),
      );
    });
  }

  String speechErrorMessage(String code) {
    if (code == 'network') {
      return kIsWeb
          ? 'Browser speech network error. Type your answer or try the mobile app/device with speech services enabled.'
          : 'Speech network error. Check internet or install offline speech recognition on the device.';
    }
    if (code == 'not-allowed' || code == 'permission-denied') {
      return 'Microphone permission was blocked. Allow microphone access and try again.';
    }
    return 'Speech error: $code';
  }

  Future<void> submitAnswer() async {
    final answer = answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type or speak an answer first.')),
      );
      return;
    }

    setState(() => isEvaluating = true);
    exchanges.add(QaExchange(question: currentQuestion, answer: answer));

    // Already hit the hard cap: stop asking follow-ups and move on.
    if (totalAsked >= maxQuestions) {
      await advancePastCurrentQuestion();
      return;
    }

    try {
      final followUp = await ai.evaluateAnswer(
        panelTitle: widget.title,
        question: currentQuestion,
        answer: answer,
      );
      if (!mounted) return;

      if (followUp.hasGap && followUp.followUpQuestion.isNotEmpty) {
        setState(() {
          pendingFollowUp = followUp.followUpQuestion;
          totalAsked++;
          resetAnswerInput();
          isEvaluating = false;
        });
        return;
      }

      await advancePastCurrentQuestion();
    } catch (error) {
      if (!mounted) return;
      setState(() => isEvaluating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  // Satisfied with the answer (or hit the question cap): resume the fixed
  // question list instead of drifting into more follow-ups.
  Future<void> advancePastCurrentQuestion() async {
    pendingFollowUp = null;
    genericIndex++;
    if (genericIndex >= widget.questions.length) {
      await finishSession();
      return;
    }
    setState(() {
      totalAsked++;
      resetAnswerInput();
      isEvaluating = false;
    });
  }

  void resetAnswerInput() {
    answerController.clear();
    voiceBaseAnswer = '';
    lastRecognizedWords = '';
    speechStatus = 'Tap the mic and start speaking.';
  }

  Future<void> finishSession() async {
    try {
      final score = await ai.scoreSession(
        panelTitle: widget.title,
        exchanges: exchanges,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DefenseResultsScreen(
            title: widget.title,
            panelName: widget.panelName,
            panelRole: widget.panelRole,
            questions: widget.questions,
            questionsAnswered: exchanges.length,
            score: score,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => isEvaluating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
