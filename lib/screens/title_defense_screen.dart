import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';

import '../app_colors.dart';
import '../services/defense_ai_service.dart';
import '../services/recording_store.dart';
import '../services/speech_transcription_service.dart';
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
// What we're recording in: the encoder to ask for, plus the filename extension
// and MIME type Whisper needs to decode the result.
class _RecordingFormat {
  const _RecordingFormat(this.encoder, this.extension, this.mimeType);

  final AudioEncoder encoder;
  final String extension;
  final String mimeType;
}

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
  final recorder = AudioRecorder();
  final ai = DefenseAiService();
  final history = PracticeHistoryService();
  // Shares the run's session id, so every answer transcribed during this
  // practice counts inside the run's single session instead of spending a
  // day's allowance of its own.
  late final transcriber = SpeechTranscriptionService(ai.sessionId);

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

  // Voice answers are recorded whole and transcribed in one go by Whisper, so
  // there's no live text while the student talks the way the on-device
  // recognizer gave us - but equally none of its restart-and-deduplicate
  // machinery, because one recording produces exactly one transcript.
  bool recording = false;
  bool transcribing = false;
  String speechStatus = 'Tap the mic and speak your answer.';
  // Where the current clip lives (a file path natively, a blob: URL on web) and
  // what it is, both needed to read it back and tell Whisper how to decode it.
  String? recordingLocation;
  _RecordingFormat? recordingFormat;

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
    recorder.dispose();
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
    // Recording is the student answering, so that time is theirs to spend - but
    // transcribing is us making them wait, and shouldn't cost them the clock.
    if (!mounted || isEvaluating || transcribing) return;
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
    // Time ran out mid-sentence: transcribe what they'd already said rather
    // than throwing the whole spoken answer away.
    if (recording) await stopAndTranscribe();
    if (!mounted) return;
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
                    onPressed: isEvaluating || transcribing
                        ? null
                        : toggleRecording,
                    // Transcription takes a beat, and the student needs to see
                    // that something is happening to their answer.
                    icon: transcribing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(recording ? Icons.stop : Icons.mic),
                    label: Text(
                      transcribing
                          ? 'Transcribing...'
                          : recording
                          ? 'Stop and Transcribe'
                          : 'Answer with Voice',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    speechStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: recording || transcribing
                          ? AppColors.primary
                          : AppColors.textGrey,
                      fontWeight: recording || transcribing
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

  // Whisper transcribes a finished recording rather than listening live, so
  // the flow here is simply record -> stop -> upload -> text. That loses the
  // words-appearing-as-you-talk feedback the on-device recognizer gave, but it
  // also removes every reason this screen used to need restart, dedupe and
  // stale-result guards: one recording yields exactly one transcript.
  Future<void> toggleRecording() async {
    if (transcribing) return;
    if (recording) {
      await stopAndTranscribe();
      return;
    }

    if (!await recorder.hasPermission()) {
      if (!mounted) return;
      setState(() => speechStatus = 'Microphone permission was blocked.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allow microphone access, then try again.'),
        ),
      );
      return;
    }

    final format = await resolveRecordingFormat();
    final location = await newRecordingLocation(format.extension);
    try {
      await recorder.start(
        RecordConfig(
          encoder: format.encoder,
          // Whisper resamples to 16kHz mono anyway, and the clip is base64'd
          // into a JSON request - so anything richer costs upload size for no
          // gain in what comes back.
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 24000,
        ),
        path: location,
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => speechStatus = 'Could not start recording. Type your answer.',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      recording = true;
      recordingLocation = location;
      recordingFormat = format;
      speechStatus = 'Recording... tap stop when you finish your answer.';
    });
  }

  Future<void> stopAndTranscribe() async {
    final location = await recorder.stop() ?? recordingLocation;
    final format = recordingFormat;
    if (!mounted) return;
    setState(() {
      recording = false;
      transcribing = true;
      speechStatus = 'Transcribing your answer...';
    });

    if (location == null || format == null) {
      setState(() {
        transcribing = false;
        speechStatus = 'Nothing was recorded. Try again or type your answer.';
      });
      return;
    }

    try {
      final bytes = await readRecording(location);
      final text = await transcriber.transcribe(
        audio: bytes,
        mimeType: format.mimeType,
        filename: 'answer.${format.extension}',
      );
      if (!mounted) return;
      if (text.isEmpty) {
        setState(
          () => speechStatus =
              "Didn't catch any speech. Try again or type your answer.",
        );
      } else {
        appendVoiceText(text);
        setState(
          () => speechStatus = 'Added what you said. Record again to add more.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : 'Could not transcribe your answer. You can type it instead.';
      setState(() => speechStatus = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      await disposeRecording(location);
      if (mounted) {
        setState(() {
          transcribing = false;
          recordingLocation = null;
        });
      }
    }
  }

  // Whisper accepts several formats, but each platform encodes a different
  // subset, so ask rather than assume. Opus leads because the clip travels as
  // base64 inside a JSON body and it is far and away the smallest.
  //
  // The extension is not cosmetic: Whisper picks its decoder from the filename,
  // and browsers wrap Opus in WebM where native platforms use Ogg - so the same
  // encoder needs a different name depending on who produced it.
  Future<_RecordingFormat> resolveRecordingFormat() async {
    if (await recorder.isEncoderSupported(AudioEncoder.opus)) {
      return kIsWeb
          ? const _RecordingFormat(AudioEncoder.opus, 'webm', 'audio/webm')
          : const _RecordingFormat(AudioEncoder.opus, 'ogg', 'audio/ogg');
    }
    if (await recorder.isEncoderSupported(AudioEncoder.aacLc)) {
      return const _RecordingFormat(AudioEncoder.aacLc, 'm4a', 'audio/mp4');
    }
    // Uncompressed and much bigger, but universally supported - a last resort
    // beats no voice answer at all.
    return const _RecordingFormat(AudioEncoder.wav, 'wav', 'audio/wav');
  }

  // Appends rather than replaces, so a student can record in several goes, or
  // type part of an answer and dictate the rest, without losing what's there.
  void appendVoiceText(String text) {
    final existing = answerController.text.trim();
    setState(() {
      answerController.text = existing.isEmpty ? text : '$existing $text';
      answerController.selection = TextSelection.fromPosition(
        TextPosition(offset: answerController.text.length),
      );
    });
  }

  Future<void> submitAnswer() async {
    // Submitting mid-recording should hand in what they said, not drop it.
    if (recording) await stopAndTranscribe();
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
    speechStatus = 'Tap the mic and speak your answer.';
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
