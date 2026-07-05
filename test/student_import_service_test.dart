import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:appstone/services/admin_repository.dart';
import 'package:appstone/services/student_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Builds a minimal .xlsx containing only the two parts the reader needs:
// the first worksheet and the shared-strings table.
Uint8List buildXlsx(List<List<String>> rows) {
  final strings = <String>[];
  final indexOf = <String, int>{};
  int intern(String s) => indexOf.putIfAbsent(s, () {
        strings.add(s);
        return strings.length - 1;
      });

  final sheet = StringBuffer('<?xml version="1.0"?><worksheet><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final col = String.fromCharCode(65 + c);
      sheet.write('<c r="$col${r + 1}" t="s"><v>${intern(rows[r][c])}</v></c>');
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');

  final ss = StringBuffer('<?xml version="1.0"?><sst>');
  for (final s in strings) {
    final esc = s.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
    ss.write('<si><t>$esc</t></si>');
  }
  ss.write('</sst>');

  final archive = Archive()
    ..add(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet.toString()))
    ..add(ArchiveFile.string('xl/sharedStrings.xml', ss.toString()));
  return ZipEncoder().encodeBytes(archive);
}

CapstoneGroup group(String id, String name, List<String> emails) =>
    CapstoneGroup(
      id: id,
      name: name,
      isPremium: false,
      students: [
        for (var i = 0; i < emails.length; i++)
          StudentAccount(
            id: '$id-$i',
            name: 'Existing $i',
            email: emails[i],
            studentId: 'STU$i',
            password: 'x',
          ),
      ],
    );

void main() {
  final svc = StudentImportService();

  test('reads xlsx shared strings and column refs', () {
    final rows = svc.parse(
      bytes: buildXlsx([
        ['Name', 'Email', 'Group'],
        ['Juan Cruz', 'juan@dct.edu', 'Group 1'],
        ['Maria Reyes', 'maria@dct.edu', 'Group 2'],
      ]),
      extension: 'xlsx',
    );
    expect(rows.length, 2);
    expect(rows[0].name, 'Juan Cruz');
    expect(rows[0].email, 'juan@dct.edu');
    expect(rows[1].group, 'Group 2');
    expect(rows[1].rowNumber, 2);
  });

  test('reads csv and keeps quoted commas in a field', () {
    const csv =
        'Name,Email,Group\n"Cruz, Juan",cj@dct.edu,Group 3\nAna Lim,ana@dct.edu,Group 3\n';
    final rows = svc.parse(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      extension: 'csv',
    );
    expect(rows.length, 2);
    expect(rows[0].name, 'Cruz, Juan');
    expect(rows[1].name, 'Ana Lim');
  });

  test('validation flags dup, invalid, missing, and group overflow', () {
    final existing = [
      group('g1', 'Group 1', ['a@dct.edu', 'b@dct.edu', 'c@dct.edu', 'd@dct.edu']),
    ];
    final rows = svc.parse(
      bytes: buildXlsx([
        ['Name', 'Email', 'Group'],
        ['New One', 'a@dct.edu', 'Group 1'], // already registered
        ['New Two', 'new2@dct.edu', 'Group 1'], // fills Group 1 to 5 -> ok
        ['New Three', 'new3@dct.edu', 'Group 1'], // Group 1 full -> error
        ['Dup A', 'same@dct.edu', 'Group 9'], // ok, creates Group 9
        ['Dup B', 'same@dct.edu', 'Group 9'], // duplicate in file
        ['No Email', '', 'Group 9'], // missing email
        ['Bad Email', 'nope', 'Group 9'], // invalid email
      ]),
      extension: 'xlsx',
    );
    final preview = svc.validate(rows, existing);

    expect(preview.rows[0].message, 'Email already registered');
    expect(preview.rows[1].isOk, true);
    expect(preview.rows[2].message, contains('exceed 5'));
    expect(preview.rows[3].isOk, true);
    expect(preview.rows[4].message, contains('Duplicate email'));
    expect(preview.rows[5].message, 'Missing email');
    expect(preview.rows[6].message, 'Invalid email');
    expect(preview.validCount, 2);
    expect(preview.groupsToCreate, ['Group 9']);
  });

  test('throws when a required column is missing', () {
    expect(
      () => svc.parse(
        bytes: buildXlsx([
          ['Name', 'Email'],
          ['X', 'x@dct.edu'],
        ]),
        extension: 'xlsx',
      ),
      throwsA(isA<ImportException>()),
    );
  });
}
