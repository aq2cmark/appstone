import 'package:cloud_firestore/cloud_firestore.dart';

// One rubric section's score inside a saved paper check. Kept alongside the
// total so the history screen can show which chapters improved or slipped
// between checks, not just the overall number.
class PaperCheckSectionScore {
  const PaperCheckSectionScore({
    required this.name,
    required this.score,
    required this.max,
  });

  factory PaperCheckSectionScore.fromMap(Map<String, dynamic> map) {
    return PaperCheckSectionScore(
      name: map['name'] as String? ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      max: (map['max'] as num?)?.toInt() ?? 0,
    );
  }

  final String name;
  final int score;
  final int max;

  Map<String, dynamic> toMap() => {'name': name, 'score': score, 'max': max};
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
      'createdAt': FieldValue.serverTimestamp(),
    });
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
