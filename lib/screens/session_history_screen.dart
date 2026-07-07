import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../services/practice_history_service.dart';
import 'auth_gate.dart';

// How the session list can be ordered. "Newest first" is the default; the
// others let a student compare their best scores or longest sessions.
enum HistorySort { newest, oldest, highestScore, longestDuration }

// The student's finished defense practice sessions, loaded from Firestore.
// Each row shows the session type, questions answered, duration, and overall
// score. Sessions can be filtered by type and re-sorted from a dropdown.
class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final _service = PracticeHistoryService();

  List<PracticeSessionRecord>? _records;
  String? _error;
  HistorySort _sort = HistorySort.newest;
  // null = show all session types.
  String? _typeFilter;

  static const _typeOptions = ['Title Defense', 'Oral Defense', 'Final Defense'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _records = null;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getString(studentIdPrefsKey);
      final groupId = prefs.getString(groupIdPrefsKey);
      if (studentId == null || groupId == null) {
        throw StateError('Log in as a student to see your session history.');
      }
      final records = await _service.fetchSessions(
        groupId: groupId,
        studentId: studentId,
      );
      if (!mounted) return;
      setState(() => _records = records);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  // The fetched list with the current filter and sort applied.
  List<PracticeSessionRecord> get _visibleRecords {
    final records = [...?_records];
    final filtered = _typeFilter == null
        ? records
        : records.where((r) => r.sessionType == _typeFilter).toList();
    switch (_sort) {
      case HistorySort.newest:
        // fetchSessions already returns newest first.
        break;
      case HistorySort.oldest:
        filtered.sort(
          (a, b) => (a.createdAt ?? DateTime(0))
              .compareTo(b.createdAt ?? DateTime(0)),
        );
      case HistorySort.highestScore:
        filtered.sort((a, b) => b.overallScore.compareTo(a.overallScore));
      case HistorySort.longestDuration:
        filtered.sort(
          (a, b) => b.durationSeconds.compareTo(a.durationSeconds),
        );
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Session History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.primary, size: 40),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_records == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_records!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: AppColors.textGrey, size: 48),
            SizedBox(height: 12),
            Text(
              'No practice sessions yet.\nFinish a defense practice and it '
              'will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
            ),
          ],
        ),
      );
    }

    final visible = _visibleRecords;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildControls(),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No sessions of this type yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
        for (final record in visible) _buildSessionCard(record),
      ],
    );
  }

  // Filter chips (session type) + sort dropdown, side by side when they fit.
  Widget _buildControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _typeFilter == null,
              onSelected: (_) => setState(() => _typeFilter = null),
            ),
            for (final type in _typeOptions)
              ChoiceChip(
                label: Text(type.replaceAll(' Defense', '')),
                selected: _typeFilter == type,
                onSelected: (_) => setState(() => _typeFilter = type),
              ),
            const SizedBox(width: 8),
            DropdownButton<HistorySort>(
              value: _sort,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: HistorySort.newest,
                  child: Text('Newest first'),
                ),
                DropdownMenuItem(
                  value: HistorySort.oldest,
                  child: Text('Oldest first'),
                ),
                DropdownMenuItem(
                  value: HistorySort.highestScore,
                  child: Text('Highest score'),
                ),
                DropdownMenuItem(
                  value: HistorySort.longestDuration,
                  child: Text('Longest duration'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _sort = value ?? HistorySort.newest),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(PracticeSessionRecord record) {
    final typeColor = switch (record.sessionType) {
      'Title Defense' => AppColors.primary,
      'Oral Defense' => AppColors.greyDark,
      'Final Defense' => AppColors.gold,
      _ => AppColors.grey,
    };
    final typeIcon = switch (record.sessionType) {
      'Title Defense' => Icons.chat_bubble_outline,
      'Oral Defense' => Icons.mic_none,
      'Final Defense' => Icons.emoji_events_outlined,
      _ => Icons.school_outlined,
    };
    final scoreColor = record.overallScore >= 85
        ? Colors.green
        : record.overallScore >= 70
        ? AppColors.gold
        : AppColors.primary;
    final dateLabel = record.createdAt == null
        ? 'Just now'
        : DateFormat('MMM d, yyyy - h:mm a').format(record.createdAt!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: typeColor.withValues(alpha: 0.12),
              child: Icon(typeIcon, color: typeColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.sessionType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _detail(
                        Icons.question_answer_outlined,
                        '${record.questionsAnswered} '
                        'question${record.questionsAnswered == 1 ? '' : 's'}',
                      ),
                      _detail(Icons.schedule, record.durationLabel),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  '${record.overallScore}%',
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'SCORE',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textGrey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.textGrey)),
      ],
    );
  }
}
