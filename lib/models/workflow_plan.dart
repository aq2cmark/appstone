import 'dart:convert';

// One unit of work in the capstone timeline (usually a chapter or a phase like
// "Prototype Development"). `weight` is a relative share of effort the AI
// assigns; the schedule turns weights into actual day ranges.
class WorkflowPhase {
  WorkflowPhase({
    required this.name,
    required this.weight,
    required this.note,
    this.done = false,
    this.completedOn,
  });

  final String name;
  final double weight;
  final String note;
  bool done;
  DateTime? completedOn;

  Map<String, dynamic> toJson() => {
        'name': name,
        'weight': weight,
        'note': note,
        'done': done,
        'completedOn': completedOn?.toIso8601String(),
      };

  factory WorkflowPhase.fromJson(Map<String, dynamic> json) => WorkflowPhase(
        name: json['name'] as String? ?? 'Phase',
        weight: (json['weight'] as num?)?.toDouble() ?? 1,
        note: json['note'] as String? ?? '',
        done: json['done'] as bool? ?? false,
        completedOn: json['completedOn'] == null
            ? null
            : DateTime.tryParse(json['completedOn'] as String),
      );
}

// A phase after scheduling: the concrete date window it lands in and how it
// sits relative to the deadline. Recomputed live so it always reflects "today"
// and any phases already ticked off.
class ScheduledPhase {
  ScheduledPhase({
    required this.phase,
    required this.start,
    required this.end,
    required this.days,
    required this.isOverdue,
  });

  final WorkflowPhase phase;
  final DateTime start;
  final DateTime end;
  final int days;
  // Only meaningful for not-done phases: its window runs past the deadline.
  final bool isOverdue;
}

// The whole plan: when it started, how long the student has, the AI's read on
// the paper, and the ordered phases. All scheduling is derived from this plus
// the current date, so finishing a phase early automatically relaxes the rest.
class WorkflowPlan {
  WorkflowPlan({
    required this.startDate,
    required this.totalDays,
    required this.assessment,
    required this.paperName,
    required this.phases,
  });

  final DateTime startDate;
  final int totalDays;
  final String assessment;
  final String? paperName;
  final List<WorkflowPhase> phases;

  DateTime get deadline => _dateOnly(startDate).add(Duration(days: totalDays));

  int get doneCount => phases.where((p) => p.done).length;
  int get totalCount => phases.length;
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  int daysRemaining([DateTime? now]) {
    final today = _dateOnly(now ?? DateTime.now());
    return deadline.difference(today).inDays;
  }

  // Builds the live schedule. Completed phases keep their real completion date;
  // every remaining phase is laid out sequentially from today and shares the
  // time left until the deadline in proportion to its weight. So if a phase is
  // finished early, the leftover days flow into the phases that remain.
  List<ScheduledPhase> schedule([DateTime? now]) {
    final today = _dateOnly(now ?? DateTime.now());
    final result = <ScheduledPhase>[];

    final remaining = phases.where((p) => !p.done).toList();
    final anchor = today.isAfter(_dateOnly(startDate))
        ? today
        : _dateOnly(startDate);
    final budget = deadline.difference(anchor).inDays;
    final allocations = _allocateDays(
      remaining.map((p) => p.weight).toList(),
      budget,
    );

    var cursor = anchor;
    var alloc = 0;
    for (final phase in phases) {
      if (phase.done) {
        final on = _dateOnly(phase.completedOn ?? today);
        result.add(
          ScheduledPhase(
            phase: phase,
            start: on,
            end: on,
            days: 0,
            isOverdue: false,
          ),
        );
      } else {
        final days = allocations[alloc++];
        final start = cursor;
        final end = start.add(Duration(days: days));
        result.add(
          ScheduledPhase(
            phase: phase,
            start: start,
            end: end,
            days: days,
            isOverdue: end.isAfter(deadline),
          ),
        );
        cursor = end;
      }
    }
    return result;
  }

  // Projected finish date = end of the last remaining phase (or the last
  // completion date if everything is done). Compared with the deadline this
  // tells the student whether they are on track.
  DateTime projectedFinish([DateTime? now]) {
    final scheduled = schedule(now);
    if (scheduled.isEmpty) return deadline;
    return scheduled
        .map((s) => s.end)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  bool isOnTrack([DateTime? now]) =>
      !projectedFinish(now).isAfter(deadline);

  // Splits `totalDays` across the given weights so every phase gets at least
  // one day and the parts sum to the budget (or to the phase count when time
  // is too short - the schedule then simply runs past the deadline, which the
  // UI surfaces as "behind schedule").
  static List<int> _allocateDays(List<double> weights, int totalDays) {
    final n = weights.length;
    if (n == 0) return const [];
    final budget = totalDays < n ? n : totalDays;
    final sumW = weights.fold<double>(0, (a, b) => a + (b <= 0 ? 0 : b));

    final raw = weights
        .map((w) => sumW > 0 ? budget * (w <= 0 ? 0 : w) / sumW : budget / n)
        .toList();
    final result = raw.map((r) => r.floor().clamp(1, budget)).toList();

    var used = result.fold<int>(0, (a, b) => a + b);
    var remainder = budget - used;
    if (remainder > 0) {
      // Hand out the leftover days to the phases with the biggest rounded-off
      // fraction first, so allocation stays proportional.
      final order = List.generate(n, (i) => i)
        ..sort((a, b) =>
            (raw[b] - result[b]).compareTo(raw[a] - result[a]));
      var i = 0;
      while (remainder > 0) {
        result[order[i % n]] += 1;
        remainder--;
        i++;
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'startDate': startDate.toIso8601String(),
        'totalDays': totalDays,
        'assessment': assessment,
        'paperName': paperName,
        'phases': phases.map((p) => p.toJson()).toList(),
      };

  factory WorkflowPlan.fromJson(Map<String, dynamic> json) => WorkflowPlan(
        startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ??
            DateTime.now(),
        totalDays: (json['totalDays'] as num?)?.toInt() ?? 30,
        assessment: json['assessment'] as String? ?? '',
        paperName: json['paperName'] as String?,
        phases: ((json['phases'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WorkflowPhase.fromJson)
            .toList(),
      );

  String encode() => jsonEncode(toJson());

  static WorkflowPlan? decode(String raw) {
    try {
      return WorkflowPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
