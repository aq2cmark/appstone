import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

import '../app_colors.dart';
import '../services/defense_ai_service.dart';
import '../services/practice_history_service.dart';
import 'auth_gate.dart';
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
      // Conceptual questions: 3 minutes each is enough to type a solid answer.
      secondsPerQuestion: 180,
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
      // Technical explanations need more room than title defense.
      secondsPerQuestion: 240,
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
      // The deepest questions get the most time.
      secondsPerQuestion: 300,
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
// Every question runs on a countdown; when it hits zero the student gets a
// short grace period to wrap up, then the answer submits itself.
class DefensePracticeSessionScreen extends StatefulWidget {
  const DefensePracticeSessionScreen({
    super.key,
    required this.title,
    required this.panelName,
    required this.panelRole,
    required this.questions,
    required this.maxQuestions,
    required this.secondsPerQuestion,
  });

  final String title;
  final String panelName;
  final String panelRole;
  final List<String> questions;
  final int maxQuestions;
  // Time allowed per main panel question. Harder defense types get more time;
  // follow-up questions always use the shorter [followUpSeconds] instead.
  final int secondsPerQuestion;

  @override
  State<DefensePracticeSessionScreen> createState() =>
      _DefensePracticeSessionScreenState();
}

class _DefensePracticeSessionScreenState
    extends State<DefensePracticeSessionScreen> {
  final answerController = TextEditingController();
  final speechToText = speech.SpeechToText();
  final ai = DefenseAiService();
  final history = PracticeHistoryService();

  // ---- Question timer -------------------------------------------------------
  // Each question gets widget.secondsPerQuestion (follow-ups get less). When
  // the clock reaches zero the student is NOT cut off instantly: a 30-second
  // "wrap up" grace period starts, and only when that also runs out is the
  // answer submitted automatically - empty answers are recorded as no answer.
  // The countdown pauses while the AI is evaluating so thinking time isn't
  // charged against the student.
  static const followUpSeconds = 120;
  static const graceSeconds = 30;
  Timer? questionTimer;
  int secondsLeft = 0;
  bool inGrace = false;
  // When the session started, for the duration shown in session history.
  late final DateTime sessionStart;

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
  // Text already confirmed in the box before the current utterance started,
  // so each new utterance's words are appended onto it instead of replacing
  // or duplicating it.
  String voiceBaseAnswer = '';
  String speechStatus = 'Tap the mic and start speaking.';
  String lastRecognizedWords = '';
  // True only when the user pressed the mic button to stop, so we can tell
  // that apart from one utterance ending naturally (which should restart
  // listening, not end the whole session).
  bool userStoppedListening = true;
  // Bumped on every fresh listen() call. A result tagged with an older id is
  // a stray late arrival from a session that already ended - ignoring it is
  // cheap insurance against the exact kind of duplicate text this is fixing.
  int voiceSessionId = 0;
  // The plugin fires onStatus twice for a single utterance ending ('notListening'
  // then 'done') - this stops both from scheduling their own restart, which
  // would otherwise start two overlapping listen() sessions at once.
  bool restartScheduled = false;

  String get currentQuestion => pendingFollowUp ?? widget.questions[genericIndex];
  bool get isFollowUp => pendingFollowUp != null;

  // Shared tips shown under every question.
  final List<String> tips = [
    'Be specific.',
    'Explain who is affected.',
    'Give real-world examples.',
  ];

  @override
  void initState() {
    super.initState();
    sessionStart = DateTime.now();
    startQuestionTimer();
  }

  @override
  void dispose() {
    questionTimer?.cancel();
    speechToText.stop();
    answerController.dispose();
    super.dispose();
  }

  // Resets the countdown for whichever question is now on screen.
  void startQuestionTimer() {
    questionTimer?.cancel();
    inGrace = false;
    secondsLeft = isFollowUp ? followUpSeconds : widget.secondsPerQuestion;
    questionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => tickTimer(),
    );
  }

  void tickTimer() {
    if (!mounted || isEvaluating) return;
    if (secondsLeft > 0) {
      setState(() => secondsLeft--);
    }
    if (secondsLeft > 0) return;

    if (!inGrace) {
      // Main time is up: give a final 30 seconds to wrap up instead of
      // cutting the student off mid-sentence.
      setState(() {
        inGrace = true;
        secondsLeft = graceSeconds;
      });
      return;
    }

    // Grace also ran out: hand in whatever is there.
    questionTimer?.cancel();
    handleTimeExpired();
  }

  // Called only when the grace period expires. A typed/spoken partial answer
  // goes through the normal submit path (so it still gets evaluated); a blank
  // box is recorded as no answer and the panel moves to the next topic.
  Future<void> handleTimeExpired() async {
    if (isEvaluating) return;
    if (listening) {
      userStoppedListening = true;
      await speechToText.stop();
      if (mounted) setState(() => listening = false);
    }
    final answer = answerController.text.trim();
    if (answer.isEmpty) {
      setState(() => isEvaluating = true);
      exchanges.add(
        QaExchange(
          question: currentQuestion,
          answer: '(No answer - time ran out.)',
        ),
      );
      await advancePastCurrentQuestion();
      return;
    }
    await submitAnswer();
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalAsked / widget.maxQuestions;

    return PopScope(
      // Intercept back/exit so we can warn that leaving still uses a session.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await _confirmLeave();
        if (!mounted || !leave) return;
        navigator.pop();
      },
      child: Scaffold(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Question $totalAsked (of up to ${widget.maxQuestions})',
                        ),
                      ),
                      buildTimerChip(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  if (inGrace) buildGraceBanner(),
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
        ),
    );
  }

  // Asks the student to confirm leaving mid-practice, warning that it still
  // counts as one of their daily defense practice sessions.
  Future<bool> _confirmLeave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave practice?'),
        content: const Text(
          'Leaving ends this practice now. It still counts as one of your daily '
          'defense practice sessions, and your progress will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Countdown pill next to the question counter. Primary while there's
  // plenty of time, gold in the last 30 seconds, red during the grace period.
  Widget buildTimerChip() {
    final minutes = secondsLeft ~/ 60;
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
    final color = inGrace
        ? Colors.red
        : secondsLeft <= 30
        ? AppColors.gold
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inGrace ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$minutes:$seconds',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget buildGraceBanner() {
    return Card(
      color: Colors.red.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Time's up! Your answer submits automatically in "
                '$secondsLeft second${secondsLeft == 1 ? '' : 's'}.',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
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

  // Android's SpeechRecognizer only ever recognizes ONE utterance per
  // listen() call - "continuous dictation" is an illusion the plugin creates
  // by silently restarting its own native session after every pause. That
  // internal restart is opaque to this Dart code, and on some Android
  // devices it re-delivers the tail of the just-finished utterance before
  // starting fresh, which is what was doubling text.
  //
  // The fix: stop relying on that hidden native restart. Use
  // ListenMode.confirmation, which cleanly ends (`onStatus` reports 'done')
  // after each single utterance, then explicitly start a brand new listen()
  // ourselves for the next one - snapshotting the box's current text fresh
  // each time. From the user's side it still feels like one continuous
  // session; the difference is every restart is now something this code
  // controls instead of something the OS does invisibly.
  Future<void> toggleListening() async {
    if (listening) {
      userStoppedListening = true;
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
            if (userStoppedListening) {
              setState(() => listening = false);
            } else if (!restartScheduled) {
              restartScheduled = true;
              restartForNextUtterance();
            }
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

    userStoppedListening = false;
    await startListening();
  }

  // Starts recognizing exactly one utterance. voiceBaseAnswer is captured
  // fresh right here, every time, from whatever is currently in the answer
  // box - not once for the whole session like before - so a restart after a
  // finished utterance appends onto the real current text instead of
  // overwriting it with a stale snapshot from before the session started.
  Future<void> startListening() async {
    restartScheduled = false;
    voiceBaseAnswer = answerController.text.trim();
    lastRecognizedWords = '';
    voiceSessionId++;
    final currentSession = voiceSessionId;
    setState(() {
      listening = true;
      speechStatus = 'Listening... speak now.';
    });
    await speechToText.listen(
      listenOptions: speech.SpeechListenOptions(
        // On web, this plugin ties the BROWSER's own "continuous" mode
        // directly to partialResults (see speech_to_text_web.dart) - there is
        // no separate on/off switch for it. Turning partialResults off forced
        // the browser into its non-continuous, one-phrase-at-a-time mode,
        // which stopped a duplicate-text bug on some phone browsers - but that
        // one-shot mode is also what made Chrome auto-capitalize and punctuate
        // every phrase and recognize Filipino words noticeably worse than its
        // normal continuous session does. That trade was worse than the bug it
        // fixed, so web keeps partialResults on like native does;
        // listenMode.confirmation plus the restart logic above still recovers
        // gracefully if the browser's continuous session ends on its own.
        partialResults: true,
        onDevice: !kIsWeb,
        listenMode: speech.ListenMode.confirmation,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: false,
      ),
      onResult: (result) {
        if (!mounted || currentSession != voiceSessionId) return;
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

  // Called when one utterance ends naturally (the user paused) while they're
  // still holding the mic on. The short delay avoids restarting into the
  // tail end of the same pause the recognizer just detected.
  Future<void> restartForNextUtterance() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || userStoppedListening) return;
    await startListening();
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
    // Stop any active mic session so a late result can't overwrite the answer.
    if (listening) {
      await speechToText.stop();
      if (mounted) setState(() => listening = false);
    }
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
        startQuestionTimer();
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
    startQuestionTimer();
  }

  void resetAnswerInput() {
    answerController.clear();
    voiceBaseAnswer = '';
    lastRecognizedWords = '';
    speechStatus = 'Tap the mic and start speaking.';
  }

  Future<void> finishSession() async {
    questionTimer?.cancel();
    try {
      final score = await ai.scoreSession(
        panelTitle: widget.title,
        exchanges: exchanges,
      );
      if (!mounted) return;
      await saveSessionHistory(score);
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
            secondsPerQuestion: widget.secondsPerQuestion,
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

  // Best-effort write to session history. The student identity comes from the
  // same SharedPreferences keys the login screen saves; if either is missing
  // (shouldn't happen for a logged-in student) the session simply isn't
  // recorded. Any failure here must never block the results screen.
  Future<void> saveSessionHistory(DefenseScore score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getString(studentIdPrefsKey);
      final groupId = prefs.getString(groupIdPrefsKey);
      if (studentId == null || groupId == null) return;
      await history.saveSession(
        groupId: groupId,
        studentId: studentId,
        sessionType: widget.title,
        questionsAnswered: exchanges.length,
        durationSeconds: DateTime.now().difference(sessionStart).inSeconds,
        overallScore: score.overall,
      );
    } catch (_) {
      // History is a nice-to-have; the results screen still shows.
    }
  }
}
