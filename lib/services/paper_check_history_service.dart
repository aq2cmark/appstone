import 'package:cloud_firestore/cloud_firestore.dart';

// One rubric section's score inside a saved paper check. Kept alongside the
// total so the history screen can show which chapters improved or slipped
// between checks, not just the overall number.
class PaperCheckSectionScore {
  const PaperCheckSectionScore({
    required this.name,
    required this.score,
    required this.max,
    this.comment = '',
    this.issues = const <String>[],
  });

  factory PaperCheckSectionScore.fromMap(Map<String, dynamic> map) {
    return PaperCheckSectionScore(
      name: map['name'] as String? ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      max: (map['max'] as num?)?.toInt() ?? 0,
      // Absent on checks saved before the feedback was persisted; those
      // records still render, just without their comments.
      comment: map['comment'] as String? ?? '',
      issues: ((map['issues'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  final String name;
  final int score;
  final int max;
  final String comment;
  final List<String> issues;

  Map<String, dynamic> toMap() => {
    'name': name,
    'score': score,
    'max': max,
    if (comment.isNotEmpty) 'comment': comment,
    if (issues.isNotEmpty) 'issues': issues,
  };
}

// One finished paper check, as stored in the `paper_checks` Firestore
// collection. Mirrors PracticeSessionRecord: a compact snapshot of a completed
// check so a student can look back and compare how the manuscript improved over
// time. Only successful checks (a real score) are saved - errors are never
// recorded.
class PaperCheckRecord {
  const PaperCheckRecord({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.fileName,
    required this.totalScore,
    required this.maxScore,
    required this.verdict,
    required this.summary,
    required this.sections,
    required this.layoutPassCount,
    required this.layoutTotal,
    required this.createdAt,
    required this.contentHash,
  });

  factory PaperCheckRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final rawSections = (data['sections'] as List?) ?? const [];
    return PaperCheckRecord(
      id: snapshot.id,
      groupId: data['groupId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      fileName: data['fileName'] as String? ?? 'Manuscript',
      totalScore: (data['totalScore'] as num?)?.toInt() ?? 0,
      maxScore: (data['maxScore'] as num?)?.toInt() ?? 0,
      verdict: data['verdict'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      sections: rawSections
          .whereType<Map<String, dynamic>>()
          .map(PaperCheckSectionScore.fromMap)
          .toList(),
      layoutPassCount: (data['layoutPassCount'] as num?)?.toInt(),
      layoutTotal: (data['layoutTotal'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      contentHash: data['contentHash'] as String? ?? '',
    );
  }

  final String id;
  final String groupId;
  final String studentId;
  final String fileName;
  final int totalScore;
  final int maxScore;
  // Plain-language band snapshot ('Excellent', etc.) taken at check time.
  final String verdict;
  final String summary;
  final List<PaperCheckSectionScore> sections;
  // Null for non-.docx uploads, where layout couldn't be measured.
  final int? layoutPassCount;
  final int? layoutTotal;
  // Null only for the brief moment before the server timestamp resolves.
  final DateTime? createdAt;
  // Fingerprint of the graded content. Empty on checks saved before caching
  // existed - those simply never match and get re-graded once.
  final String contentHash;

  double get percent => maxScore == 0 ? 0 : totalScore / maxScore;
  bool get hasLayout => layoutPassCount != null && layoutTotal != null;
}

// Firestore layer for paper check history. Kept separate from the check
// controller (which computes the review) so persistence is one small, testable
// unit - the exact split PracticeHistoryService uses for defense practice.
class PaperCheckHistoryService {
  PaperCheckHistoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Called from the check controller right after a check finishes scoring.
  // Failures are the caller's to swallow - saving history must never turn a
  // finished, on-screen result into an error.
  Future<void> saveCheck({
    required String groupId,
    required String studentId,
    required String fileName,
    required int totalScore,
    required int maxScore,
    required String verdict,
    required String summary,
    required List<PaperCheckSectionScore> sections,
    int? layoutPassCount,
    int? layoutTotal,
    String contentHash = '',
  }) {
    return _firestore.collection('paper_checks').add({
      'groupId': groupId,
      'studentId': studentId,
      'fileName': fileName,
      'totalScore': totalScore,
      'maxScore': maxScore,
      'verdict': verdict,
      'summary': summary,
      'sections': sections.map((s) => s.toMap()).toList(),
      if (layoutPassCount != null) 'layoutPassCount': layoutPassCount,
      if (layoutTotal != null) 'layoutTotal': layoutTotal,
      if (contentHash.isNotEmpty) 'contentHash': contentHash,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // The most recent check of this exact content, or null if it has never been
  // graded. This is what makes a re-upload return the identical score: the
  // model is never asked twice about the same manuscript. Equality filters
  // only, like fetchChecks, so no composite index is needed.
  Future<PaperCheckRecord?> findByContentHash({
    required String groupId,
    required String studentId,
    required String contentHash,
  }) async {
    if (contentHash.isEmpty) return null;
    final snapshot = await _firestore
        .collection('paper_checks')
        .where('groupId', isEqualTo: groupId)
        .where('studentId', isEqualTo: studentId)
        .where('contentHash', isEqualTo: contentHash)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final records = snapshot.docs.map(PaperCheckRecord.fromSnapshot).toList();
    records.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(0);
      final bTime = b.createdAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return records.first;
  }

  // The student's most recent check, or null if they have never run one.
  // Used to put the last result back on the Paper Checker after a restart:
  // the on-screen result lives in memory, which a page reload throws away,
  // even though the check itself is already saved here.
  Future<PaperCheckRecord?> fetchLatest({
    required String groupId,
    required String studentId,
  }) async {
    final records = await fetchChecks(groupId: groupId, studentId: studentId);
    return records.isEmpty ? null : records.first;
  }

  // All checks for one student, newest first. Uses equality filters only (no
  // orderBy) so Firestore needs no composite index; sorting happens here.
  Future<List<PaperCheckRecord>> fetchChecks({
    required String groupId,
    required String studentId,
  }) async {
    final snapshot = await _firestore
        .collection('paper_checks')
        .where('groupId', isEqualTo: groupId)
        .where('studentId', isEqualTo: studentId)
        .get();
    final records = snapshot.docs.map(PaperCheckRecord.fromSnapshot).toList();
    records.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(0);
      final bTime = b.createdAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return records;
  }
}
