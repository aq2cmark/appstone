import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'docx_layout_checker.dart';
import 'document_text_extractor.dart';
import 'paper_check_history_service.dart';
import 'paper_checker_service.dart';

// Holds the state of the current (or most recent) paper check ABOVE the screen,
// so a check keeps running when the user leaves the Paper Checker and the
// result is still there when they come back. It's a singleton because only one
// check runs at a time.
class PaperCheckController extends ChangeNotifier {
  PaperCheckController._();
  static final PaperCheckController instance = PaperCheckController._();

  final _extractor = DocumentTextExtractor();
  final _service = PaperCheckerService();
  final _layoutChecker = DocxLayoutChecker();
  final _history = PaperCheckHistoryService();

  bool _running = false;
  bool _restoring = false;
  bool _restoreDone = false;
  String? _fileName;
  PaperReview? _review;
  LayoutReport? _layout;
  bool _layoutSkipped = false;
  String? _error;
  DateTime? _reusedFrom;
  PaperCheckRecord? _restoredFrom;
  // Which student the visible result belongs to, so one student's remarks are
  // never left on screen for the next person to sign in on the same device.
  String? _ownerStudentId;

  bool get running => _running;
  // True while the last saved check is being fetched back after a restart.
  bool get restoring => _restoring;
  String? get fileName => _fileName;
  PaperReview? get review => _review;
  LayoutReport? get layout => _layout;
  bool get layoutSkipped => _layoutSkipped;
  String? get error => _error;
  // Set when this result came from a previous check of identical content
  // rather than a fresh grading run. The screen uses it to say so.
  DateTime? get reusedFrom => _reusedFrom;
  // The saved check this result was read back from, set only when the result
  // was restored after a restart rather than produced in this session. The
  // screen uses it to name the file and say when it was checked.
  PaperCheckRecord? get restoredFrom => _restoredFrom;
  bool get hasResult => _review != null || _error != null;

  // Starts checking [file] in the background. Safe to call away from any screen;
  // listeners (the screen, when open) rebuild as it progresses. The student
  // identity is passed in (read from prefs by the screen, as defense practice
  // does) so a finished check can be logged to history without this service
  // layer reaching into SharedPreferences itself.
  Future<void> start(
    PlatformFile file, {
    String? groupId,
    String? studentId,
  }) async {
    if (_running) return;
    _running = true;
    _error = null;
    _ownerStudentId = studentId;
    notifyListeners();

    // The run builds its result in locals and only commits it once it has one.
    // The previous check's fields are left standing until then, so a run that
    // fails - an exhausted daily allowance, a file that will not parse - leaves
    // the student the remarks they already had instead of clearing the screen
    // in exchange for an error. Nothing stale is on show meanwhile: the screen
    // renders its running state while `_running` is true.
    LayoutReport? layout;
    var layoutSkipped = false;

    try {
      // Deterministic .docx-only layout check first; kept even if the AI check
      // later fails.
      final bytes = file.bytes;
      final isDocx = (file.extension ?? '').toLowerCase() == 'docx';
      if (isDocx && bytes != null) {
        try {
          layout = _layoutChecker.check(bytes);
        } catch (_) {
          layoutSkipped = true;
        }
      } else {
        layoutSkipped = true;
      }

      final text = await _extractor.extract(file);
      final hash = _contentHash(text, layout);

      // Identical content was already graded, so reuse that verdict instead of
      // asking the model again. This is what makes the same manuscript score
      // the same twice: an LLM re-run drifts by a point or two per section
      // even at temperature 0, and those add up across the rubric. Reusing
      // also costs the student nothing against the daily AI allowance.
      final previous = await _findPrevious(hash, groupId, studentId);
      if (previous != null) {
        _commit(
          fileName: file.name,
          review: _reviewFromRecord(previous),
          layout: layout,
          layoutSkipped: layoutSkipped,
          reusedFrom: previous.createdAt,
        );
        return;
      }

      _commit(
        fileName: file.name,
        review: await _service.checkPaper(paperText: text, layout: layout),
        layout: layout,
        layoutSkipped: layoutSkipped,
      );
      // Log this finished check so the student can compare it against earlier
      // ones. Kept inside the try (only successful checks are worth saving) but
      // self-contained so a history failure never becomes a check error.
      await _saveToHistory(file, groupId, studentId, hash);
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  // Puts the student's most recent completed check back on screen. The result
  // of a check lives in this object, and closing the tab or restarting the app
  // throws that away - so a student came back to an empty checker even though
  // the check itself was already saved in their history. This reads that saved
  // record back. Nothing new is stored: it is the same document the Check
  // History screen already lists.
  //
  // Deliberately never overwrites a result that is already here. A check in
  // flight, or one that finished in this session, is the newer truth - the
  // saved record only fills the gap a restart leaves.
  Future<void> restoreLast({String? groupId, String? studentId}) async {
    // A different student has signed in on this device since the visible
    // result was produced. Their predecessor's remarks are not theirs to read.
    if (_ownerStudentId != null && _ownerStudentId != studentId) _clear();

    if (_running || _restoring || _restoreDone || hasResult) return;
    if (groupId == null || studentId == null) return;

    _restoring = true;
    notifyListeners();
    try {
      final last = await _history.fetchLatest(
        groupId: groupId,
        studentId: studentId,
      );
      // Only a completed lookup counts as done. A failed one leaves the flag
      // clear so the next visit to the screen tries again.
      _restoreDone = true;
      if (last != null) {
        _ownerStudentId = studentId;
        _commit(
          fileName: last.fileName,
          review: _reviewFromRecord(last),
          // A saved check keeps the formatting tally but not the individual
          // rules, which were measured from a file we no longer hold. The
          // screen shows the tally and says where to get the detail back.
          layout: null,
          layoutSkipped: false,
          restoredFrom: last,
        );
      }
    } catch (_) {
      // Offline, or history unreadable. Having nothing to restore is not an
      // error worth showing: the student simply gets the empty checker they
      // would have had anyway, and can run a fresh check.
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  // Wipes the visible result outright. Only for when it stops being the
  // current student's to see - a finished check is otherwise kept until a new
  // one replaces it.
  void _clear() {
    _fileName = null;
    _review = null;
    _layout = null;
    _layoutSkipped = false;
    _error = null;
    _reusedFrom = null;
    _restoredFrom = null;
    _ownerStudentId = null;
    _restoreDone = false;
    notifyListeners();
  }

  // Replaces the visible result with a finished one, in a single step so the
  // fields are never a mix of two different checks.
  void _commit({
    required String fileName,
    required PaperReview review,
    required LayoutReport? layout,
    required bool layoutSkipped,
    DateTime? reusedFrom,
    PaperCheckRecord? restoredFrom,
  }) {
    _fileName = fileName;
    _review = review;
    _layout = layout;
    _layoutSkipped = layoutSkipped;
    _reusedFrom = reusedFrom;
    _restoredFrom = restoredFrom;
  }

  // Best-effort write to paper check history. Needs a completed review and a
  // signed-in student; any failure is swallowed so the on-screen result stands.
  Future<void> _saveToHistory(
    PlatformFile file,
    String? groupId,
    String? studentId,
    String contentHash,
  ) async {
    final review = _review;
    if (review == null || groupId == null || studentId == null) return;
    try {
      await _history.saveCheck(
        groupId: groupId,
        studentId: studentId,
        fileName: file.name,
        totalScore: review.totalScore,
        maxScore: review.maxScore,
        verdict: review.verdict,
        summary: review.summary,
        sections: review.sections
            .map(
              (s) => PaperCheckSectionScore(
                name: s.name,
                score: s.score,
                max: s.max,
                comment: s.comment,
                issues: s.issues,
              ),
            )
            .toList(),
        layoutPassCount: _layout?.passCount,
        layoutTotal: _layout?.total,
        contentHash: contentHash,
      );
    } catch (_) {
      // History is a nice-to-have; the finished result is already on screen.
    }
  }

  // Fingerprint of everything the grade depends on. The layout report is part
  // of it because Manuscript Mechanics is scored partly from those
  // measurements, and _checkerVersion is part of it so that changing the
  // rubric or the prompt retires every cached result rather than serving
  // grading the current app would no longer produce.
  static const int _checkerVersion = 2;

  // Exposed so the caching guarantee can be tested directly: identical
  // content must always fingerprint identically, or a re-upload silently
  // becomes a fresh grading run again.
  @visibleForTesting
  static String contentHashOf(String text, LayoutReport? layout) =>
      _contentHash(text, layout);

  static String _contentHash(String text, LayoutReport? layout) {
    final layoutSignature = layout == null
        ? 'none'
        : layout.rules.map((r) => '${r.name}=${r.pass}').join(';');
    return sha256
        .convert(utf8.encode('v$_checkerVersion|$layoutSignature|$text'))
        .toString();
  }

  // Best-effort: a lookup failure (offline, rules, whatever) must never stop a
  // check - it just means this one gets graded fresh.
  Future<PaperCheckRecord?> _findPrevious(
    String hash,
    String? groupId,
    String? studentId,
  ) async {
    if (groupId == null || studentId == null) return null;
    try {
      return await _history.findByContentHash(
        groupId: groupId,
        studentId: studentId,
        contentHash: hash,
      );
    } catch (_) {
      return null;
    }
  }

  // Rebuilds the on-screen review from a stored check, so a reused result shows
  // exactly what the original run showed.
  PaperReview _reviewFromRecord(PaperCheckRecord record) {
    return PaperReview(
      summary: record.summary,
      sections: <RubricResult>[
        for (final section in record.sections)
          RubricResult(
            name: section.name,
            max: section.max,
            score: section.score,
            comment: section.comment,
            issues: section.issues,
          ),
      ],
    );
  }

  // Drops a failed check while leaving a completed one alone. Called when a new
  // file is picked.
  //
  // Picking a file used to clear the whole result, which threw away the remarks
  // the student came here for the moment they reached for their next draft -
  // before the new check had even started, and whether or not it ever ran. A
  // finished review is the product of this screen and now survives until a new
  // check replaces it in start(). An error is not: it describes an attempt that
  // has been moved on from, and leaving it up would make the screen look broken
  // next to a freshly chosen file.
  //
  // `_fileName` is deliberately left alone: it now names the check whose remarks
  // are still on screen, not the attempt that failed, and clearing it would
  // leave those remarks unlabelled.
  //
  // No-op while a check is still running.
  void clearError() {
    if (_running || _error == null) return;
    _error = null;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is DocumentExtractionException) return error.message;
    if (error is StateError) return error.message;
    return 'Something went wrong while checking the paper. Please try again.';
  }
}

