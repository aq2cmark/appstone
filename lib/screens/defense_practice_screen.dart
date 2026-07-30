import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/defense_context_service.dart';

// Lets students choose a defense practice mode.
// Before starting, they can hand the AI panel context about their own capstone
// ("Add More Context") so the follow-up questions and the final score are about
// their project instead of a generic one. Context is optional: any mode can be
// started without it.
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

  // Opens the context editor, then refreshes this menu so the card reflects
  // whatever they just saved or cleared.
  Future<void> _openContextEditor() async {
    await Navigator.pushNamed(context, '/defense-context');
    if (!mounted) return;
    await _loadContext();
  }

  // Starting a mode is the last moment the context is still editable, so a
  // student with none gets one reminder here rather than discovering halfway
  // through that the panel knows nothing about their project. They can always
  // decline and practice with generic questions.
  Future<void> _startMode(String route) async {
    if (_projectContext.isEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add project context first?'),
          content: const Text(
            "You haven't told the panel anything about your capstone yet. "
            'Adding it takes a minute and makes the questions and your score '
            'specific to your own project.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'skip'),
              child: const Text('Start without it'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'add'),
              child: const Text('Add Context'),
            ),
          ],
        ),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Defense Practice'),
        actions: [
          IconButton(
            tooltip: 'Session history',
            onPressed: () => Navigator.pushNamed(context, '/session-history'),
            icon: const Icon(Icons.history),
          ),
        ],
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
                  const Text(
                    'Choose a mode and practice your defense.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  buildContextCard(),
                  const SizedBox(height: 16),
                  PracticeModeCard(
                    title: 'Title Defense',
                    subtitle:
                        'Practice defending your proposal and research plan.',
                    details: '15-20 min | 5-8 questions | 3 min each',
                    icon: Icons.chat_bubble_outline,
                    color: AppColors.primary,
                    onTap: () => _startMode('/title-defense'),
                  ),
                  PracticeModeCard(
                    title: 'Oral Defense',
                    subtitle: 'Practice presenting your system design.',
                    details: '30-45 min | 10-15 questions | 4 min each',
                    icon: Icons.mic_none,
                    color: AppColors.grey,
                    onTap: () => _startMode('/oral-defense'),
                  ),
                  PracticeModeCard(
                    title: 'Final Defense',
                    subtitle: 'Practice your full final presentation.',
                    details: '45-60 min | 15-20 questions | 5 min each',
                    icon: Icons.emoji_events_outlined,
                    color: AppColors.gold,
                    onTap: () => _startMode('/final-defense'),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/session-history'),
                    icon: const Icon(Icons.history),
                    label: const Text('View Session History'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // The "Add More Context" entry point. Doubles as a status card: once context
  // exists it says how much the panel knows and switches to "Edit", so the
  // student can tell at a glance whether their next run will be project-aware.
  Widget buildContextCard() {
    final hasContext = _projectContext.isNotEmpty;
    final title = _projectContext.projectTitle.trim();

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasContext ? Icons.auto_awesome : Icons.info_outline,
                  color: hasContext ? AppColors.gold : AppColors.textGrey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasContext
                        ? 'Project context added'
                        : 'No project context yet',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                if (_loadingContext)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasContext
                  ? '${title.isEmpty ? 'Your project' : title} - '
                        '${_projectContext.filledCount} of '
                        '${_projectContext.fieldCount} details filled in. The '
                        'panel reads this before your first question.'
                  : 'Tell the AI panel what your capstone is about before you '
                        'start, and it will ask about your actual system '
                        'instead of asking generic questions.',
              style: const TextStyle(height: 1.4, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: hasContext
                  ? OutlinedButton.icon(
                      onPressed: _loadingContext ? null : _openContextEditor,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Context'),
                    )
                  : FilledButton.icon(
                      onPressed: _loadingContext ? null : _openContextEditor,
                      icon: const Icon(Icons.add),
                      label: const Text('Add More Context'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PracticeModeCard extends StatelessWidget {
  // Simple card used for each defense mode.
  const PracticeModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String details;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: Icon(icon, color: Colors.white, size: 32),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$subtitle\n$details',
          style: const TextStyle(color: Colors.white70),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        onTap:
            onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title is not ready yet.')),
              );
            },
      ),
    );
  }
}
