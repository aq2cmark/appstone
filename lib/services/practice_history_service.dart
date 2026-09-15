import 'package:cloud_firestore/cloud_firestore.dart';

// One finished defense practice session, as stored in the
// `practice_sessions` Firestore collection. Only sessions that reached the
// results screen are saved - abandoned sessions are never recorded.
class PracticeSessionRecord {
  const PracticeSessionRecord({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.sessionType,
    required this.questionsAnswered,
    required this.durationSeconds,
    required this.overallScore,
    required this.createdAt,
  });

  factory PracticeSessionRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return PracticeSessionRecord(
      id: snapshot.id,
      groupId: data['groupId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      sessionType: data['sessionType'] as String? ?? 'Practice',
      questionsAnswered: (data['questionsAnswered'] as num?)?.toInt() ?? 0,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      overallScore: (data['overallScore'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String groupId;
  final String studentId;
  // 'Title Defense', 'Oral Defense', or 'Final Defense' - the same title the
  // practice screen shows, so history rows match what the student practiced.
  final String sessionType;
  final int questionsAnswered;
  final int durationSeconds;
  final int overallScore;
  // Null only for the brief moment before the server timestamp resolves.
  final DateTime? createdAt;

  // Duration formatted as m:ss (e.g. 12:07) for history rows.
  String get durationLabel {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// Firestore layer for defense practice history, kept separate from
// AdminRepository because it is student-facing, not admin-facing.
class PracticeHistoryService {
  PracticeHistoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Called from the practice screen right after the AI scores a finished
  // session. Failures here are the caller's to swallow - saving history must
  // never block the student from seeing their results.
  Future<void> saveSession({
    required String groupId,
    required String studentId,
    required String sessionType,
    required int questionsAnswered,
    required int durationSeconds,
    required int overallScore,
  }) {
    return _firestore.collection('practice_sessions').add({
      'groupId': groupId,
      'studentId': studentId,
      'sessionType': sessionType,
      'questionsAnswered': questionsAnswered,
      'durationSeconds': durationSeconds,
      'overallScore': overallScore,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // All sessions for one student, newest first. Uses equality filters only
  // (no orderBy) so Firestore needs no composite index; sorting happens here.
  Future<List<PracticeSessionRecord>> fetchSessions({
    required String groupId,
    required String studentId,
  }) async {
    final snapshot = await _firestore
        .collection('practice_sessions')
        .where('groupId', isEqualTo: groupId)
        .where('studentId', isEqualTo: studentId)
        .get();
    final records =
        snapshot.docs.map(PracticeSessionRecord.fromSnapshot).toList();
    records.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(0);
      final bTime = b.createdAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return records;
  }
}
