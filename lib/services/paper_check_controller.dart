import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'docx_layout_checker.dart';
import 'document_text_extractor.dart';
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

  bool _running = false;
  String? _fileName;
  PaperReview? _review;
  LayoutReport? _layout;
  bool _layoutSkipped = false;
  String? _error;

  bool get running => _running;
  String? get fileName => _fileName;
  PaperReview? get review => _review;
  LayoutReport? get layout => _layout;
  bool get layoutSkipped => _layoutSkipped;
  String? get error => _error;
  bool get hasResult => _review != null || _error != null;

  // Starts checking [file] in the background. Safe to call away from any screen;
  // listeners (the screen, when open) rebuild as it progresses.
  Future<void> start(PlatformFile file) async {
    if (_running) return;
    _running = true;
    _fileName = file.name;
    _review = null;
    _layout = null;
    _layoutSkipped = false;
    _error = null;
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
      _review = await _service.checkPaper(paperText: text);
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _running = false;
      notifyListeners();
    }
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
    notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is DocumentExtractionException) return error.message;
    if (error is StateError) return error.message;
    return 'Something went wrong while checking the paper. Please try again.';
  }
}
