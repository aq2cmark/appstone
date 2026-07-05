import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../app_colors.dart';
import '../services/docx_layout_checker.dart';
import '../services/document_text_extractor.dart';
import '../services/paper_checker_service.dart';

// Paper Checker: uploads a capstone manuscript, extracts its text, and grades
// it against Section 8.3 of the Capstone Manual (the 50-point manuscript
// rubric). It reports a score per rubric section plus the concrete "wrongs"
// the student needs to fix.
class PaperCheckerScreen extends StatefulWidget {
  const PaperCheckerScreen({super.key});

  @override
  State<PaperCheckerScreen> createState() => _PaperCheckerScreenState();
}

class _PaperCheckerScreenState extends State<PaperCheckerScreen> {
  final _extractor = DocumentTextExtractor();
  final _service = PaperCheckerService();
  final _layoutChecker = DocxLayoutChecker();

  PlatformFile? _selectedFile;
  bool _checking = false;
  String? _error;
  PaperReview? _review;
  LayoutReport? _layout;
  // True after a check ran on a non-.docx file, so we can explain why the
  // layout section is missing.
  bool _layoutSkipped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Paper Checker'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Upload your capstone manuscript. It is graded against the '
                    'Capstone Manual manuscript rubric (50 pts), with the exact '
                    'issues to fix in each chapter.',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  _buildUploadCard(),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _checking ? null : _runCheck,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.fact_check),
                    label: Text(_checking ? 'Checking...' : 'Check Paper'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorCard(_error!),
                  ],
                  if (_review != null) ...[
                    const SizedBox(height: 20),
                    _buildScoreCard(_review!),
                  ],
                  if (_layout != null) ...[
                    const SizedBox(height: 16),
                    _buildLayoutCard(_layout!),
                  ] else if (_layoutSkipped) ...[
                    const SizedBox(height: 16),
                    _buildLayoutNote(),
                  ],
                  if (_review != null) ...[
                    const SizedBox(height: 16),
                    for (final section in _review!.sections)
                      _buildSectionCard(section),
                    const SizedBox(height: 8),
                    const Text(
                      'This is an AI pre-check to help you improve the paper. '
                      'It is not the official panel grade, which also weighs the '
                      'software and oral defense.',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.upload_file, color: AppColors.primary, size: 56),
            const SizedBox(height: 12),
            Text(
              _selectedFile?.name ?? 'Tap to select document',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFile == null
                  ? 'PDF, DOCX, or TXT'
                  : _fileSizeText(_selectedFile!.size),
              style: const TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _checking ? null : _pickPaper,
              icon: const Icon(Icons.folder_open),
              label: const Text('Select File'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      color: const Color(0xFFFDECEC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(PaperReview review) {
    final color = _scoreColor(review.percent);
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manuscript Score',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        review.verdict,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${review.totalScore}/${review.maxScore}',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: review.percent,
                minHeight: 10,
                backgroundColor: const Color(0xFFECECEC),
                color: color,
              ),
            ),
            if (review.summary.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(review.summary, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutCard(LayoutReport layout) {
    final ratio = layout.total == 0 ? 0.0 : layout.passCount / layout.total;
    final color = _scoreColor(ratio);
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Layout Compliance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Section 10.3 - Standard Format (.docx)',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${layout.passCount}/${layout.total}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: const Color(0xFFECECEC),
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            for (final rule in layout.rules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      rule.pass
                          ? Icons.check_circle
                          : Icons.cancel_outlined,
                      size: 18,
                      color: rule.pass ? Colors.green : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: AppColors.textDark),
                          children: [
                            TextSpan(
                              text: '${rule.name}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: rule.pass
                                  ? rule.actual
                                  : 'found ${rule.actual}, needs ${rule.expected}',
                              style: TextStyle(
                                color: rule.pass
                                    ? AppColors.textGrey
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutNote() {
    return Card(
      color: const Color(0xFFF3F1EE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Upload a .docx to also check the layout (margins, line spacing, '
                'font, and font size against Section 10.3). Layout cannot be '
                'measured reliably from PDF or TXT files.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(RubricResult section) {
    final ratio = section.max == 0 ? 0.0 : section.score / section.max;
    final color = _scoreColor(ratio);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        // Remove the default divider lines on the ExpansionTile for a cleaner
        // card look.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              '${section.score}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            section.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${section.score} of ${section.max} points'),
          children: [
            if (section.comment.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  section.comment,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            if (section.issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Issues to fix',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              for (final issue in section.issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(issue)),
                    ],
                  ),
                ),
            ] else ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('No major issues flagged.'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickPaper() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      // We need the bytes in memory to read the document text.
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _selectedFile = result.files.single;
      _review = null;
      _layout = null;
      _layoutSkipped = false;
      _error = null;
    });
  }

  Future<void> _runCheck() async {
    final file = _selectedFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a paper first.')),
      );
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
      _review = null;
      _layout = null;
      _layoutSkipped = false;
    });

    try {
      // Layout is a deterministic, .docx-only check (Section 10.3). Run it
      // first and keep the result even if the AI content check later fails.
      final bytes = file.bytes;
      final isDocx = (file.extension ?? '').toLowerCase() == 'docx';
      if (isDocx && bytes != null) {
        try {
          final layout = _layoutChecker.check(bytes);
          if (!mounted) return;
          setState(() => _layout = layout);
        } catch (_) {
          if (mounted) setState(() => _layoutSkipped = true);
        }
      } else {
        if (mounted) setState(() => _layoutSkipped = true);
      }

      final text = await _extractor.extract(file);
      final review = await _service.checkPaper(paperText: text);
      if (!mounted) return;
      setState(() => _review = review);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is DocumentExtractionException) return error.message;
    if (error is StateError) return error.message;
    return 'Something went wrong while checking the paper. Please try again.';
  }

  Color _scoreColor(double ratio) {
    if (ratio >= 0.75) return Colors.green.shade700;
    if (ratio >= 0.5) return Colors.orange.shade800;
    return AppColors.primary;
  }

  String _fileSizeText(int bytes) {
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB selected';
    return '${(kb / 1024).toStringAsFixed(1)} MB selected';
  }
}
