import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart';

import 'admin_repository.dart';

// Thrown for problems with the whole file (wrong type, missing header row,
// missing required columns). Per-row problems are reported in the preview
// instead, so one bad row never blocks the rest.
class ImportException implements Exception {
  ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

// One student row as read from the spreadsheet, before validation.
class ParsedStudentRow {
  ParsedStudentRow({
    required this.rowNumber,
    required this.name,
    required this.email,
    required this.group,
  });

  // 1-based position among the data rows (header excluded) - shown to the
  // admin so they can find a bad row in their file.
  final int rowNumber;
  final String name;
  final String email;
  final String group;
}

enum ImportRowStatus { ok, error }

// A parsed row plus the verdict of validating it against the current groups.
class ImportRow {
  ImportRow({required this.data, required this.status, this.message = ''});

  final ParsedStudentRow data;
  final ImportRowStatus status;
  final String message;

  bool get isOk => status == ImportRowStatus.ok;
}

// The reviewed batch: every row with its status, and which groups would be
// created on import.
class ImportPreview {
  ImportPreview({required this.rows, required this.groupsToCreate});

  final List<ImportRow> rows;
  final List<String> groupsToCreate;

  List<ImportRow> get validRows => rows.where((r) => r.isOk).toList();
  int get validCount => validRows.length;
  int get errorCount => rows.length - validCount;
}

// Reads a student roster from an .xlsx or .csv file and validates it against
// the existing groups. An .xlsx is just a ZIP of XML, so it's read with the
// archive + xml packages the app already uses (no conflicting dependency).
class StudentImportService {
  static const int maxGroupSize = 5;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // Accepted header spellings for each column (compared lower-cased/trimmed).
  static const _nameHeaders = ['name', 'student name', 'full name', 'student'];
  static const _emailHeaders = ['email', 'e-mail', 'email address'];
  static const _groupHeaders = ['group', 'group name', 'team'];

  List<ParsedStudentRow> parse({
    required Uint8List bytes,
    required String extension,
  }) {
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'xlsx':
        return _rowsToStudents(_readXlsx(bytes));
      case 'csv':
        return _rowsToStudents(_readCsv(bytes));
      default:
        throw ImportException(
          'Unsupported file ".$ext". Upload an .xlsx or .csv file.',
        );
    }
  }

  // ---- Validation -----------------------------------------------------------

  ImportPreview validate(
    List<ParsedStudentRow> parsed,
    List<CapstoneGroup> existingGroups,
  ) {
    // Existing state to check against.
    final existingEmails = <String>{
      for (final group in existingGroups)
        for (final student in group.students) student.email.toLowerCase(),
    };
    // group key (lower-cased name) -> current member count.
    final groupCounts = <String, int>{
      for (final group in existingGroups)
        group.name.trim().toLowerCase(): group.students.length,
    };
    final existingGroupNames = groupCounts.keys.toSet();

    final seenEmails = <String>{};
    final groupsToCreate = <String>{};
    final rows = <ImportRow>[];

    for (final row in parsed) {
      final email = row.email.toLowerCase();
      final groupKey = row.group.trim().toLowerCase();
      String? error;

      if (row.name.isEmpty) {
        error = 'Missing name';
      } else if (row.email.isEmpty) {
        error = 'Missing email';
      } else if (!_emailPattern.hasMatch(row.email)) {
        error = 'Invalid email';
      } else if (row.group.isEmpty) {
        error = 'Missing group';
      } else if (seenEmails.contains(email)) {
        error = 'Duplicate email in this file';
      } else if (existingEmails.contains(email)) {
        error = 'Email already registered';
      } else if ((groupCounts[groupKey] ?? 0) >= maxGroupSize) {
        error = 'Group "${row.group}" would exceed $maxGroupSize members';
      }

      if (error != null) {
        rows.add(ImportRow(
          data: row,
          status: ImportRowStatus.error,
          message: error,
        ));
        continue;
      }

      // Accepted: reserve the email and a seat in the group.
      seenEmails.add(email);
      groupCounts[groupKey] = (groupCounts[groupKey] ?? 0) + 1;
      if (!existingGroupNames.contains(groupKey)) {
        groupsToCreate.add(row.group.trim());
      }
      rows.add(ImportRow(data: row, status: ImportRowStatus.ok));
    }

    return ImportPreview(rows: rows, groupsToCreate: groupsToCreate.toList());
  }

  // ---- Committing the import ------------------------------------------------

  // Registers each valid row, creating any missing groups first. Groups are
  // matched by name (case-insensitive); a name not seen yet is created once and
  // reused. Each student goes through the normal registration path, so they get
  // the same STU id + temporary password as a hand-added student.
  Future<StudentImportResult> commit({
    required AdminRepository repo,
    required List<ParsedStudentRow> validRows,
  }) async {
    final groups = await repo.getGroups();
    final nameToId = <String, String>{
      for (final group in groups) group.name.trim().toLowerCase(): group.id,
    };

    final created = <ImportedStudent>[];
    final failures = <ImportFailure>[];

    for (final row in validRows) {
      final key = row.group.trim().toLowerCase();
      try {
        var groupId = nameToId[key];
        groupId ??= await repo.createGroupReturningId(row.group.trim());
        nameToId[key] = groupId;

        final student = await repo.registerStudent(
          StudentDraft(name: row.name, email: row.email, groupId: groupId),
        );
        created.add(ImportedStudent(
          name: student.name,
          email: student.email,
          studentId: student.studentId,
          tempPassword: student.tempPassword,
          group: row.group.trim(),
        ));
      } catch (error) {
        failures.add(ImportFailure(row: row, message: error.toString()));
      }
    }

    return StudentImportResult(created: created, failures: failures);
  }

  // ---- Row -> student mapping (shared by xlsx and csv) ----------------------

  List<ParsedStudentRow> _rowsToStudents(List<List<String>> rows) {
    // First non-empty row is the header.
    final headerIndex = rows.indexWhere((r) => r.any((c) => c.trim().isNotEmpty));
    if (headerIndex == -1) {
      throw ImportException('The file is empty.');
    }
    final header = rows[headerIndex];
    final nameIdx = _findColumn(header, _nameHeaders);
    final emailIdx = _findColumn(header, _emailHeaders);
    final groupIdx = _findColumn(header, _groupHeaders);

    final missing = <String>[
      if (nameIdx == -1) 'Name',
      if (emailIdx == -1) 'Email',
      if (groupIdx == -1) 'Group',
    ];
    if (missing.isNotEmpty) {
      throw ImportException(
        'Missing required column(s): ${missing.join(', ')}. The first row must '
        'have headers Name, Email, and Group.',
      );
    }

    final students = <ParsedStudentRow>[];
    var dataNumber = 0;
    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      final name = _at(row, nameIdx);
      final email = _at(row, emailIdx);
      final group = _at(row, groupIdx);
      // Skip completely blank rows silently.
      if (name.isEmpty && email.isEmpty && group.isEmpty) continue;
      dataNumber++;
      students.add(ParsedStudentRow(
        rowNumber: dataNumber,
        name: name,
        email: email,
        group: group,
      ));
    }
    return students;
  }

  int _findColumn(List<String> header, List<String> options) {
    for (var i = 0; i < header.length; i++) {
      if (options.contains(header[i].trim().toLowerCase())) return i;
    }
    return -1;
  }

  String _at(List<String> row, int index) =>
      index >= 0 && index < row.length ? row[index].trim() : '';

  // ---- CSV reading ----------------------------------------------------------

  List<List<String>> _readCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final table = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
    return [
      for (final row in table) [for (final cell in row) cell.toString()],
    ];
  }

  // ---- XLSX reading (ZIP of XML) --------------------------------------------

  List<List<String>> _readXlsx(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw ImportException('Could not read the .xlsx file. Re-save it and try again.');
    }

    // Shared strings: cell text is stored here and referenced by index.
    final sharedStrings = <String>[];
    final ssEntry = archive.find('xl/sharedStrings.xml');
    if (ssEntry != null) {
      final doc = XmlDocument.parse(
        utf8.decode(ssEntry.content, allowMalformed: true),
      );
      for (final si in doc.findAllElements('si')) {
        final buffer = StringBuffer();
        for (final t in si.findAllElements('t')) {
          buffer.write(t.innerText);
        }
        sharedStrings.add(buffer.toString());
      }
    }

    final sheetEntry = _firstWorksheet(archive);
    if (sheetEntry == null) {
      throw ImportException('The .xlsx has no worksheet.');
    }
    final sheet = XmlDocument.parse(
      utf8.decode(sheetEntry.content, allowMalformed: true),
    );

    final rows = <List<String>>[];
    for (final rowEl in sheet.findAllElements('row')) {
      final cells = <int, String>{};
      var fallbackCol = 0;
      for (final c in rowEl.findAllElements('c')) {
        final ref = c.getAttribute('r') ?? '';
        final col = _columnIndex(ref, fallbackCol);
        fallbackCol = col + 1;

        final type = c.getAttribute('t');
        String value;
        if (type == 's') {
          final idx = int.tryParse(c.getElement('v')?.innerText ?? '');
          value = (idx != null && idx >= 0 && idx < sharedStrings.length)
              ? sharedStrings[idx]
              : '';
        } else if (type == 'inlineStr') {
          value = c.getElement('is')?.innerText ?? '';
        } else {
          value = c.getElement('v')?.innerText ?? '';
        }
        cells[col] = value;
      }
      if (cells.isEmpty) {
        rows.add(const []);
        continue;
      }
      final maxCol = cells.keys.reduce(max);
      rows.add([for (var i = 0; i <= maxCol; i++) cells[i] ?? '']);
    }
    return rows;
  }

  ArchiveFile? _firstWorksheet(Archive archive) {
    // sheet1.xml is the usual first sheet; fall back to any worksheet file.
    final direct = archive.find('xl/worksheets/sheet1.xml');
    if (direct != null) return direct;
    for (final file in archive.files) {
      if (file.name.startsWith('xl/worksheets/') &&
          file.name.endsWith('.xml')) {
        return file;
      }
    }
    return null;
  }

  // Converts an A1-style reference to a 0-based column index. Falls back to the
  // next sequential column when a cell has no reference attribute.
  int _columnIndex(String ref, int fallback) {
    var col = 0;
    var sawLetter = false;
    for (var i = 0; i < ref.length; i++) {
      final code = ref.codeUnitAt(i);
      if (code >= 65 && code <= 90) {
        col = col * 26 + (code - 64);
        sawLetter = true;
      } else if (code >= 97 && code <= 122) {
        col = col * 26 + (code - 96);
        sawLetter = true;
      } else {
        break;
      }
    }
    return sawLetter ? col - 1 : fallback;
  }
}

// A student successfully created during an import, with the credentials the
// admin needs to hand out.
class ImportedStudent {
  ImportedStudent({
    required this.name,
    required this.email,
    required this.studentId,
    required this.tempPassword,
    required this.group,
  });

  final String name;
  final String email;
  final String studentId;
  final String tempPassword;
  final String group;
}

// A row that passed preview but failed while being written (e.g. the group
// filled up between preview and import).
class ImportFailure {
  ImportFailure({required this.row, required this.message});

  final ParsedStudentRow row;
  final String message;
}

class StudentImportResult {
  StudentImportResult({required this.created, required this.failures});

  final List<ImportedStudent> created;
  final List<ImportFailure> failures;
}
