import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

// One measured formatting rule from Section 10.3 (Documentation Standard
// Format): what the manual requires, what the .docx actually uses, and whether
// they match.
class LayoutRule {
  const LayoutRule({
    required this.name,
    required this.expected,
    required this.actual,
    required this.pass,
  });

  final String name;
  final String expected;
  final String actual;
  final bool pass;
}

class LayoutReport {
  const LayoutReport(this.rules);

  final List<LayoutRule> rules;

  int get passCount => rules.where((r) => r.pass).length;
  int get total => rules.length;
}

// Checks a Word (.docx) manuscript against the DCT CCS Capstone Manual's
// Section 10.3 layout rules (page size, margins, line spacing, font, font
// size). This is a deterministic reader of the file's own XML - not an AI
// guess - so the values it reports are exactly what Word has stored.
//
// Word measures lengths in twips (1 inch = 1440 twips) and font sizes in
// half-points (22 = 11pt). All of that lives in word/document.xml (section
// properties + runs) and word/styles.xml (document defaults).
class DocxLayoutChecker {
  // Margins/page can be a hair off after a round-trip through an editor, so
  // allow ~1/32 inch of slack before calling a value wrong.
  static const double _inchTolerance = 0.03;

  LayoutReport check(Uint8List docxBytes) {
    final archive = ZipDecoder().decodeBytes(docxBytes);

    final documentEntry = archive.find('word/document.xml');
    if (documentEntry == null) {
      throw Exception('Not a valid .docx (missing word/document.xml).');
    }
    final document = XmlDocument.parse(
      utf8.decode(documentEntry.content, allowMalformed: true),
    );

    XmlDocument? styles;
    final stylesEntry = archive.find('word/styles.xml');
    if (stylesEntry != null) {
      styles = XmlDocument.parse(
        utf8.decode(stylesEntry.content, allowMalformed: true),
      );
    }

    final rules = <LayoutRule>[];
    rules.addAll(_pageAndMargins(document));
    rules.add(_lineSpacing(document, styles));
    final fontRules = _fontRules(document, styles);
    rules.addAll(fontRules);
    return LayoutReport(rules);
  }

  // ---- Page size + margins (from the body-level <w:sectPr>) -----------------

  List<LayoutRule> _pageAndMargins(XmlDocument document) {
    // The last section-properties block defines the main document section.
    final sectPrs = _all(document, 'sectPr').toList();
    final sectPr = sectPrs.isEmpty ? null : sectPrs.last;

    final pgSz = _child(sectPr, 'pgSz');
    final pgMar = _child(sectPr, 'pgMar');

    final rules = <LayoutRule>[];

    // Paper size 8.5 x 11, portrait.
    final w = _twipsToInch(_attr(pgSz, 'w'));
    final h = _twipsToInch(_attr(pgSz, 'h'));
    if (w != null && h != null) {
      final portrait = h >= w;
      final ok = _near(w, 8.5) && _near(h, 11) && portrait;
      rules.add(LayoutRule(
        name: 'Paper size',
        expected: '8.5 x 11 in, portrait',
        actual:
            '${w.toStringAsFixed(2)} x ${h.toStringAsFixed(2)} in${portrait ? '' : ', landscape'}',
        pass: ok,
      ));
    } else {
      rules.add(const LayoutRule(
        name: 'Paper size',
        expected: '8.5 x 11 in, portrait',
        actual: 'not detected',
        pass: false,
      ));
    }

    rules.add(_marginRule('Top margin', _attr(pgMar, 'top'), 1.0));
    rules.add(_marginRule('Bottom margin', _attr(pgMar, 'bottom'), 1.0));
    rules.add(_marginRule('Left margin', _attr(pgMar, 'left'), 1.5));
    rules.add(_marginRule('Right margin', _attr(pgMar, 'right'), 1.0));
    rules.add(_marginRule('Header distance', _attr(pgMar, 'header'), 0.5));
    rules.add(_marginRule('Footer distance', _attr(pgMar, 'footer'), 0.5));
    rules.add(_marginRule('Gutter', _attr(pgMar, 'gutter'), 0.0));

    return rules;
  }

  LayoutRule _marginRule(String name, String? twips, double expectedInch) {
    final inch = _twipsToInch(twips);
    return LayoutRule(
      name: name,
      expected: '${_inch(expectedInch)} in',
      actual: inch == null ? 'not detected' : '${_inch(inch)} in',
      pass: inch != null && _near(inch, expectedInch),
    );
  }

  // ---- Line spacing (predominant across body paragraphs) --------------------

  LayoutRule _lineSpacing(XmlDocument document, XmlDocument? styles) {
    final defaultMultiple = _defaultLineMultiple(styles);

    // Tally the effective line multiple over paragraphs that actually have
    // text, weighting by paragraph so the body's real spacing wins.
    final counts = <String, int>{};
    for (final p in _all(document, 'p')) {
      if (_paragraphText(p).trim().isEmpty) continue;
      final spacing = _child(_child(p, 'pPr'), 'spacing');
      final multiple = _lineMultiple(spacing) ?? defaultMultiple;
      if (multiple == null) continue;
      final key = multiple.toStringAsFixed(2);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final predominant = _mostCommon(counts);
    final value = predominant == null ? null : double.tryParse(predominant);
    return LayoutRule(
      name: 'Line spacing',
      expected: '1.5',
      actual: value == null ? 'not detected' : _spacingLabel(value),
      pass: value != null && (value - 1.5).abs() < 0.05,
    );
  }

  // ---- Font family + body size (predominant across text runs) ---------------

  List<LayoutRule> _fontRules(XmlDocument document, XmlDocument? styles) {
    final defaultFont = _defaultFont(styles);
    final defaultSize = _defaultSize(styles);

    final fontCounts = <String, int>{};
    final sizeCounts = <String, int>{};

    for (final run in _all(document, 'r')) {
      final text = _runText(run);
      final len = text.length;
      if (len == 0) continue;

      final rPr = _child(run, 'rPr');
      final font = _attr(_child(rPr, 'rFonts'), 'ascii') ?? defaultFont;
      final sizeHalfPts = _attr(_child(rPr, 'sz'), 'val') ?? defaultSize;

      if (font != null && font.trim().isNotEmpty) {
        fontCounts[font] = (fontCounts[font] ?? 0) + len;
      }
      final half = int.tryParse(sizeHalfPts ?? '');
      if (half != null) {
        final pt = (half / 2).toStringAsFixed(half.isEven ? 0 : 1);
        sizeCounts[pt] = (sizeCounts[pt] ?? 0) + len;
      }
    }

    final font = _mostCommon(fontCounts);
    final size = _mostCommon(sizeCounts);

    return [
      LayoutRule(
        name: 'Font',
        expected: 'Times New Roman',
        actual: font ?? 'not detected',
        pass: font != null &&
            font.toLowerCase().contains('times new roman'),
      ),
      LayoutRule(
        name: 'Body font size',
        expected: '11 pt',
        actual: size == null ? 'not detected' : '$size pt',
        pass: size != null && (double.tryParse(size) ?? 0) == 11,
      ),
    ];
  }

  // ---- Document-default lookups from styles.xml -----------------------------

  String? _defaultFont(XmlDocument? styles) {
    if (styles == null) return null;
    final fromDefaults = _attr(
      _child(_docDefaultRPr(styles), 'rFonts'),
      'ascii',
    );
    if (fromDefaults != null) return fromDefaults;
    return _attr(_child(_child(_normalStyle(styles), 'rPr'), 'rFonts'), 'ascii');
  }

  String? _defaultSize(XmlDocument? styles) {
    if (styles == null) return null;
    final fromDefaults = _attr(_child(_docDefaultRPr(styles), 'sz'), 'val');
    if (fromDefaults != null) return fromDefaults;
    return _attr(_child(_child(_normalStyle(styles), 'rPr'), 'sz'), 'val');
  }

  double? _defaultLineMultiple(XmlDocument? styles) {
    if (styles == null) return null;
    final defaults = _child(_docDefaultPPr(styles), 'spacing');
    final fromDefaults = _lineMultiple(defaults);
    if (fromDefaults != null) return fromDefaults;
    return _lineMultiple(_child(_child(_normalStyle(styles), 'pPr'), 'spacing'));
  }

  XmlElement? _docDefaultRPr(XmlDocument styles) =>
      _child(_child(_child(styles.rootElement, 'docDefaults'), 'rPrDefault'),
          'rPr');

  XmlElement? _docDefaultPPr(XmlDocument styles) =>
      _child(_child(_child(styles.rootElement, 'docDefaults'), 'pPrDefault'),
          'pPr');

  XmlElement? _normalStyle(XmlDocument styles) {
    for (final style in _all(styles, 'style')) {
      if (_attr(style, 'type') == 'paragraph' &&
          _attr(style, 'default') == '1') {
        return style;
      }
    }
    return null;
  }

  // ---- Small helpers --------------------------------------------------------

  // A <w:spacing> is 1.5-spaced when lineRule is "auto" and line = 360
  // (240 twips = one line). Exact/atLeast rules use twips and aren't a
  // multiple, so we treat them as unknown here.
  double? _lineMultiple(XmlElement? spacing) {
    if (spacing == null) return null;
    final line = int.tryParse(_attr(spacing, 'line') ?? '');
    if (line == null) return null;
    final rule = _attr(spacing, 'lineRule');
    if (rule != null && rule != 'auto') return null;
    return line / 240.0;
  }

  String _spacingLabel(double multiple) {
    if ((multiple - 1.0).abs() < 0.05) return '1.0 (single)';
    if ((multiple - 2.0).abs() < 0.05) return '2.0 (double)';
    return multiple.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _runText(XmlElement run) {
    final buffer = StringBuffer();
    for (final child in run.childElements) {
      if (child.name.local == 't') buffer.write(child.innerText);
    }
    return buffer.toString();
  }

  String _paragraphText(XmlElement paragraph) {
    final buffer = StringBuffer();
    for (final t in _all(paragraph, 't')) {
      buffer.write(t.innerText);
    }
    return buffer.toString();
  }

  String? _mostCommon(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    String? best;
    var bestCount = -1;
    counts.forEach((key, value) {
      if (value > bestCount) {
        best = key;
        bestCount = value;
      }
    });
    return best;
  }

  double? _twipsToInch(String? twips) {
    final value = int.tryParse(twips ?? '');
    if (value == null) return null;
    return value / 1440.0;
  }

  String _inch(double value) {
    // Trim trailing zeros so 1.50 shows as 1.5 and 0.00 as 0.
    final s = value.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  bool _near(double a, double b) => (a - b).abs() <= _inchTolerance;

  // Prefix-agnostic element/attribute lookups: match on local name so a file
  // that binds the WordprocessingML namespace to a non-"w" prefix still works.
  XmlElement? _child(XmlElement? parent, String local) {
    if (parent == null) return null;
    for (final e in parent.childElements) {
      if (e.name.local == local) return e;
    }
    return null;
  }

  Iterable<XmlElement> _all(XmlNode root, String local) =>
      root.descendantElements.where((e) => e.name.local == local);

  String? _attr(XmlElement? element, String local) {
    if (element == null) return null;
    for (final a in element.attributes) {
      if (a.name.local == local) return a.value;
    }
    return null;
  }
}
