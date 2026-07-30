import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// What the student tells the panel about their capstone before a practice run.
//
// Without this, the AI only sees a generic question and the student's answer, so
// its follow-ups and scoring can only be generic too. With it, the panel knows
// what the project actually is and can press on the real thing ("you said you
// use Firebase - how does that handle offline use?") instead of guessing.
//
// Every field is optional: a student who fills in nothing still gets the same
// practice they got before this existed.
class DefenseContext {
  const DefenseContext({
    this.projectTitle = '',
    this.problem = '',
    this.techStack = '',
    this.targetUsers = '',
    this.notes = '',
  });

  factory DefenseContext.decode(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return DefenseContext(
        projectTitle: data['projectTitle'] as String? ?? '',
        problem: data['problem'] as String? ?? '',
        techStack: data['techStack'] as String? ?? '',
        targetUsers: data['targetUsers'] as String? ?? '',
        notes: data['notes'] as String? ?? '',
      );
    } catch (_) {
      // A corrupt or older payload just means "no context yet" - never a crash
      // on the way into a practice session.
      return const DefenseContext();
    }
  }

  final String projectTitle;
  // What the system does and the problem it solves.
  final String problem;
  final String techStack;
  final String targetUsers;
  // Free-form: anything else the panel should know (features, scope, known
  // weaknesses the student wants to be grilled on).
  final String notes;

  // Long answers are the student's own words, but the prompt still has a budget,
  // so each field is capped when rendered for the AI.
  static const _fieldLimit = 400;
  static const _notesLimit = 1200;

  List<String> get _values => [
    projectTitle,
    problem,
    techStack,
    targetUsers,
    notes,
  ];

  bool get isEmpty => _values.every((value) => value.trim().isEmpty);
  bool get isNotEmpty => !isEmpty;

  // How many of the five fields the student actually filled in - shown on the
  // Defense Practice menu so they can see at a glance how much the panel knows.
  int get filledCount =>
      _values.where((value) => value.trim().isNotEmpty).length;
  int get fieldCount => _values.length;

  DefenseContext copyWith({
    String? projectTitle,
    String? problem,
    String? techStack,
    String? targetUsers,
    String? notes,
  }) {
    return DefenseContext(
      projectTitle: projectTitle ?? this.projectTitle,
      problem: problem ?? this.problem,
      techStack: techStack ?? this.techStack,
      targetUsers: targetUsers ?? this.targetUsers,
      notes: notes ?? this.notes,
    );
  }

  String encode() => jsonEncode({
    'projectTitle': projectTitle,
    'problem': problem,
    'techStack': techStack,
    'targetUsers': targetUsers,
    'notes': notes,
  });

  static String _trim(String value, int limit) {
    final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return clean.length <= limit ? clean : '${clean.substring(0, limit)}...';
  }

  // The block dropped into every AI prompt for this run. Empty fields are left
  // out entirely rather than sent as blanks the model has to interpret, and the
  // whole thing is empty when the student added nothing - so the prompts read
  // exactly as they did before when there's no context to give.
  String get promptBlock {
    if (isEmpty) return '';
    final lines = <String>[
      if (projectTitle.trim().isNotEmpty)
        'Project title: ${_trim(projectTitle, _fieldLimit)}',
      if (problem.trim().isNotEmpty)
        'What it does / problem solved: ${_trim(problem, _fieldLimit)}',
      if (techStack.trim().isNotEmpty)
        'Technology stack: ${_trim(techStack, _fieldLimit)}',
      if (targetUsers.trim().isNotEmpty)
        'Target users: ${_trim(targetUsers, _fieldLimit)}',
      if (notes.trim().isNotEmpty)
        'Other notes from the student: ${_trim(notes, _notesLimit)}',
    ];
    return lines.join('\n');
  }
}

// Saves the context on-device, the same way the AI Workflow plan is kept, so it
// survives closing the app and is reused by every later practice session until
// the student edits or clears it.
class DefenseContextService {
  static const _prefsKey = 'defense_context_v1';

  Future<DefenseContext> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    return raw == null ? const DefenseContext() : DefenseContext.decode(raw);
  }

  Future<void> save(DefenseContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (context.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setString(_prefsKey, context.encode());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
