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
      maxQuestions: 8,
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
      maxQuestions: 15,
      questions: [
        'Can you explain your system architecture?',
        'Why did you choose your database structure?',
        'How will users navigate the main workflow?',
        'What are the possible security risks?',
        'How will you test if the system works correctly?',
        'What third-party libraries or APIs does your system depend on, and why did you choose them?',
        'How does your system handle errors or unexpected input?',
        'What would happen if your system needed to support many more users at once?',
        'How is user data stored and protected in your system?',
        'Walk us through what happens, step by step, when a user submits a key action in your app.',
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
      maxQuestions: 20,
      questions: [
        'What did your group complete in the final system?',
        'Can you demonstrate the most important feature?',
        'What feedback did you apply after previous defenses?',
        'What are the final limitations of your system?',
        'What future improvements would you recommend?',
        'How does your finished system compare to your original proposal?',
        'What was the most difficult technical problem your team solved, and how?',
        'How did your team divide the work among members?',
        'What would you do differently if you started this project again?',
        'How did you validate that your system actually solves the problem you set out to solve?',
        'What metrics or results can you show that prove your system works?',
        'How maintainable is your codebase for someone who did not build it?',
        'What risks or edge cases could still break your system in production?',
        'How does your system handle a real user making a mistake?',
        'What did each team member personally contribute and learn from this project?',
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
    required this.maxQuestions,
  });

  final String title;
  final String panelName;
  final String panelRole;
  final List<String> questions;
  final int maxQuestions;

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
  // Follow-ups are capped per topic too, so a student who's stuck on one
  // question gets moved to a new topic instead of being pressed forever.
  static const maxFollowUpsPerTopic = 2;
  int genericIndex = 0;
  String? pendingFollowUp;
  int totalAsked = 1;
  int followUpsOnTopic = 0;
  bool isEvaluating = false;
  final List<QaExchange> exchanges = [];

  bool speechReady = false;
  bool listening = false;
  // Only the Stop button should end a listening session. The browser/OS can
  // still end a session on its own (timeout, brief silence - mobile does
  // this far more aggressively than desktop), so this flag tells the status
  // handler whether that was requested or should restart.
  bool userRequestedStop = false;
  String voiceBaseAnswer = '';
  String speechStatus = 'Tap the mic and start speaking.';
  // Bumped every time a new listening session starts. A restarted session's
  // callback checks this so a late result from the session it replaced can't
  // still land and duplicate text on top of the new session's words.
  int voiceSessionId = 0;

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
    final progress = totalAsked / widget.maxQuestions;

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
                  Text('Question $totalAsked (of up to ${widget.maxQuestions})'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    color: AppColors.primary,
                  ),
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
      userRequestedStop = true;
      voiceSessionId++;
      await speechToText.stop();
      setState(() {
        listening = false;
        speechStatus = 'Voice answer stopped.';
      });
      return;
    }

    var initErrorShown = false;
    if (!speechReady) {
      speechReady = await speechToText.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => speechStatus = 'Speech status: $status');
          if (status != 'done' && status != 'notListening') return;
          // The browser/OS can end a session on its own (timeout, a brief
          // pause). Only actually stop if the user pressed Stop themselves -
          // otherwise keep going by starting a fresh session.
          if (userRequestedStop) {
            setState(() => listening = false);
          } else {
            startListening();
          }
        },
        onError: (error) {
          if (!mounted) return;
          initErrorShown = true;
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
      if (!mounted || initErrorShown) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice input is not available. Please type your answer instead.',
          ),
        ),
      );
      return;
    }

    userRequestedStop = false;
    await startListening();
  }

  Future<void> startListening() async {
    // Re-anchor on whatever text already exists (including anything from a
    // prior session in this same answer) so a restart never duplicates it -
    // the recognizer's own words always start counting from empty again.
    voiceBaseAnswer = answerController.text.trim();
    voiceSessionId++;
    final sessionId = voiceSessionId;
    if (!mounted) return;
    setState(() {
      listening = true;
      speechStatus = 'Listening... speak now.';
    });
    await speechToText.listen(
      listenOptions: speech.SpeechListenOptions(
        // Mobile speech engines can report garbled, self-repeating interim
        // hypotheses (e.g. "bakitbakitbakit") before settling on a final
        // answer. Only accepting finalResult below isn't enough on its own
        // because some platforms never mark anything final until the
        // session ends, so partial results are disabled outright here -
        // each pause commits one clean, final chunk instead.
        partialResults: false,
        onDevice: !kIsWeb,
        listenMode: speech.ListenMode.dictation,
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(seconds: 20),
        cancelOnError: false,
      ),
      onResult: (result) {
        if (!mounted) return;
        // Ignore results from a session that's already been replaced by a
        // restart - otherwise a late result can double up on the new text.
        if (sessionId != voiceSessionId) return;
        if (!result.finalResult) return;
        setState(() => speechStatus = 'Writing your voice answer...');
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
    if (code == 'speech_not_supported' || code.contains('not_supported')) {
      return kIsWeb
          ? 'Voice input is not supported in this browser. Try Chrome or Edge, or just type your answer.'
          : 'Voice input is not supported on this device. Please type your answer instead.';
    }
    return 'Speech error: $code';
  }

  Future<void> stopListeningIfActive() async {
    // A still-running mic session can deliver a late result after we've
    // already moved to the next question, overwriting its answer box with
    // stale text. Always stop it before reading or clearing the answer.
    if (!listening) return;
    userRequestedStop = true;
    voiceSessionId++;
    await speechToText.stop();
    if (mounted) setState(() => listening = false);
  }

  Future<void> submitAnswer() async {
    await stopListeningIfActive();
    if (!mounted) return;
    final answer = answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type or speak an answer first.')),
      );
      return;
    }

    setState(() => isEvaluating = true);
    exchanges.add(QaExchange(question: currentQuestion, answer: answer));

    // Already hit the hard cap, or pressed this same topic enough times:
    // stop asking follow-ups and move to a new topic instead.
    final atQuestionCap = totalAsked >= widget.maxQuestions;
    final atTopicCap = followUpsOnTopic >= maxFollowUpsPerTopic;
    if (atQuestionCap || atTopicCap) {
      await advancePastCurrentQuestion();
      return;
    }

    try {
      final followUp = await ai.evaluateAnswer(
        panelTitle: widget.title,
        question: currentQuestion,
        answer: answer,
        followUpsSoFarOnTopic: followUpsOnTopic,
        maxFollowUpsPerTopic: maxFollowUpsPerTopic,
      );
      if (!mounted) return;

      if (followUp.hasGap && followUp.followUpQuestion.isNotEmpty) {
        setState(() {
          pendingFollowUp = followUp.followUpQuestion;
          totalAsked++;
          followUpsOnTopic++;
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

  // Satisfied with the answer (or hit a cap): resume the fixed question
  // list on a fresh topic rather than drifting or exceeding the limit.
  Future<void> advancePastCurrentQuestion() async {
    pendingFollowUp = null;
    followUpsOnTopic = 0;
    genericIndex++;
    if (genericIndex >= widget.questions.length ||
        totalAsked >= widget.maxQuestions) {
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
            maxQuestions: widget.maxQuestions,
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
