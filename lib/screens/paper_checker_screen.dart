import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/docx_layout_checker.dart';
import '../services/paper_check_controller.dart';
import '../services/paper_check_history_service.dart';
import '../services/paper_checker_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/charts/score_dial.dart';
import '../widgets/icon_tile.dart';
import '../widgets/states/app_states.dart';
import '../widgets/states/skeleton.dart';
import 'auth_gate.dart';

/// Paper Checker: uploads a capstone manuscript, extracts its text, and grades
/// it against Section 8.3 of the Capstone Manual (the 50-point manuscript
/// rubric). It reports a score per rubric section plus the concrete issues the
/// student needs to fix.
class PaperCheckerScreen extends StatefulWidget {
  const PaperCheckerScreen({super.key});

  @override
  State<PaperCheckerScreen> createState() => _PaperCheckerScreenState();
}

class _PaperCheckerScreenState extends State<PaperCheckerScreen> {
  // The check runs in this shared controller (not local state), so it keeps
  // going when the user leaves this screen and the result is still here when
  // they return.
  final _controller = PaperCheckController.instance;

  // The file the user has picked but not yet checked (screen-local).
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _restoreLastCheck();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return AppScaffold(
          title: 'AI Paper Checker',
          subtitle: 'Graded against the manuscript rubric',
          accent: colors.modulePaper,
          maxContentWidth: AppContentWidth.wide,
          actions: <Widget>[
            IconButton(
              tooltip: 'Check history',
              onPressed: () =>
                  Navigator.pushNamed(context, '/paper-check-history'),
              icon: const Icon(Icons.history_rounded),
            ),
          ],
          // Upload controls stay pinned on the left on a wide window while the
          // results scroll on the right, so re-checking a revised draft does not
          // mean scrolling back past the whole report.
          body: AppTwoColumn(
            sideWidth: 340,
            sideFirstWhenStacked: true,
            side: _buildControls(),
            main: _buildResults(),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Left / top: upload and run
  // ---------------------------------------------------------------------------

  Widget _buildControls() {
    final colors = AppColors.of(context);
    final running = _controller.running;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildUploadCard(),
        AppSpacing.vLg,
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colors.modulePaper,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: running ? null : _runCheck,
          icon: running
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onColor,
                  ),
                )
              : const Icon(Icons.fact_check_rounded),
          label: Text(running ? 'Checking...' : 'Check paper'),
        ),
        AppSpacing.vLg,
        Text(
          'Your manuscript is graded against the Capstone Manual rubric '
          '(50 points), with the exact issues to fix in each chapter. '
          'A .docx file is also measured for margins, spacing and font.',
          style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildUploadCard() {
    final colors = AppColors.of(context);
    final file = _selectedFile;
    final running = _controller.running;

    return Card(
      child: InkWell(
        onTap: running ? null : _pickPaper,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              IconBadge(
                icon: file == null
                    ? Icons.upload_file_rounded
                    : Icons.description_rounded,
                color: colors.modulePaper,
                size: AppSize.tileLg,
                soft: true,
              ),
              AppSpacing.vMd,
              Text(
                file?.name ?? 'Choose your manuscript',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              AppSpacing.vXs,
              Text(
                file == null ? 'PDF, DOCX or TXT' : _fileSizeText(file.size),
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (file != null) ...<Widget>[
                AppSpacing.vMd,
                TextButton.icon(
                  onPressed: running ? null : _pickPaper,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Choose a different file'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right / bottom: results
  // ---------------------------------------------------------------------------

  Widget _buildResults() {
    final colors = AppColors.of(context);
    final running = _controller.running;
    final review = _controller.review;
    final layout = _controller.layout;
    final error = _controller.error;

    if (running) return _buildRunningState();

    // Reading the last saved check back after a restart. A skeleton rather
    // than the "No check yet" empty state: telling a student they have no
    // check and then replacing that with their result a moment later reads as
    // the app having lost their work.
    if (_controller.restoring && review == null) {
      return const SkeletonList(count: 3, lines: 3);
    }

    // A failed run only takes over the pane when there is nothing to keep
    // showing. With remarks still on screen it becomes a banner above them
    // instead, since replacing a completed check with an error message costs
    // the student the notes they were working from.
    if (error != null && review == null) {
      return AppErrorView(
        message: error,
        title: 'Could not check this paper',
        onRetry: _selectedFile == null ? null : _runCheck,
      );
    }

    if (review == null) {
      return AppEmptyView(
        icon: Icons.fact_check_outlined,
        accent: colors.modulePaper,
        title: 'No check yet',
        body:
            'Pick your manuscript and run a check. You will get a rubric '
            'score, a formatting report, and the specific issues to fix.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The results outlive the file that produced them now, so whenever the
        // student has selected a different one they are told what they are
        // reading rather than left to assume it graded the new draft.
        if (error != null) ...<Widget>[
          _buildFailedRunNote(error),
          AppSpacing.vLg,
        ] else if (_isShowingPreviousFile) ...<Widget>[
          _buildPreviousFileNote(),
          AppSpacing.vLg,
        ] else if (_controller.restoredFrom != null) ...<Widget>[
          _buildRestoredNote(_controller.restoredFrom!),
          AppSpacing.vLg,
        ],
        if (_controller.reusedFrom != null) ...<Widget>[
          _buildReusedNote(_controller.reusedFrom!),
          AppSpacing.vLg,
        ],
        StaggeredEntrance(index: 0, child: _buildScoreCard(review)),
        AppSpacing.vLg,
        if (layout != null)
          StaggeredEntrance(index: 1, child: _buildLayoutCard(layout))
        else if (_controller.restoredFrom?.hasLayout ?? false)
          StaggeredEntrance(
            index: 1,
            child: _buildRestoredLayoutNote(_controller.restoredFrom!),
          )
        else if (_controller.layoutSkipped)
          StaggeredEntrance(index: 1, child: _buildLayoutNote()),
        AppSpacing.vXl,
        StaggeredEntrance(
          index: 2,
          child: AppSection(
            label: 'Rubric breakdown',
            accent: colors.modulePaper,
            child: Column(
              children: <Widget>[
                for (final section in review.sections) ...<Widget>[
                  _buildSectionCard(section),
                  AppSpacing.vMd,
                ],
              ],
            ),
          ),
        ),
        AppSpacing.vLg,
        Text(
          'This is an AI pre-check to help you improve the paper. It is not '
          'the official panel grade, which also weighs the software and the '
          'oral defense.',
          style: AppTypography.bodySmall.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildRunningState() {
    final colors = AppColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            const AppLoading(),
            AppSpacing.vLg,
            Text(
              'Analyzing your paper',
              style: AppTypography.titleMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
            AppSpacing.vXs,
            Text(
              'Reading every chapter and grading it against the rubric. You can move around the app - the '
              'check keeps running and the result will be here when you '
              'come back.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shown when the score came from an earlier check of identical content.
  // Without this the student would wonder why the check finished instantly -
  // and would have no way to tell a reused verdict from a fresh one.
  // True when the remarks on screen were produced by a file other than the one
  // now selected. Both sides must be present: leaving this screen and coming
  // back rebuilds it with no selection, and that is not a mismatch - it is
  // simply the last check the student ran.
  bool get _isShowingPreviousFile {
    final selected = _selectedFile?.name;
    final graded = _controller.fileName;
    return selected != null && graded != null && selected != graded;
  }

  Widget _buildFailedRunNote(String error) {
    final colors = AppColors.of(context);
    final graded = _controller.fileName;
    return _buildNote(
      icon: Icons.error_outline_rounded,
      background: colors.dangerTint,
      accent: colors.danger,
      message: graded == null
          ? '$error The remarks below are from your last completed check.'
          : '$error The remarks below are from $graded, your last completed '
              'check.',
    );
  }

  Widget _buildPreviousFileNote() => _buildNote(
        icon: Icons.description_outlined,
        message: 'These remarks are from ${_controller.fileName}. They stay '
            'here until you run the check on ${_selectedFile!.name}.',
      );

  Widget _buildReusedNote(DateTime checkedAt) => _buildNote(
        icon: Icons.history_rounded,
        message: 'This manuscript is unchanged since it was checked on '
            '${_formatCheckedAt(checkedAt)}, so the same result is shown. '
            'Edit the paper and upload again for a fresh check.',
      );

  // Shown when the remarks were read back from the student's saved history
  // after a restart, rather than produced in this session. Says which file
  // they belong to and when it was graded, so a result that appears on a
  // freshly opened checker is never mistaken for one just run.
  Widget _buildRestoredNote(PaperCheckRecord record) {
    final checkedAt = record.createdAt;
    return _buildNote(
      icon: Icons.history_rounded,
      message: checkedAt == null
          ? 'These remarks are from ${record.fileName}, your last completed '
              'check. They stay here until you check another manuscript.'
          : 'These remarks are from ${record.fileName}, checked on '
              '${_formatCheckedAt(checkedAt)}. They stay here until you check '
              'another manuscript.',
    );
  }

  // A restored check keeps its formatting tally but not the individual rules -
  // those were measured from a .docx the app no longer holds. Showing the
  // count alone beats dropping the formatting section entirely, which would
  // look like the check had stopped covering it.
  Widget _buildRestoredLayoutNote(PaperCheckRecord record) => _buildNote(
        icon: Icons.rule_rounded,
        message: '${record.layoutPassCount} of ${record.layoutTotal} '
            'formatting rules were met on that check. Upload the .docx again '
            'to see each rule measured.',
      );

  // Shared chassis for the advisory lines that sit above a result.
  Widget _buildNote({
    required IconData icon,
    required String message,
    Color? background,
    Color? accent,
  }) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background ?? colors.surfaceSunken,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: accent == null ? colors.divider : colors.tintBorder(accent),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: AppSize.iconSm, color: accent ?? colors.textTertiary),
          AppSpacing.hMd,
          Expanded(
            child: Text(
              message,
              // These carry file names, which are user data and can be long.
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCheckedAt(DateTime when) {
    final local = when.toLocal();
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} at '
        '$hour:$minute $period';
  }

  Widget _buildScoreCard(PaperReview review) {
    final colors = AppColors.of(context);
    final tone = _scoreColor(review.percent);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: colors.tintBorder(tone)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.tint(tone), colors.surface],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 460;

          final dial = ScoreDial(
            score: review.totalScore,
            maxScore: review.maxScore,
            size: 150,
            color: tone,
            label: 'rubric points',
          );

          final details = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                review.verdict,
                textAlign: narrow ? TextAlign.center : TextAlign.start,
                style: AppTypography.headlineSmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (review.summary.trim().isNotEmpty) ...<Widget>[
                AppSpacing.vSm,
                Text(
                  review.summary.trim(),
                  textAlign: narrow ? TextAlign.center : TextAlign.start,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          );

          if (narrow) {
            return Column(children: <Widget>[dial, AppSpacing.vLg, details]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              dial,
              AppSpacing.hXl,
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLayoutCard(LayoutReport layout) {
    final colors = AppColors.of(context);
    final allPassed = layout.passCount == layout.total;
    final tone = allPassed ? colors.success : colors.warning;

    return AppSection(
      label: 'Formatting compliance',
      accent: colors.modulePaper,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconBadge(
                    icon: allPassed
                        ? Icons.verified_rounded
                        : Icons.rule_rounded,
                    color: tone,
                    size: 44,
                    soft: true,
                  ),
                  AppSpacing.hLg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${layout.passCount} of ${layout.total} rules met',
                          style: AppTypography.titleMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        AppSpacing.vXs,
                        Text(
                          'Measured from the .docx itself - margins, spacing, '
                          'font and paper size, per Capstone Manual 10.3.',
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
              for (final rule in layout.rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        rule.pass
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: AppSize.iconSm,
                        color: rule.pass ? colors.success : colors.danger,
                      ),
                      AppSpacing.hMd,
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: rule.name,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: '  ${rule.actual}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (!rule.pass)
                                TextSpan(
                                  text: '  (expected ${rule.expected})',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: colors.danger,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutNote() {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.infoTint,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: colors.tintBorder(colors.info)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            color: colors.info,
            size: AppSize.iconMd,
          ),
          AppSpacing.hMd,
          Expanded(
            child: Text(
              'Formatting could not be measured. Margins, spacing and font are '
              'stored inside a .docx file - a PDF or TXT does not carry them. '
              'Upload the .docx to include the formatting check.',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(RubricResult section) {
    final colors = AppColors.of(context);
    final ratio = section.max == 0 ? 0.0 : section.score / section.max;
    final tone = _scoreColor(ratio);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        title: Text(
          section.name,
          style: AppTypography.titleSmall.copyWith(color: colors.textPrimary),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: AnimatedProgressBar(
            value: ratio,
            minHeight: 6,
            color: tone,
            backgroundColor: colors.surfaceSunken,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.tint(tone),
            borderRadius: AppRadius.pillAll,
          ),
          child: Text(
            '${section.score}/${section.max}',
            style: AppTypography.labelMedium.copyWith(color: tone),
          ),
        ),
        children: <Widget>[
          if (section.comment.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                section.comment.trim(),
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          if (section.issues.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: AppSize.iconSm,
                    color: colors.success,
                  ),
                  AppSpacing.hSm,
                  Text(
                    'No major issues flagged.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.success,
                    ),
                  ),
                ],
              ),
            )
          else ...<Widget>[
            AppSpacing.vMd,
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ISSUES TO FIX',
                style: AppTypography.eyebrow.copyWith(color: colors.danger),
              ),
            ),
            AppSpacing.vSm,
            for (final issue in section.issues)
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
                          color: colors.danger,
                        ),
                      ),
                    ),
                    AppSpacing.hSm,
                    Expanded(
                      child: Text(
                        issue,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickPaper() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'docx', 'txt'],
      // We need the bytes in memory to read the document text.
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    // Only a failed attempt is dropped here. The remarks from a finished check
    // stay on screen until a new check replaces them - reaching for the next
    // draft is not a reason to lose the notes you are working from.
    _controller.clearError();
    setState(() => _selectedFile = result.files.single);
  }

  // Puts the last saved check back on screen. A check's result lives in the
  // shared controller, which a page reload throws away - so without this a
  // student who closed the tab returned to an empty checker even though the
  // check was already in their history. The controller decides whether there
  // is anything to do; it never disturbs a result that is already here.
  Future<void> _restoreLastCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await _controller.restoreLast(
      groupId: prefs.getString(groupIdPrefsKey),
      studentId: prefs.getString(studentIdPrefsKey),
    );
  }

  Future<void> _runCheck() async {
    final file = _selectedFile;
    if (file == null) {
      showMessageSnack(context, 'Select a paper first.', isError: true);
      return;
    }
    // The student identity is read here (as defense practice does) and handed
    // to the controller so the finished check can be saved to history.
    final prefs = await SharedPreferences.getInstance();
    // Runs in the shared controller, so the check keeps going (and the result
    // stays) even if the student leaves this screen and comes back.
    _controller.start(
      file,
      groupId: prefs.getString(groupIdPrefsKey),
      studentId: prefs.getString(studentIdPrefsKey),
    );
  }

  Color _scoreColor(double ratio) {
    final colors = AppColors.of(context);
    if (ratio >= 0.75) return colors.success;
    if (ratio >= 0.5) return colors.warning;
    return colors.danger;
  }

  String _fileSizeText(int bytes) {
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB selected';
    return '${(kb / 1024).toStringAsFixed(1)} MB selected';
  }
}
