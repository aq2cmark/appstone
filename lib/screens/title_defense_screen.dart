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
  // A browser reports BOTH 'notListening' and 'done' when one session ends.
  // Firing two restarts for a single ending is the main cause of duplicated
  // words on mobile, so this guard makes sure we only restart once.
  bool restartScheduled = false;
  // Everything already locked into the answer: the student's typed text plus
  // the finalized transcript of every session that has already ended.
  String committedText = '';
  // The live transcript of the CURRENT session only. It is replaced (never
  // appended) on every result, because both web and mobile report the running
  // transcript cumulatively within a single session.
  String sessionText = '';
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
      await stopListeningIfActive();
      if (mounted) setState(() => speechStatus = 'Voice answer stopped.');
      return;
    }

    if (!speechReady) {
      speechReady = await speechToText.initialize(
        onStatus: handleSpeechStatus,
        onError: (error) => handleSpeechError(error.errorMsg),
      );
    }

    if (!speechReady) {
      if (!mounted) return;
      // initialize() already routed any specific reason through
      // handleSpeechError; this is the catch-all so the user is never left
      // wondering why nothing happened.
      final message = kIsWeb
          ? 'Voice input is not available in this browser. Try Chrome or Edge, or type your answer instead.'
          : 'Voice input is not available on this device. Please type your answer instead.';
      setState(() => speechStatus = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    userRequestedStop = false;
    // Anchor on whatever is already in the box (typed text, or a previous
    // answer being edited) so the voice transcript is added onto it.
    committedText = answerController.text.trim();
    sessionText = '';
    await startListening();
  }

  // Handles the recognizer's own status changes. A session can end on its own
  // (mobile does this on the slightest pause); when it does we transparently
  // start a fresh one so the student can keep talking without re-tapping.
  void handleSpeechStatus(String status) {
    if (!mounted) return;
    if (status != 'done' && status != 'notListening') return;

    // Lock in whatever this finishing session produced. This is essential on
    // web, where results are never flagged "final" - the only signal a chunk
    // is complete is the session ending here.
    commitSessionText();

    if (userRequestedStop) {
      setState(() => listening = false);
      return;
    }
    // 'notListening' and 'done' both fire for a single ending; only one of
    // them should trigger a restart, or the next session duplicates words.
    if (restartScheduled) return;
    restartScheduled = true;
    scheduleRestart();
  }

  void handleSpeechError(String code) {
    if (!mounted) return;
    final normalized = code.toLowerCase();
    // Fatal errors won't fix themselves on a retry loop (unsupported browser,
    // blocked mic, no speech service). Stop cleanly and tell the user instead
    // of silently restarting into the same failure over and over.
    final fatal =
        normalized.contains('network') ||
        normalized.contains('not-allowed') ||
        normalized.contains('permission') ||
        normalized.contains('audio-capture') ||
        normalized.contains('service-not-allowed') ||
        normalized.contains('service_not_allowed') ||
        normalized.contains('not_supported') ||
        normalized.contains('not supported');

    final message = speechErrorMessage(code);
    if (fatal) {
      userRequestedStop = true;
      restartScheduled = false;
      voiceSessionId++;
      setState(() {
        listening = false;
        speechStatus = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } else {
      // Transient (e.g. a brief no-speech timeout): keep the mic alive; the
      // status handler will restart the session.
      setState(() => speechStatus = message);
    }
  }

  Future<void> scheduleRestart() async {
    // Fully release the recognizer before starting again. Without this pause
    // mobile can re-hear the tail of the previous session and repeat words.
    await speechToText.stop();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || userRequestedStop) {
      restartScheduled = false;
      if (mounted && userRequestedStop) setState(() => listening = false);
      return;
    }
    await startListening();
  }

  Future<void> startListening() async {
    restartScheduled = false;
    // A new session's transcript always starts empty; committedText already
    // holds everything from before, so results just replace sessionText.
    sessionText = '';
    voiceSessionId++;
    final sessionId = voiceSessionId;
    if (!mounted) return;
    setState(() {
      listening = true;
      speechStatus = 'Listening... speak now.';
    });
    await speechToText.listen(
      listenOptions: speech.SpeechListenOptions(
        partialResults: true,
        onDevice: !kIsWeb,
        listenMode: speech.ListenMode.dictation,
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(minutes: 10),
        cancelOnError: false,
      ),
      onResult: (result) {
        if (!mounted) return;
        // Ignore results from a session that's already been replaced by a
        // restart - otherwise a late result can double up on the new text.
        if (sessionId != voiceSessionId) return;
        // Replace (don't append): the recognizer reports the running transcript
        // of THIS session cumulatively, so the latest value is the whole thing.
        sessionText = result.recognizedWords.trim();
        if (result.finalResult) {
          // Mobile marks a chunk final; fold it into committedText now so the
          // next session (after a pause) appends cleanly instead of colliding.
          commitSessionText();
        }
        updateAnswerFromVoice();
        setState(() {
          speechStatus = result.finalResult
              ? 'Captured. Keep speaking or press Stop.'
              : 'Writing your voice answer...';
        });
      },
    );
  }

  // Moves the current session's transcript into the committed answer, trimming
  // any overlap so a restarted session that re-hears the last words can't
  // duplicate them.
  void commitSessionText() {
    if (sessionText.trim().isEmpty) return;
    committedText = mergeTranscript(committedText, sessionText);
    sessionText = '';
  }

  void updateAnswerFromVoice() {
    final text = mergeTranscript(committedText, sessionText);
    answerController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // Joins two transcript fragments, dropping any overlap where the tail of the
  // first repeats the head of the second. This is the core fix for mobile
  // duplication: when a paused session restarts and re-hears "...the system",
  // the repeat is detected and removed instead of being pasted in twice.
  String mergeTranscript(String base, String addition) {
    final left = base.trim();
    final right = addition.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;

    final leftWords = left.split(RegExp(r'\s+'));
    final rightWords = right.split(RegExp(r'\s+'));
    final maxOverlap = leftWords.length < rightWords.length
        ? leftWords.length
        : rightWords.length;

    for (var k = maxOverlap; k > 0; k--) {
      final leftTail = leftWords
          .sublist(leftWords.length - k)
          .join(' ')
          .toLowerCase();
      final rightHead = rightWords.sublist(0, k).join(' ').toLowerCase();
      if (leftTail == rightHead) {
        final rest = rightWords.sublist(k).join(' ');
        return rest.isEmpty ? left : '$left $rest';
      }
    }
    return '$left $right';
  }

  String speechErrorMessage(String code) {
    final normalized = code.toLowerCase();
    if (normalized.contains('network') ||
        normalized.contains('service-not-allowed') ||
        normalized.contains('service_not_allowed')) {
      return kIsWeb
          ? 'Voice input needs a browser with built-in speech recognition. Opera, Firefox and Brave do not include it - please use Chrome or Edge, or just type your answer.'
          : 'Speech network error. Check your internet connection, or install offline speech recognition on the device.';
    }
    if (normalized.contains('not-allowed') ||
        normalized.contains('permission') ||
        normalized.contains('audio-capture')) {
      return 'Microphone access was blocked. Allow microphone permission in your browser or device settings and try again.';
    }
    if (normalized.contains('not_supported') ||
        normalized.contains('not supported') ||
        normalized.contains('language-not-supported')) {
      return kIsWeb
          ? 'This browser does not support voice input. Try Chrome or Edge, or type your answer instead.'
          : 'Voice input is not supported on this device. Please type your answer instead.';
    }
    if (normalized.contains('no-speech') || normalized.contains('no match')) {
      return 'Did not catch that - keep speaking, or tap the mic again.';
    }
    return 'Speech error: $code';
  }

  Future<void> stopListeningIfActive() async {
    // A still-running mic session can deliver a late result after we've
    // already moved to the next question, overwriting its answer box with
    // stale text. Always stop it before reading or clearing the answer.
    if (!listening) return;
    userRequestedStop = true;
    restartScheduled = false;
    voiceSessionId++;
    await speechToText.stop();
    commitSessionText();
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
    committedText = '';
    sessionText = '';
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
