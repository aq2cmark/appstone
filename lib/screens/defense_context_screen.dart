import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/theme_toggle_button.dart';
import '../services/defense_context_service.dart';

// "Add More Context" from the Defense Practice menu.
//
// The student describes their capstone here once; every practice session after
// that hands the description to the AI panel before the first question, so the
// follow-ups and the final scoring are about THEIR project instead of a generic
// one. Nothing here is required, and it is saved on-device so it only has to be
// written once.
class DefenseContextScreen extends StatefulWidget {
  const DefenseContextScreen({super.key});

  @override
  State<DefenseContextScreen> createState() => _DefenseContextScreenState();
}

class _DefenseContextScreenState extends State<DefenseContextScreen> {
  final _service = DefenseContextService();

  final _titleController = TextEditingController();
  final _problemController = TextEditingController();
  final _stackController = TextEditingController();
  final _usersController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _problemController.dispose();
    _stackController.dispose();
    _usersController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await _service.load();
    if (!mounted) return;
    _titleController.text = saved.projectTitle;
    _problemController.text = saved.problem;
    _stackController.text = saved.techStack;
    _usersController.text = saved.targetUsers;
    _notesController.text = saved.notes;
    setState(() => _loading = false);
  }

  DefenseContext get _current => DefenseContext(
    projectTitle: _titleController.text.trim(),
    problem: _problemController.text.trim(),
    techStack: _stackController.text.trim(),
    targetUsers: _usersController.text.trim(),
    notes: _notesController.text.trim(),
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    final entered = _current;
    await _service.save(entered);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entered.isEmpty
              ? 'Context cleared. The panel will ask generic questions.'
              : 'Saved. The panel will use this in your next practice.',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _clear() async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear project context?'),
        content: const Text(
          'The panel will go back to asking generic questions until you add '
          'context again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.clear();
    if (!mounted) return;
    _titleController.clear();
    _problemController.clear();
    _stackController.clear();
    _usersController.clear();
    _notesController.clear();
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Project context cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
            appBar: AppBar(
        title: const Text('Project Context'),
        bottom: appBarAccent(colors.moduleDefense),
        actions: [
          if (!_loading && _current.isNotEmpty)
            IconButton(
              tooltip: 'Clear context',
              onPressed: _saving ? null : _clear,
              icon: const Icon(Icons.delete_outline),
            ),
          const ThemeToggleButton(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: StaggeredEntrance.list(<Widget>[
                        _buildExplainer(),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _titleController,
                          label: 'Project title',
                          hint: 'e.g. Appstone: A Capstone Companion App',
                          icon: Icons.title_rounded,
                          maxLength: 150,
                        ),
                        _buildField(
                          controller: _problemController,
                          label: 'What it does and the problem it solves',
                          hint:
                              'e.g. Students lose track of capstone deadlines '
                              'and have no way to practice their defense, so '
                              'the app schedules their work and runs mock '
                              'defenses.',
                          icon: Icons.lightbulb_outline,
                          maxLines: 4,
                          maxLength: 600,
                        ),
                        _buildField(
                          controller: _stackController,
                          label: 'Technology stack',
                          hint: 'e.g. Flutter, Firebase Auth, Firestore, '
                              'Cloud Functions',
                          icon: Icons.memory,
                          maxLines: 2,
                          maxLength: 300,
                        ),
                        _buildField(
                          controller: _usersController,
                          label: 'Target users',
                          hint:
                              'e.g. 4th year CS students and their capstone '
                              'advisers',
                          icon: Icons.groups_outlined,
                          maxLines: 2,
                          maxLength: 300,
                        ),
                        _buildField(
                          controller: _notesController,
                          label: 'Anything else the panel should know',
                          hint:
                              'Scope and limitations, key features, the parts '
                              'you want to be grilled on, feedback from a '
                              'previous defense...',
                          icon: Icons.notes,
                          maxLines: 6,
                          maxLength: 1200,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text('Save Context'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Saved on this device only. You can edit or clear it '
                          'any time before a practice session.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildExplainer() {
    final colors = AppColors.of(context);
    return Card(
      color: colors.warningTint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: colors.premium),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tell the panel about your project',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'The AI panel reads this before your first question. The more it '
              'knows, the more its follow-up questions and your final score are '
              'about your actual capstone instead of a generic one.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              'Every field is optional. Leave it blank and practice works the '
              'same as before.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required int maxLength,
    int maxLines = 1,
  }) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          prefixIcon: Icon(icon, color: colors.brand),
          fillColor: colors.surface,
          // Counters on five stacked fields are noise; the cap is a safety net,
          // not something the student should be watching.
          counterText: '',
        ),
      ),
    );
  }
}
