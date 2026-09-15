import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

// Raised when a picked file can't be turned into readable text. The message is
// written to be shown directly to a student in a snackbar/dialog.
class DocumentExtractionException implements Exception {
  DocumentExtractionException(this.message);

  final String message;

  @override
  String toString() => message;
}

// Pulls plain text out of a picked capstone document so the AI can read it.
// Supports the formats students actually submit: PDF, .docx, and .txt.
// Works on every platform (including Flutter web) because every reader here is
// pure Dart - no native/OCR dependency.
class DocumentTextExtractor {
  // Upper bound on how much text we forward to the model. A full manuscript
  // still fits comfortably; anything past this is truncated with a marker so a
  // huge appendix dump can't blow the context window.
  static const int maxChars = 48000;

  Future<String> extract(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw DocumentExtractionException(
        'Could not read the file contents. Please select the file again.',
      );
    }

    final ext = (file.extension ?? '').toLowerCase();
    String text;
    switch (ext) {
      case 'pdf':
        text = _extractPdf(bytes);
        break;
      case 'docx':
        text = _extractDocx(bytes);
        break;
      case 'txt':
        text = utf8.decode(bytes, allowMalformed: true);
        break;
      case 'doc':
        throw DocumentExtractionException(
          'The old .doc format is not supported. Please save your paper as PDF '
          'or .docx and try again.',
        );
      default:
        throw DocumentExtractionException(
          'Unsupported file type ".$ext". Upload a PDF, .docx, or .txt file.',
        );
    }

    text = _normalize(text);
    if (text.trim().isEmpty) {
      throw DocumentExtractionException(
        'No readable text was found. If this is a scanned PDF (images only), '
        'export a text-based PDF or upload the .docx instead.',
      );
    }
    if (text.length > maxChars) {
      text = '${text.substring(0, maxChars)}\n\n[...truncated for length...]';
    }
    return text;
  }

  String _extractPdf(Uint8List bytes) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      return PdfTextExtractor(document).extractText();
    } catch (error) {
      throw DocumentExtractionException(
        'Could not read the PDF. Make sure it is not password-protected.',
      );
    } finally {
      document?.dispose();
    }
  }

  // A .docx is a ZIP whose main body lives in word/document.xml. Word wraps
  // each paragraph in <w:p> and each text run in <w:t>, so we join the runs
  // per paragraph and separate paragraphs with newlines to keep structure.
  String _extractDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.find('word/document.xml');
      if (entry == null) {
        throw DocumentExtractionException(
          'This .docx is missing its document body. Re-save it from Word and '
          'try again.',
        );
      }
      final xmlString = utf8.decode(entry.content, allowMalformed: true);
      final document = XmlDocument.parse(xmlString);
      final buffer = StringBuffer();
      for (final paragraph in document.findAllElements('w:p')) {
        final runs = paragraph.findAllElements('w:t').map((t) => t.innerText);
        buffer.writeln(runs.join());
      }
      return buffer.toString();
    } on DocumentExtractionException {
      rethrow;
    } catch (error) {
      throw DocumentExtractionException(
        'Could not read the .docx file. Re-save it from Word and try again.',
      );
    }
  }

  // Normalize line endings and collapse long stretches of blank lines so the
  // text sent to the AI is compact and consistent.
  String _normalize(String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final cleaned = <String>[];
    var blankRun = 0;
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        blankRun++;
        if (blankRun <= 1) cleaned.add('');
      } else {
        blankRun = 0;
        cleaned.add(line);
      }
    }
    return cleaned.join('\n').trim();
  }
}
