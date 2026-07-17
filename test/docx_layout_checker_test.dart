import 'dart:typed_data';

import 'package:appstone/services/docx_layout_checker.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

// The layout checker reads Word's own XML rather than guessing, so a student is
// told their margins are wrong on the strength of these numbers. Word stores
// lengths in twips (1 inch = 1440) and font sizes in half-points (22 = 11pt),
// and every rule below is one of those conversions plus a comparison against
// Section 10.3 of the manual.

// A .docx holding only the parts the checker reads. Defaults describe a
// manuscript that is compliant on every rule, so each test changes one thing.
Uint8List buildDocx({
  int pageWidth = 12240, // 8.5 in
  int pageHeight = 15840, // 11 in
  int top = 1440, // 1 in
  int bottom = 1440,
  int left = 2160, // 1.5 in
  int right = 1440,
  int header = 720, // 0.5 in
  int footer = 720,
  int gutter = 0,
  int line = 360, // 360 / 240 = 1.5 spacing
  String lineRule = 'auto',
  String font = 'Times New Roman',
  int halfPoints = 22, // 11 pt
  String prefix = 'w',
  String? stylesXml,
  bool includeDocument = true,
}) {
  final p = prefix;
  final document =
      '<?xml version="1.0"?>'
      '<$p:document xmlns:$p="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<$p:body>'
      '<$p:p>'
      '<$p:pPr><$p:spacing $p:line="$line" $p:lineRule="$lineRule"/></$p:pPr>'
      '<$p:r>'
      '<$p:rPr><$p:rFonts $p:ascii="$font"/><$p:sz $p:val="$halfPoints"/></$p:rPr>'
      '<$p:t>Chapter 1. Introduction to the study.</$p:t>'
      '</$p:r>'
      '</$p:p>'
      '<$p:sectPr>'
      '<$p:pgSz $p:w="$pageWidth" $p:h="$pageHeight"/>'
      '<$p:pgMar $p:top="$top" $p:bottom="$bottom" $p:left="$left" '
      '$p:right="$right" $p:header="$header" $p:footer="$footer" $p:gutter="$gutter"/>'
      '</$p:sectPr>'
      '</$p:body>'
      '</$p:document>';

  final archive = Archive();
  if (includeDocument) {
    archive.add(ArchiveFile.string('word/document.xml', document));
  }
  if (stylesXml != null) {
    archive.add(ArchiveFile.string('word/styles.xml', stylesXml));
  }
  return ZipEncoder().encodeBytes(archive);
}

// styles.xml carrying document-wide defaults and no direct formatting.
String stylesWithDefaults({
  String font = 'Times New Roman',
  int halfPoints = 22,
  int line = 360,
}) =>
    '<?xml version="1.0"?>'
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:docDefaults>'
    '<w:rPrDefault><w:rPr>'
    '<w:rFonts w:ascii="$font"/><w:sz w:val="$halfPoints"/>'
    '</w:rPr></w:rPrDefault>'
    '<w:pPrDefault><w:pPr>'
    '<w:spacing w:line="$line" w:lineRule="auto"/>'
    '</w:pPr></w:pPrDefault>'
    '</w:docDefaults>'
    '</w:styles>';

// A document with a run carrying no rPr, so the font and size must come from
// styles.xml defaults.
String bareDocument() =>
    '<?xml version="1.0"?>'
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:body>'
    '<w:p><w:r><w:t>Body text with no direct formatting.</w:t></w:r></w:p>'
    '<w:sectPr>'
    '<w:pgSz w:w="12240" w:h="15840"/>'
    '<w:pgMar w:top="1440" w:bottom="1440" w:left="2160" w:right="1440" '
    'w:header="720" w:footer="720" w:gutter="0"/>'
    '</w:sectPr>'
    '</w:body>'
    '</w:document>';

void main() {
  final checker = DocxLayoutChecker();

  LayoutRule ruleNamed(LayoutReport report, String name) =>
      report.rules.firstWhere((r) => r.name == name);

  test('a fully compliant manuscript passes every rule', () {
    final report = checker.check(buildDocx());

    expect(report.total, 11);
    expect(report.passCount, 11);
    expect(report.rules.every((r) => r.pass), isTrue);
  });

  test('page size, margins, spacing and font are each reported', () {
    // The report is the whole checklist the student sees; a silently dropped
    // rule reads as a rule that passed.
    final names = checker.check(buildDocx()).rules.map((r) => r.name).toList();

    expect(names, containsAll(<String>[
      'Paper size',
      'Top margin',
      'Bottom margin',
      'Left margin',
      'Right margin',
      'Header distance',
      'Footer distance',
      'Gutter',
      'Line spacing',
      'Font',
      'Body font size',
    ]));
  });

  test('twips are converted to the inches the manual is written in', () {
    final report = checker.check(buildDocx());

    expect(ruleNamed(report, 'Paper size').actual, '8.50 x 11.00 in');
    expect(ruleNamed(report, 'Left margin').actual, '1.5 in');
    expect(ruleNamed(report, 'Left margin').expected, '1.5 in');
    expect(ruleNamed(report, 'Top margin').actual, '1 in');
    expect(ruleNamed(report, 'Header distance').actual, '0.5 in');
    expect(ruleNamed(report, 'Gutter').actual, '0 in');
  });

  test('the 1.5 inch binding margin is the one checked on the left', () {
    // A 1 inch left margin is the most common real mistake: it looks right
    // everywhere else, and only the left is meant to be 1.5.
    final report = checker.check(buildDocx(left: 1440));
    final rule = ruleNamed(report, 'Left margin');

    expect(rule.pass, isFalse);
    expect(rule.actual, '1 in');
    expect(rule.expected, '1.5 in');
    // And it is the only failure - the rest of the page is untouched.
    expect(report.passCount, 10);
  });

  test('a margin a hair off after a round trip is not called wrong', () {
    // 2158 twips is 1.4986 in - Word does this to itself on save, and flagging
    // it would be a false alarm.
    expect(ruleNamed(checker.check(buildDocx(left: 2158)), 'Left margin').pass, isTrue);
    // 2100 twips is 1.458 in, past the tolerance, and is a real miss.
    expect(ruleNamed(checker.check(buildDocx(left: 2100)), 'Left margin').pass, isFalse);
  });

  test('landscape is caught even at the right dimensions', () {
    final rule = ruleNamed(
      checker.check(buildDocx(pageWidth: 15840, pageHeight: 12240)),
      'Paper size',
    );

    expect(rule.pass, isFalse);
    expect(rule.actual, contains('landscape'));
  });

  test('A4 is caught as the wrong paper size', () {
    // A4 (8.27 x 11.69 in) is the default on many machines and is close enough
    // to 8.5 x 11 to pass unnoticed on screen.
    final rule = ruleNamed(
      checker.check(buildDocx(pageWidth: 11906, pageHeight: 16838)),
      'Paper size',
    );

    expect(rule.pass, isFalse);
  });

  test('single and double spacing are both reported in words', () {
    expect(ruleNamed(checker.check(buildDocx(line: 240)), 'Line spacing').actual,
        '1.0 (single)');
    expect(ruleNamed(checker.check(buildDocx(line: 480)), 'Line spacing').actual,
        '2.0 (double)');
    expect(ruleNamed(checker.check(buildDocx(line: 240)), 'Line spacing').pass, isFalse);
    expect(ruleNamed(checker.check(buildDocx(line: 360)), 'Line spacing').pass, isTrue);
  });

  test('exact-point spacing is reported as undetected, not guessed at', () {
    // An "exactly 18pt" rule measures in twips, not multiples of a line, so it
    // cannot honestly be compared with "1.5".
    final rule = ruleNamed(
      checker.check(buildDocx(line: 360, lineRule: 'exact')),
      'Line spacing',
    );

    expect(rule.actual, 'not detected');
    expect(rule.pass, isFalse);
  });

  test('half-points are converted to the point size students recognise', () {
    expect(ruleNamed(checker.check(buildDocx()), 'Body font size').actual, '11 pt');
    expect(ruleNamed(checker.check(buildDocx(halfPoints: 24)), 'Body font size').actual,
        '12 pt');
    expect(ruleNamed(checker.check(buildDocx(halfPoints: 24)), 'Body font size').pass,
        isFalse);
    // 11.5pt is stored as 23 half-points and must not round to a passing 11.
    expect(ruleNamed(checker.check(buildDocx(halfPoints: 23)), 'Body font size').actual,
        '11.5 pt');
    expect(ruleNamed(checker.check(buildDocx(halfPoints: 23)), 'Body font size').pass,
        isFalse);
  });

  test('the wrong font is named in the report, not just failed', () {
    final rule = ruleNamed(checker.check(buildDocx(font: 'Arial')), 'Font');

    expect(rule.pass, isFalse);
    expect(rule.actual, 'Arial');
    expect(rule.expected, 'Times New Roman');
  });

  test('the font match ignores case and trailing detail', () {
    expect(ruleNamed(checker.check(buildDocx(font: 'times new roman')), 'Font').pass,
        isTrue);
    expect(ruleNamed(checker.check(buildDocx(font: 'Times New Roman PS MT')), 'Font').pass,
        isTrue);
  });

  test('formatting inherited from styles.xml is read, not missed', () {
    // A manuscript written entirely with Word's default style carries no rPr on
    // its runs at all; reading only the runs would report "not detected".
    final archive = Archive()
      ..add(ArchiveFile.string('word/document.xml', bareDocument()))
      ..add(ArchiveFile.string('word/styles.xml', stylesWithDefaults()));
    final report = checker.check(ZipEncoder().encodeBytes(archive));

    expect(ruleNamed(report, 'Font').actual, 'Times New Roman');
    expect(ruleNamed(report, 'Body font size').actual, '11 pt');
    expect(ruleNamed(report, 'Line spacing').pass, isTrue);
    expect(report.passCount, 11);
  });

  test('direct formatting on the run beats the styles.xml default', () {
    final report = checker.check(
      buildDocx(font: 'Arial', stylesXml: stylesWithDefaults()),
    );

    expect(ruleNamed(report, 'Font').actual, 'Arial');
    expect(ruleNamed(report, 'Font').pass, isFalse);
  });

  test('a file with no styles.xml is read from the document alone', () {
    // Not every .docx ships one, and throwing would reject a valid manuscript.
    final report = checker.check(buildDocx());

    expect(report.total, 11);
    expect(ruleNamed(report, 'Font').actual, 'Times New Roman');
  });

  test('a document binding the namespace to another prefix still reads', () {
    // The prefix is the author's choice, not part of the format.
    final report = checker.check(buildDocx(prefix: 'x'));

    expect(report.passCount, 11);
  });

  test('a file that is not a .docx is rejected with a readable reason', () {
    expect(
      () => checker.check(buildDocx(includeDocument: false)),
      throwsA(predicate((e) => e.toString().contains('word/document.xml'))),
    );
  });
}
