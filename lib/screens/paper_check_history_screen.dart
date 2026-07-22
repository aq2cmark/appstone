import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../services/paper_check_history_service.dart';
import 'auth_gate.dart';

// How the check list can be ordered. "Newest first" is the default; the others
// let a student find their best result or read the checks in order.
enum PaperCheckSort { newest, oldest, highestScore }

// The student's saved paper checks, loaded from Firestore. Each row expands to
// a per-chapter breakdown and shows how each score moved since the previous
// check, so a student can see exactly where the manuscript improved between
// runs. The defense practice Session History screen is the sibling of this one.
class PaperCheckHistoryScreen extends StatefulWidget {
  const PaperCheckHistoryScreen({super.key});

  @override
  State<PaperCheckHistoryScreen> createState() =>
      _PaperCheckHistoryScreenState();
}

class _PaperCheckHistoryScreenState extends State<PaperCheckHistoryScreen> {
  final _service = PaperCheckHistoryService();

  List<PaperCheckRecord>? _records;
  String? _error;
  PaperCheckSort _sort = PaperCheckSort.newest;
  // For each record id, the check taken just before it in time. Drives the
  // "vs previous check" deltas. Built once from the fetched (newest-first) list
  // so it stays chronological no matter how the display is re-sorted.
  Map<String, PaperCheckRecord> _previousById = {};

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
        throw StateError('Log in as a student to see your check history.');
      }
      final records = await _service.fetchChecks(
        groupId: groupId,
        studentId: studentId,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _previousById = _buildPreviousMap(records);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  // records is newest-first, so the chronological predecessor of records[i] is
  // records[i + 1].
  Map<String, PaperCheckRecord> _buildPreviousMap(
    List<PaperCheckRecord> records,
  ) {
    final map = <String, PaperCheckRecord>{};
    for (var i = 0; i < records.length - 1; i++) {
      map[records[i].id] = records[i + 1];
    }
    return map;
  }

  // The fetched list with the current sort applied. Deltas always reference
  // [_previousById], so re-sorting never changes what "previous" means.
  List<PaperCheckRecord> get _visibleRecords {
    final records = [...?_records];
    switch (_sort) {
      case PaperCheckSort.newest:
        break; // fetchChecks already returns newest first.
      case PaperCheckSort.oldest:
        records.sort(
          (a, b) => (a.createdAt ?? DateTime(0))
              .compareTo(b.createdAt ?? DateTime(0)),
        );
      case PaperCheckSort.highestScore:
        records.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    }
    return records;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Check History'),
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
              'No paper checks yet.\nCheck a manuscript and it will show up '
              'here so you can compare it against later checks.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildControls(),
        const SizedBox(height: 12),
        for (final record in _visibleRecords) _buildCheckCard(record),
      ],
    );
  }

  // Sort dropdown, matching the Session History control.
  Widget _buildControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.sort, size: 18, color: AppColors.textGrey),
            const SizedBox(width: 8),
            DropdownButton<PaperCheckSort>(
              value: _sort,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: PaperCheckSort.newest,
                  child: Text('Newest first'),
                ),
                DropdownMenuItem(
                  value: PaperCheckSort.oldest,
                  child: Text('Oldest first'),
                ),
                DropdownMenuItem(
                  value: PaperCheckSort.highestScore,
                  child: Text('Highest score'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _sort = value ?? PaperCheckSort.newest),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckCard(PaperCheckRecord record) {
    final color = _scoreColor(record.percent);
    final previous = _previousById[record.id];
    final dateLabel = record.createdAt == null
        ? 'Just now'
        : DateFormat('MMM d, yyyy - h:mm a').format(record.createdAt!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        // Drop the ExpansionTile's default divider lines for a cleaner card.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(Icons.description_outlined, color: color),
          ),
          title: Text(
            record.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    record.verdict,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (previous != null)
                    _deltaChip(
                      record.totalScore,
                      previous.totalScore,
                      label: 'vs previous',
                    ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${record.totalScore}/${record.maxScore}',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'SCORE',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          children: [_buildBreakdown(record, previous)],
        ),
      ),
    );
  }

  // The expanded body: overall summary, per-chapter scores with deltas, and the
  // layout compliance count when the check was run on a .docx.
  Widget _buildBreakdown(
    PaperCheckRecord record,
    PaperCheckRecord? previous,
  ) {
    // Match previous sections by name so a per-chapter delta survives any
    // reordering in the stored data.
    final prevByName = {
      for (final s in previous?.sections ?? const []) s.name: s.score,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (record.summary.isNotEmpty) ...[
          Text(record.summary, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
        ],
        const Text(
          'Score breakdown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        for (final section in record.sections)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(section.name)),
                if (prevByName.containsKey(section.name)) ...[
                  _deltaChip(section.score, prevByName[section.name]!),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${section.score}/${section.max}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        if (record.hasLayout) ...[
          const Divider(height: 24),
          Row(
            children: [
              const Icon(
                Icons.rule_folder_outlined,
                size: 18,
                color: AppColors.textGrey,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Layout compliance (Section 10.3)')),
              Text(
                '${record.layoutPassCount}/${record.layoutTotal}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
        if (previous == null) ...[
          const SizedBox(height: 12),
          const Text(
            'This is your first saved check - run another to see what changed.',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  // A small +/- pill comparing [current] to [previous]. Up is green, down is
  // the app danger tone, no change is grey. [label] appends context, e.g.
  // "vs previous", for the header delta.
  Widget _deltaChip(int current, int previous, {String? label}) {
    final diff = current - previous;
    final Color color;
    final IconData icon;
    final String text;
    if (diff > 0) {
      color = Colors.green.shade700;
      icon = Icons.arrow_upward;
      text = '+$diff';
    } else if (diff < 0) {
      color = AppColors.danger;
      icon = Icons.arrow_downward;
      text = '$diff';
    } else {
      color = AppColors.textGrey;
      icon = Icons.remove;
      text = 'same';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 2),
          Text(
            label == null ? text : '$text $label',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Same score bands as the Paper Checker screen, so a score reads the same
  // colour in history as it did on the result.
  Color _scoreColor(double ratio) {
    if (ratio >= 0.75) return Colors.green.shade700;
    if (ratio >= 0.5) return Colors.orange.shade800;
    return AppColors.primary;
  }
}
