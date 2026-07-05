import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../models/workflow_plan.dart';
import '../services/document_text_extractor.dart';
import '../services/workflow_service.dart';

// AI Workflow: the student uploads their paper and says how long they have.
// The AI reads the paper and proposes weighted phases; the app schedules them
// across the time budget. Ticking a phase done recomputes the remaining
// schedule live - finishing early relaxes the rest, finishing late tightens
// it. The plan is saved on-device so it survives reopening the screen.
class AIWorkflowScreen extends StatefulWidget {
  const AIWorkflowScreen({super.key});

  @override
  State<AIWorkflowScreen> createState() => _AIWorkflowScreenState();
}

enum _DurationUnit { days, weeks, months }

class _AIWorkflowScreenState extends State<AIWorkflowScreen> {
  static const _prefsKey = 'workflow_plan_v1';

  final _extractor = DocumentTextExtractor();
  final _service = WorkflowService();
  final _amountController = TextEditingController(text: '4');

  final _dateFmt = DateFormat('MMM d');
  final _dateFmtYear = DateFormat('MMM d, yyyy');

  _DurationUnit _unit = _DurationUnit.weeks;
  PlatformFile? _selectedPaper;

  WorkflowPlan? _plan;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedPlan();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (!mounted) return;
    setState(() {
      _plan = raw == null ? null : WorkflowPlan.decode(raw);
      _loading = false;
    });
  }

  Future<void> _savePlan() async {
    final prefs = await SharedPreferences.getInstance();
    final plan = _plan;
    if (plan == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, plan.encode());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('AI Workflow'),
        actions: [
          if (_plan != null)
            IconButton(
              tooltip: 'Start over',
              onPressed: _confirmStartOver,
              icon: const Icon(Icons.restart_alt),
            ),
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
                    child: _plan == null ? _buildSetup() : _buildPlan(_plan!),
                  ),
                ),
              ],
            ),
    );
  }

  // ---- Setup form (no plan yet) --------------------------------------------

  Widget _buildSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Upload your paper and tell us how long you have. The AI builds a '
          'chapter-by-chapter timeline you can track and adjust.',
          style: TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Upload your current paper',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedPaper?.name ??
                      'PDF, DOCX, or TXT - the AI reads it to see what is done '
                          'and what is left.',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _generating ? null : _pickPaper,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _selectedPaper == null ? 'Select Paper' : 'Change Paper',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. How long will you work on it?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Amount',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<_DurationUnit>(
                        value: _unit,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Unit',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: _DurationUnit.days,
                            child: Text('Days'),
                          ),
                          DropdownMenuItem(
                            value: _DurationUnit.weeks,
                            child: Text('Weeks'),
                          ),
                          DropdownMenuItem(
                            value: _DurationUnit.months,
                            child: Text('Months'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _unit = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Deadline: ${_dateFmtYear.format(_previewDeadline())}',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _buildErrorCard(_error!),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _generating ? null : _generate,
          icon: _generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_generating ? 'Building timeline...' : 'Generate Timeline'),
        ),
      ],
    );
  }

  // ---- Plan view (schedule + tracking) -------------------------------------

  Widget _buildPlan(WorkflowPlan plan) {
    final schedule = plan.schedule();
    final now = DateTime.now();
    final daysLeft = plan.daysRemaining(now);
    final allDone = plan.doneCount == plan.totalCount && plan.totalCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusCard(plan, daysLeft, allDone),
        const SizedBox(height: 16),
        for (final item in schedule) _buildPhaseCard(plan, item),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _confirmStartOver,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Start a new plan'),
        ),
      ],
    );
  }

  Widget _buildStatusCard(WorkflowPlan plan, int daysLeft, bool allDone) {
    final onTrack = plan.isOnTrack();
    final projected = plan.projectedFinish();

    final Color bannerColor;
    final IconData bannerIcon;
    final String bannerText;
    if (allDone) {
      bannerColor = Colors.green.shade700;
      bannerIcon = Icons.celebration;
      bannerText = 'All phases complete. Great work!';
    } else if (onTrack) {
      bannerColor = Colors.green.shade700;
      bannerIcon = Icons.trending_up;
      bannerText = 'On track - projected finish ${_dateFmt.format(projected)}.';
    } else {
      bannerColor = AppColors.primary;
      bannerIcon = Icons.warning_amber_rounded;
      bannerText =
          'Behind schedule - projected finish ${_dateFmt.format(projected)}, '
          'after your ${_dateFmt.format(plan.deadline)} deadline.';
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.paperName != null)
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      plan.paperName!,
                      style: const TextStyle(color: AppColors.textGrey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${plan.doneCount}/${plan.totalCount}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('phases done'),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Deadline ${_dateFmt.format(plan.deadline)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      daysLeft >= 0
                          ? '$daysLeft day(s) left'
                          : '${-daysLeft} day(s) overdue',
                      style: TextStyle(
                        color: daysLeft >= 0
                            ? AppColors.textGrey
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: plan.progress,
                minHeight: 10,
                backgroundColor: const Color(0xFFECECEC),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(bannerIcon, color: bannerColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bannerText,
                      style: TextStyle(
                        color: bannerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (plan.assessment.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                plan.assessment,
                style: const TextStyle(height: 1.4, color: AppColors.textDark),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseCard(WorkflowPlan plan, ScheduledPhase item) {
    final phase = item.phase;
    final Widget scheduleChip;
    if (phase.done) {
      scheduleChip = _chip(
        icon: Icons.check_circle,
        label: 'Done ${_dateFmt.format(item.end)}',
        color: Colors.green.shade700,
      );
    } else if (item.isOverdue) {
      scheduleChip = _chip(
        icon: Icons.event_busy,
        label:
            '${_dateFmt.format(item.start)} - ${_dateFmt.format(item.end)} - past deadline',
        color: AppColors.primary,
      );
    } else {
      scheduleChip = _chip(
        icon: Icons.event,
        label:
            '${_dateFmt.format(item.start)} - ${_dateFmt.format(item.end)} - ${item.days} day(s)',
        color: AppColors.grey,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              activeColor: AppColors.primary,
              value: phase.done,
              onChanged: (value) => _togglePhase(plan, phase, value ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    phase.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      decoration:
                          phase.done ? TextDecoration.lineThrough : null,
                      color: phase.done
                          ? AppColors.textGrey
                          : AppColors.textDark,
                    ),
                  ),
                  if (phase.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      phase.note,
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                  ],
                  const SizedBox(height: 10),
                  scheduleChip,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      color: const Color(0xFFFDECEC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  int _durationInDays() {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    switch (_unit) {
      case _DurationUnit.days:
        return amount;
      case _DurationUnit.weeks:
        return amount * 7;
      case _DurationUnit.months:
        return amount * 30;
    }
  }

  DateTime _previewDeadline() =>
      DateTime.now().add(Duration(days: _durationInDays().clamp(0, 100000)));

  Future<void> _pickPaper() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _selectedPaper = result.files.single;
      _error = null;
    });
  }

  Future<void> _generate() async {
    final paper = _selectedPaper;
    if (paper == null) {
      setState(() => _error = 'Upload your paper first.');
      return;
    }
    final totalDays = _durationInDays();
    if (totalDays < 1) {
      setState(() => _error = 'Enter how long you have (at least 1 day).');
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final text = await _extractor.extract(paper);
      final generated = await _service.generate(
        paperText: text,
        totalDays: totalDays,
      );
      final plan = WorkflowPlan(
        startDate: DateTime.now(),
        totalDays: totalDays,
        assessment: generated.assessment,
        paperName: paper.name,
        phases: generated.phases,
      );
      if (!mounted) return;
      setState(() => _plan = plan);
      await _savePlan();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _togglePhase(
    WorkflowPlan plan,
    WorkflowPhase phase,
    bool done,
  ) async {
    setState(() {
      phase.done = done;
      phase.completedOn = done ? DateTime.now() : null;
    });
    await _savePlan();
    if (!mounted) return;
    if (done && plan.doneCount < plan.totalCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Schedule updated for the remaining phases.'),
        ),
      );
    }
  }

  Future<void> _confirmStartOver() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new plan?'),
        content: const Text(
          'This clears your current timeline and progress so you can upload a '
          'paper and generate a fresh plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _plan = null;
      _selectedPaper = null;
      _error = null;
    });
    await _savePlan();
  }

  String _friendlyError(Object error) {
    if (error is DocumentExtractionException) return error.message;
    if (error is StateError) return error.message;
    return 'Something went wrong while building the timeline. Please try again.';
  }
}
