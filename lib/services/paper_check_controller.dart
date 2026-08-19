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
  String? _fileName;
  PaperReview? _review;
  LayoutReport? _layout;
  bool _layoutSkipped = false;
  String? _error;
  DateTime? _reusedFrom;

  bool get running => _running;
  String? get fileName => _fileName;
  PaperReview? get review => _review;
  LayoutReport? get layout => _layout;
  bool get layoutSkipped => _layoutSkipped;
  String? get error => _error;
  // Set when this result came from a previous check of identical content
  // rather than a fresh grading run. The screen uses it to say so.
  DateTime? get reusedFrom => _reusedFrom;
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
    _fileName = file.name;
    _review = null;
    _layout = null;
    _layoutSkipped = false;
    _error = null;
    _reusedFrom = null;
    notifyListeners();

    try {
      // Deterministic .docx-only layout check first; kept even if the AI check
      // later fails.
      final bytes = file.bytes;
      final isDocx = (file.extension ?? '').toLowerCase() == 'docx';
      if (isDocx && bytes != null) {
        try {
          _layout = _layoutChecker.check(bytes);
        } catch (_) {
          _layoutSkipped = true;
        }
      } else {
        _layoutSkipped = true;
      }
      notifyListeners();

      final text = await _extractor.extract(file);
      final hash = _contentHash(text, _layout);

      // Identical content was already graded, so reuse that verdict instead of
      // asking the model again. This is what makes the same manuscript score
      // the same twice: an LLM re-run drifts by a point or two per section
      // even at temperature 0, and those add up across the rubric. Reusing
      // also costs the student nothing against the daily AI allowance.
      final previous = await _findPrevious(hash, groupId, studentId);
      if (previous != null) {
        _review = _reviewFromRecord(previous);
        _reusedFrom = previous.createdAt;
        return;
      }

      _review = await _service.checkPaper(paperText: text, layout: _layout);
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

  // Clears the last result (e.g. when a new file is picked). No-op while a check
  // is still running.
  void reset() {
    if (_running) return;
    _fileName = null;
    _review = null;
    _layout = null;
    _layoutSkipped = false;
    _error = null;
    _reusedFrom = null;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is DocumentExtractionException) return error.message;
    if (error is StateError) return error.message;
    return 'Something went wrong while checking the paper. Please try again.';
  }
}

