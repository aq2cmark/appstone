import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'defense_ai_service.dart';
import 'docx_layout_checker.dart';
import 'paper_checker_service.dart';

/// Turns a finished defense session or manuscript check into a PDF the student
/// can save, print, or hand to their adviser.
///
/// The `pdf` and `printing` packages were already in the project - they build
/// the admin credential roster - so this adds no dependency. Everything printed
/// here is data the screen is already displaying; nothing is recomputed and
/// nothing is stored.
class ReportPrinter {
  const ReportPrinter._();

  static const PdfColor _brand = PdfColor.fromInt(0xFF8B1A1A);
  static const PdfColor _muted = PdfColors.grey700;
  static const PdfColor _line = PdfColors.grey300;

  // ---------------------------------------------------------------------------
  // Defense practice result
  // ---------------------------------------------------------------------------

  static Future<void> printDefenseResult({
    required String mode,
    required DefenseScore score,
    required int questionsAnswered,
    required String rank,
    String? projectTitle,
    String? studentName,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => <pw.Widget>[
          _header(
            'Defense Practice Result',
            subtitle: mode,
            studentName: studentName,
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      '${score.overall}',
                      style: pw.TextStyle(
                        fontSize: 44,
                        fontWeight: pw.FontWeight.bold,
                        color: _brand,
                      ),
                    ),
                    pw.Text(
                      'out of 100',
                      style: const pw.TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        rank,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '$questionsAnswered question'
                        '${questionsAnswered == 1 ? '' : 's'} answered',
                        style: const pw.TextStyle(fontSize: 10, color: _muted),
                      ),
                      if (projectTitle != null && projectTitle.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Project: $projectTitle',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: _muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          _sectionTitle('Evaluation metrics'),
          pw.SizedBox(height: 8),
          _bar('Clarity', score.clarity),
          _bar('Technical accuracy', score.technical),
          _bar('Completeness', score.completeness),
          _bar('Presentation', score.presentation),
          if (score.insights.trim().isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 18),
            _sectionTitle('Panel insights'),
            pw.SizedBox(height: 6),
            pw.Text(
              score.insights.trim(),
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
          ],
          pw.SizedBox(height: 26),
          _disclaimer(
            'This is AI-generated practice feedback from the Appstone defense '
            'simulator. It is not an official evaluation and does not reflect '
            'the judgement of your adviser or capstone panel.',
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'Appstone - $mode result',
    );
  }

  // ---------------------------------------------------------------------------
  // Paper check
  // ---------------------------------------------------------------------------

  static Future<void> printPaperReview({
    required PaperReview review,
    required String fileName,
    LayoutReport? layout,
    String? studentName,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => <pw.Widget>[
          _header(
            'Manuscript Check Report',
            subtitle: fileName,
            studentName: studentName,
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      '${review.totalScore}/${review.maxScore}',
                      style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: _brand,
                      ),
                    ),
                    pw.Text(
                      'rubric points',
                      style: const pw.TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        review.verdict,
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (layout != null) ...<pw.Widget>[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Formatting: ${layout.passCount} of ${layout.total} '
                          'rules met',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: _muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (review.summary.trim().isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 18),
            _sectionTitle('Summary'),
            pw.SizedBox(height: 6),
            pw.Text(
              review.summary.trim(),
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
          ],
          pw.SizedBox(height: 20),
          _sectionTitle('Rubric breakdown'),
          pw.SizedBox(height: 8),
          for (final section in review.sections) ...<pw.Widget>[
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _line),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Row(
                    children: <pw.Widget>[
                      pw.Expanded(
                        child: pw.Text(
                          section.name,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Text(
                        '${section.score}/${section.max}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: _brand,
                        ),
                      ),
                    ],
                  ),
                  if (section.comment.trim().isNotEmpty) ...<pw.Widget>[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      section.comment.trim(),
                      style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.6),
                    ),
                  ],
                  if (section.issues.isNotEmpty) ...<pw.Widget>[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Issues to fix',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _muted,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    for (final issue in section.issues)
                      pw.Bullet(
                        text: issue,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ],
              ),
            ),
          ],
          if (layout != null) ...<pw.Widget>[
            pw.SizedBox(height: 6),
            _sectionTitle('Formatting compliance'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: _line),
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  children: <pw.Widget>[
                    _cell('Rule', bold: true),
                    _cell('Found', bold: true),
                    _cell('Result', bold: true),
                  ],
                ),
                for (final rule in layout.rules)
                  pw.TableRow(
                    children: <pw.Widget>[
                      _cell(rule.name),
                      _cell(rule.actual),
                      _cell(rule.pass ? 'Pass' : 'Check'),
                    ],
                  ),
              ],
            ),
          ],
          pw.SizedBox(height: 26),
          _disclaimer(
            'This is an AI-assisted pre-check against the CCS Capstone Manual '
            'rubric. It is a study aid, not the official grade - your adviser '
            'and panel remain the authority on your manuscript.',
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'Appstone - paper check',
    );
  }

  // ---------------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------------

  static pw.Widget _header(
    String title, {
    String? subtitle,
    String? studentName,
  }) {
    final generatedAt = DateTime.now().toString().split('.').first;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    pw.Text(
                      subtitle,
                      style: const pw.TextStyle(fontSize: 11, color: _muted),
                    ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                pw.Text(
                  'Appstone',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _brand,
                  ),
                ),
                pw.Text(
                  'Dominican College of Tarlac, Inc.',
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _line, height: 1),
        pw.SizedBox(height: 6),
        pw.Text(
          <String>[
            if (studentName != null && studentName.isNotEmpty) studentName,
            'Generated $generatedAt',
          ].join('  -  '),
          style: const pw.TextStyle(fontSize: 9, color: _muted),
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _muted,
          letterSpacing: 0.8,
        ),
      );

  static pw.Widget _bar(String label, int value) {
    // The pdf package has no progress widget and no FractionallySizedBox, so
    // the fill is two flexed cells that add up to 100. The zero-width side is
    // dropped entirely rather than given flex: 0, which the layout rejects.
    final filled = value.clamp(0, 100);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
              pw.Text(
                '$value%',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: <pw.Widget>[
              if (filled > 0)
                pw.Expanded(
                  flex: filled,
                  child: pw.Container(height: 6, color: _brand),
                ),
              if (filled < 100)
                pw.Expanded(
                  flex: 100 - filled,
                  child: pw.Container(height: 6, color: PdfColors.grey200),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  static pw.Widget _disclaimer(String text) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          text,
          style: const pw.TextStyle(
            fontSize: 8,
            color: _muted,
            lineSpacing: 1.6,
          ),
        ),
      );
}
