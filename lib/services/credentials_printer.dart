import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'admin_repository.dart';

// Builds and prints (or saves as PDF) a credentials roster - name, email,
// Student ID, and temp password - for the given groups. A temp password only
// exists until the student sets their own; after that it shows "(set own)",
// because their real password lives in Firebase Auth and cannot be read back.
class CredentialsPrinter {
  static Future<void> printRoster(List<CapstoneGroup> groups) async {
    final doc = pw.Document();
    final generatedAt = DateTime.now().toString().split('.').first;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Appstone - Student Credentials',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Generated $generatedAt',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          for (final group in groups) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              group.name,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            if (group.students.isEmpty)
              pw.Text(
                'No students.',
                style: const pw.TextStyle(color: PdfColors.grey600),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Name', 'Email', 'Student ID', 'Temp Password'],
                data: [
                  for (final s in group.students)
                    [
                      s.name,
                      s.email,
                      s.studentId,
                      s.tempPassword.isEmpty ? '(set own)' : s.tempPassword,
                    ],
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(1.8),
                },
              ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }
}
