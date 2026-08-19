import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';

import '../services/defense_ai_service.dart';
import '../services/defense_context_service.dart';
import '../services/defense_session_plan.dart';
import '../services/practice_history_service.dart';
import '../services/recording_store.dart';
import '../services/speech_transcription_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/states/app_states.dart';
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
    required this.questions,
    required this.maxQuestions,
    required this.secondsPerQuestion,
  });

  final String title;
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
  final contextService = DefenseContextService();

  // The student's project description, saved from the "Add More Context" screen
  // on the Defense Practice menu. Loaded once when the session opens and sent
  // with every AI call so the panel's follow-ups and the final score are about
  // their actual capstone. Empty when they never added any - the session then
  // behaves exactly as it did before.
  DefenseContext projectContext = const DefenseContext();
  // The questions this run will actually ask. Starts as the fixed list every
  // student gets, and is replaced once - before question one - with versions
  // rewritten around the student's own project, but only when they gave context
  // to rewrite them from. With none, this stays the fixed list.
  late List<String> questions = widget.questions;
  // True only while those rewrites are being fetched. The clock is held and the
  // answer box hidden meanwhile, so nobody spends their time answering a
  // question that is about to change under them.
  bool preparingQuestions = false;
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
  // This run's length and which questions may be followed up, drawn once before
  // question one. Answers to every other question move the panel straight on
  // without asking the model anything, which is what keeps a whole class
  // practising at once inside the providers' per-minute caps.
  late final DefenseSessionPlan plan = DefenseSessionPlan.draw(
    baseQuestionCount: widget.questions.length,
    maxQuestions: widget.maxQuestions,
  );
  late int followUpsLeft = plan.followUpBudget;
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

  String get currentQuestion => pendingFollowUp ?? questions[genericIndex];
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
    prepareSession();
    startQuestionTimer();
  }

  // Two different sessions start here.
  //
  // A student who added no context gets the one that always existed: the saved
  // context reads back empty in a few milliseconds, the fixed question one is
  // already on screen with its clock running, and from there the panel can only
  // follow up on what they actually say in their answers.
  //
  // A student who did add context gets their questions rewritten around their
  // own project first. That is a network call, so the question and the answer
  // box are held behind a short preparing state - showing them a generic
  // question that then changes underneath them would be worse than a two-second
  // wait - and the clock is restarted afterwards so none of that wait comes out
  // of their answering time.
  Future<void> prepareSession() async {
    final saved = await contextService.load();
    if (!mounted) return;
    if (saved.isEmpty) {
      setState(() => projectContext = saved);
      return;
    }

    setState(() {
      projectContext = saved;
      preparingQuestions = true;
    });

    final tailored = await ai.tailorQuestions(
      panelTitle: widget.title,
      baseQuestions: widget.questions,
      projectContext: saved.promptBlock,
    );
    if (!mounted) return;
    setState(() {
      questions = tailored;
      preparingQuestions = false;
      startQuestionTimer();
    });
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
    // transcribing, evaluating and preparing the questions are all us making
    // them wait, and shouldn't cost them the clock.
    if (!mounted || isEvaluating || transcribing || preparingQuestions) return;
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
    final colors = AppColors.of(context);

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
      child: AppScaffold(
        title: widget.title,
        accent: colors.moduleDefense,
        maxContentWidth: AppContentWidth.wide,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Leave practice',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        // On a wide window the answer box and the panel context sit side by
        // side, so the timer and the tips stay visible while typing instead of
        // scrolling off the top - which is exactly when a student needs them.
        body: AppTwoColumn(
          sideWidth: 320,
          main: _buildMainColumn(),
          side: _buildSideColumn(),
        ),
      ),
    );
  }

  Widget _buildMainColumn() {
    final colors = AppColors.of(context);

    if (preparingQuestions) return buildPreparingCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (projectContext.isNotEmpty) ...<Widget>[
          buildContextNotice(),
          AppSpacing.vMd,
        ],
        if (inGrace) ...<Widget>[buildGraceBanner(), AppSpacing.vMd],
        buildQuestionCard(),
        AppSpacing.vLg,
        TextField(
          controller: answerController,
          maxLines: 6,
          minLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Your answer',
            alignLabelWithHint: true,
            hintText: 'Type your answer, or use the microphone below.',
            counterText: '${answerController.text.length} characters',
          ),
        ),
        AppSpacing.vMd,
        OutlinedButton.icon(
          onPressed: isEvaluating || transcribing ? null : toggleRecording,
          style: OutlinedButton.styleFrom(
            foregroundColor: recording ? colors.danger : null,
            side: recording ? BorderSide(color: colors.danger) : null,
          ),
          // Transcription takes a beat, and the student needs to see that
          // something is happening to their answer.
          icon: transcribing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : recording
                  ? _RecordingPulse(color: colors.danger)
                  : const Icon(Icons.mic_rounded),
          label: Text(
            transcribing
                ? 'Transcribing...'
                : recording
                    ? 'Stop and transcribe'
                    : 'Answer with voice',
          ),
        ),
        AppSpacing.vSm,
        Text(
          speechStatus,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: recording || transcribing
                ? colors.moduleDefense
                : colors.textTertiary,
          ),
        ),
        AppSpacing.vLg,
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: colors.moduleDefense,
          ),
          onPressed: isEvaluating ? null : submitAnswer,
          icon: isEvaluating
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onColor,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(isEvaluating ? 'Panel is reading...' : 'Submit answer'),
        ),
      ],
    );
  }

  Widget _buildSideColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        buildProgressCard(),
        AppSpacing.vMd,
        buildTipsCard(),
      ],
    );
  }

  // Asks the student to confirm leaving mid-practice, warning that it still
  // counts as one of their daily defense practice sessions.
  Future<bool> _confirmLeave() async {
    final colors = AppColors.of(context);
    final result = await showAppDialog<bool>(
      context: context,
      title: 'Leave practice?',
      icon: Icons.exit_to_app_rounded,
      accent: colors.danger,
      message: 'Leaving ends this practice now. It still counts as one of your '
          'daily defense practice sessions, and your progress will not be '
          'saved.',
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Stay'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Leave'),
        ),
      ],
    );
    return result ?? false;
  }

  // Question counter, countdown ring and progress track in one card.
  Widget buildProgressCard() {
    final colors = AppColors.of(context);
    // Against this run's planned length, not the mode's ceiling: a student on a
    // six-question draw should see the bar fill at six, not sit two-thirds full
    // at the last question of their defense.
    final progress = (totalAsked / plan.targetQuestions).clamp(0.0, 1.0);
    final minutes = secondsLeft ~/ 60;
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');

    // Calm while there is room, warning under 30s, danger during the grace
    // period - the one place in the app where colour carries urgency.
    final tone = inGrace
        ? colors.danger
        : secondsLeft <= 30
            ? colors.warning
            : colors.moduleDefense;

    // Fraction of THIS question's time remaining, so the ring drains as the
    // clock does. During grace the ring stays full in red rather than
    // implying there is time left.
    final timeFraction = inGrace
        ? 1.0
        : (widget.secondsPerQuestion == 0
            ? 0.0
            : secondsLeft / widget.secondsPerQuestion);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _TimerRing(
                  value: timeFraction.clamp(0.0, 1.0),
                  color: tone,
                  pulsing: inGrace || (secondsLeft <= 30 && secondsLeft > 0),
                  label: '$minutes:$seconds',
                ),
                AppSpacing.hLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'QUESTION $totalAsked',
                        style: AppTypography.eyebrow.copyWith(color: tone),
                      ),
                      AppSpacing.vXs,
                      Text(
                        'of up to ${plan.targetQuestions}',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.vLg,
            AnimatedProgressBar(
              value: progress,
              minHeight: 8,
              color: colors.moduleDefense,
              backgroundColor: colors.surfaceSunken,
            ),
          ],
        ),
      ),
    );
  }

  // Stands in for the question card while the panel turns its fixed questions
  // into ones about this student's system. Seconds at most, only ever before
  // question one, and only for a student who gave context - if the rewrite
  // fails, the generic questions appear here instead of an error.
  Widget buildPreparingCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AppLoading(
          message: 'The panel is reading your project and preparing its '
              'questions...',
          compact: true,
        ),
      ),
    );
  }

  // Reassures the student that the context they wrote is actually in play, so a
  // project-specific follow-up doesn't come as a surprise. Only shown when there
  // is context to use.
  Widget buildContextNotice() {
    final colors = AppColors.of(context);
    final title = projectContext.projectTitle.trim();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: colors.tint(colors.moduleDefense),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.tintBorder(colors.moduleDefense)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.auto_awesome_rounded,
            size: AppSize.iconSm,
            color: colors.moduleDefense,
          ),
          AppSpacing.hMd,
          Expanded(
            child: Text(
              title.isEmpty
                  ? 'The panel is using your saved project context.'
                  : 'The panel is asking about your project: $title',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: colors.moduleDefense,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGraceBanner() {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.dangerTint,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.tintBorder(colors.danger)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: colors.danger),
          AppSpacing.hMd,
          Expanded(
            child: Text(
              'Time is up. Your answer submits automatically in '
              '$secondsLeft second${secondsLeft == 1 ? '' : 's'}.',
              style: AppTypography.titleSmall.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildQuestionCard() {
    final colors = AppColors.of(context);
    final tone = isFollowUp ? colors.warning : colors.moduleDefense;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  isFollowUp
                      ? Icons.subdirectory_arrow_right_rounded
                      : Icons.record_voice_over_rounded,
                  size: AppSize.iconSm,
                  color: tone,
                ),
                AppSpacing.hSm,
                Text(
                  isFollowUp ? 'FOLLOW-UP QUESTION' : 'PANEL QUESTION',
                  style: AppTypography.eyebrow.copyWith(color: tone),
                ),
              ],
            ),
            AppSpacing.vMd,
            // Keyed on the question so a new one cross-fades in rather than
            // silently swapping under the reader's eyes.
            SharedAxisSwitcher(
              child: Text(
                currentQuestion,
                key: ValueKey<String>(currentQuestion),
                style: AppTypography.headlineSmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTipsCard() {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.warningTint,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: colors.tintBorder(colors.warning)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.tips_and_updates_outlined,
                size: AppSize.iconSm,
                color: colors.warning,
              ),
              AppSpacing.hSm,
              Text(
                'TIPS FOR ANSWERING',
                style: AppTypography.eyebrow.copyWith(color: colors.warning),
              ),
            ],
          ),
          AppSpacing.vMd,
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.warning,
                      ),
                    ),
                  ),
                  AppSpacing.hSm,
                  Expanded(
                    child: Text(
                      tip,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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

    // Four reasons not to spend an AI call on this answer: the run is full, this
    // topic has been pressed enough times already, the run's follow-ups are all
    // spent, or this question was never one of the planned follow-up slots. The
    // last two are why a run costs a handful of calls instead of one per answer.
    final atQuestionCap = totalAsked >= widget.maxQuestions;
    final atTopicCap = followUpsOnTopic >= maxFollowUpsPerTopic;
    final outOfFollowUps = followUpsLeft <= 0;
    // Only base questions are planned. A follow-up's own answer can be pressed
    // again on the same topic, budget permitting, the way it always could.
    final unplannedTopic = !isFollowUp && !plan.allowsFollowUpAt(genericIndex);
    if (atQuestionCap || atTopicCap || outOfFollowUps || unplannedTopic) {
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
        projectContext: projectContext.promptBlock,
      );
      if (!mounted) return;

      if (followUp.hasGap && followUp.followUpQuestion.isNotEmpty) {
        setState(() {
          pendingFollowUp = followUp.followUpQuestion;
          totalAsked++;
          followUpsOnTopic++;
          followUpsLeft--;
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
    if (genericIndex >= questions.length ||
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
        projectContext: projectContext.promptBlock,
      );
      if (!mounted) return;
      await saveSessionHistory(score);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DefenseResultsScreen(
            title: widget.title,
            // The fixed list, not this run's rewritten one: "Practice again"
            // should tailor afresh from whatever context is saved then, not
            // rewrite questions that were already rewritten once.
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

/// The per-question countdown, drawn as a draining ring.
///
/// This is the expressive motion register the paper calls "gamified": the ring
/// empties as the clock runs down, and once the student is inside the last 30
/// seconds it breathes so the pressure is felt without a sound or a jolt. It
/// holds still for anyone who has asked their system for reduced motion.
class _TimerRing extends StatefulWidget {
  const _TimerRing({
    required this.value,
    required this.color,
    required this.label,
    required this.pulsing,
  });

  /// Fraction of this question's time still remaining, 0..1.
  final double value;
  final Color color;
  final String label;
  final bool pulsing;

  @override
  State<_TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<_TimerRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.94,
    upperBound: 1.0,
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _TimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulsing != widget.pulsing) _syncPulse();
  }

  void _syncPulse() {
    if (widget.pulsing && !AppMotion.reduced(context)) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ScaleTransition(
      scale: _pulse,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Painted directly rather than through ProgressRing: the countdown
            // must track the clock tick-for-tick, and an implicit tween would
            // always be animating a second behind the number in the middle.
            CustomPaint(
              size: const Size.square(64),
              painter: _TimerRingPainter(
                value: widget.value,
                color: widget.color,
                trackColor: colors.surfaceSunken,
              ),
            ),
            Text(
              widget.label,
              style: AppTypography.titleSmall.copyWith(color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  const _TimerRingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color
      ..isAntiAlias = true;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5707963267948966, // 12 o'clock
      6.283185307179586 * value.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_TimerRingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor;
}

/// A softly pulsing dot shown in place of the mic icon while recording, so the
/// student can tell at a glance that the microphone is live.
class _RecordingPulse extends StatefulWidget {
  const _RecordingPulse({required this.color});

  final Color color;

  @override
  State<_RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<_RecordingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    lowerBound: 0.55,
  );

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced(context)) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Icon(Icons.stop_circle_rounded, color: widget.color),
    );
  }
}
