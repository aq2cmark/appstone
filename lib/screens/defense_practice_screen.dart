import 'package:flutter/material.dart';

import '../services/defense_context_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/charts/progress_ring.dart';
import '../widgets/icon_tile.dart';

/// Lets students choose a defense practice mode.
///
/// Before starting, they can hand the AI panel context about their own capstone
/// ("Add More Context") so the follow-up questions and the final score are about
/// their project instead of a generic one. Context is optional: any mode can be
/// started without it.
class DefensePracticeScreen extends StatefulWidget {
  const DefensePracticeScreen({super.key});

  @override
  State<DefensePracticeScreen> createState() => _DefensePracticeScreenState();
}

class _DefensePracticeScreenState extends State<DefensePracticeScreen> {
  final _contextService = DefenseContextService();

  DefenseContext _projectContext = const DefenseContext();
  bool _loadingContext = true;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final saved = await _contextService.load();
    if (!mounted) return;
    setState(() {
      _projectContext = saved;
      _loadingContext = false;
    });
  }

  /// Opens the context editor, then refreshes this menu so the card reflects
  /// whatever they just saved or cleared.
  Future<void> _openContextEditor() async {
    await Navigator.pushNamed(context, '/defense-context');
    if (!mounted) return;
    await _loadContext();
  }

  /// Starting a mode is the last moment the context is still editable, so a
  /// student with none gets one reminder here rather than discovering halfway
  /// through that the panel knows nothing about their project. They can always
  /// decline and practice with generic questions.
  Future<void> _startMode(String route) async {
    if (_projectContext.isEmpty) {
      final choice = await showAppDialog<String>(
        context: context,
        title: 'Add project context first?',
        icon: Icons.auto_awesome_rounded,
        message: "You haven't told the panel anything about your capstone yet. "
            'Adding it takes a minute and makes the questions and your score '
            'specific to your own project.',
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'skip'),
            child: const Text('Start without it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'add'),
            child: const Text('Add context'),
          ),
        ],
      );
      if (!mounted || choice == null) return;
      if (choice == 'add') {
        await _openContextEditor();
        return;
      }
    }
    if (!mounted) return;
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AppScaffold(
      title: 'Defense Practice',
      subtitle: 'Practice answering, timed questions',
      accent: colors.moduleDefense,
      actions: <Widget>[
        IconButton(
          tooltip: 'Session history',
          onPressed: () => Navigator.pushNamed(context, '/session-history'),
          icon: const Icon(Icons.history_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StaggeredEntrance(index: 0, child: _buildContextCard()),
          AppSpacing.vXl,
          StaggeredEntrance(
            index: 1,
            child: AppSection(
              label: 'Choose a mode',
              accent: colors.moduleDefense,
              child: Column(
                children: <Widget>[
                  PracticeModeCard(
                    title: 'Title Defense',
                    subtitle:
                        'Propose your title, problem statement and defend it'
                        ' to the panel.',
                    duration: '15-20 min',
                    questions: '5-8 questions',
                    perQuestion: '3 min each',
                    icon: Icons.lightbulb_outline_rounded,
                    color: colors.titleDefense,
                    onTap: () => _startMode('/title-defense'),
                  ),
                  AppSpacing.vMd,
                  PracticeModeCard(
                    title: 'Oral Defense',
                    subtitle:
                        'Walk the panel through your system design and '
                        'implementation.',
                    duration: '30-45 min',
                    questions: '10-15 questions',
                    perQuestion: '4 min each',
                    icon: Icons.mic_none_rounded,
                    color: colors.oralDefense,
                    onTap: () => _startMode('/oral-defense'),
                  ),
                  AppSpacing.vMd,
                  PracticeModeCard(
                    title: 'Final Defense',
                    subtitle:
                        'Your full presentation: results, limitations and '
                        'future work.',
                    duration: '45-60 min',
                    questions: '15-20 questions',
                    perQuestion: '5 min each',
                    icon: Icons.emoji_events_outlined,
                    color: colors.finalDefense,
                    onTap: () => _startMode('/final-defense'),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.vXl,
          StaggeredEntrance(
            index: 2,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/session-history'),
              icon: const Icon(Icons.history_rounded),
              label: const Text('View session history'),
            ),
          ),
        ],
      ),
    );
  }

  /// The "Add More Context" entry point. Doubles as a status card: once context
  /// exists it shows how much the panel knows as a ring and switches to "Edit",
  /// so the student can tell at a glance whether their next run is
  /// project-aware.
  Widget _buildContextCard() {
    final colors = AppColors.of(context);
    final hasContext = _projectContext.isNotEmpty;
    final title = _projectContext.projectTitle.trim();
    final filled = _projectContext.filledCount;
    final total = _projectContext.fieldCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_loadingContext)
                  const SizedBox(
                    width: AppSize.tileSm,
                    height: AppSize.tileSm,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (hasContext)
                  ProgressRing(
                    value: total == 0 ? 0 : filled / total,
                    size: AppSize.tileSm,
                    strokeWidth: 5,
                    color: colors.moduleDefense,
                    child: Text(
                      '$filled/$total',
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.moduleDefense,
                      ),
                    ),
                  )
                else
                  IconBadge(
                    icon: Icons.auto_awesome_rounded,
                    color: colors.moduleDefense,
                    soft: true,
                  ),
                AppSpacing.hLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hasContext
                            ? 'Project context added'
                            : 'No project context yet',
                        style: AppTypography.titleMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      AppSpacing.vXs,
                      Text(
                        hasContext
                            ? '${title.isEmpty ? 'Your project' : title} - '
                                '$filled of $total details filled in. The panel '
                                'reads this before your first question.'
                            : 'Tell the AI panel what your capstone is about '
                                'before you start, and it will ask about your '
                                'actual system instead of generic questions.',
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
            Align(
              alignment: Alignment.centerLeft,
              child: hasContext
                  ? OutlinedButton.icon(
                      onPressed: _loadingContext ? null : _openContextEditor,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit context'),
                    )
                  : FilledButton.icon(
                      onPressed: _loadingContext ? null : _openContextEditor,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add more context'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One defense mode.
///
/// The pre-overhaul version was a solid-colour card with white text and a
/// three-line `ListTile` subtitle that clipped at large text scales. It is now
/// a surface card with a coloured accent rail, and the timing details are
/// separate wrapping chips instead of a fixed-height line.
class PracticeModeCard extends StatelessWidget {
  const PracticeModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.questions,
    required this.perQuestion,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String duration;
  final String questions;
  final String perQuestion;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedPressable(
      onTap: onTap,
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: colors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Accent rail - identifies the mode without flooding the card.
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        IconBadge(icon: icon, color: color, soft: true),
                        AppSpacing.hLg,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleLarge.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              AppSpacing.vXs,
                              Text(
                                subtitle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              AppSpacing.vMd,
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: <Widget>[
                                  _MetaChip(
                                    icon: Icons.schedule_rounded,
                                    label: duration,
                                    color: color,
                                  ),
                                  _MetaChip(
                                    icon: Icons.help_outline_rounded,
                                    label: questions,
                                    color: color,
                                  ),
                                  _MetaChip(
                                    icon: Icons.timer_outlined,
                                    label: perQuestion,
                                    color: color,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.hSm,
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: colors.tint(color),
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          AppSpacing.hXs,
          Text(label, style: AppTypography.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}
