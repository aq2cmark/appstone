import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';
import '../services/student_import_service.dart';

// Bulk student import: upload an .xlsx/.csv roster, review a validated preview,
// then create every valid row at once and copy out the generated credentials.
class ImportStudentsPage extends StatefulWidget {
  const ImportStudentsPage({
    super.key,
    required this.repo,
    required this.groups,
  });

  final AdminRepository repo;
  // Current groups from the portal's live stream, used to validate rows
  // (duplicate emails, group capacity, which groups need creating).
  final List<CapstoneGroup> groups;

  @override
  State<ImportStudentsPage> createState() => _ImportStudentsPageState();
}

class _ImportStudentsPageState extends State<ImportStudentsPage> {
  final _service = StudentImportService();

  String? _fileName;
  ImportPreview? _preview;
  StudentImportResult? _result;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Import students from Excel or CSV',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The file needs three columns in the first row: Name, Email, '
                  'and Group. Each student is auto-assigned a Student ID and a '
                  'temporary password. Groups named in the file are created if '
                  'they do not exist yet (max 5 members each).',
                  style: TextStyle(color: AppColors.textGrey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: _busy ? null : _pickAndParse,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_fileName == null ? 'Select File' : 'Change File'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _copyTemplate,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Copy template'),
                    ),
                  ],
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Selected: $_fileName',
                    style: const TextStyle(color: AppColors.textGrey),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _messageCard(Icons.error_outline, AppColors.primary, _error!),
        ],
        if (_busy) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_preview != null && _result == null) ...[
          const SizedBox(height: 16),
          _buildPreview(_preview!),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          _buildResult(_result!),
        ],
      ],
    );
  }

  // ---- Preview --------------------------------------------------------------

  Widget _buildPreview(ImportPreview preview) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _pill('${preview.validCount} valid', Colors.green),
                if (preview.errorCount > 0)
                  _pill('${preview.errorCount} with errors', AppColors.primary),
                if (preview.groupsToCreate.isNotEmpty)
                  _pill(
                    'Creates: ${preview.groupsToCreate.join(', ')}',
                    AppColors.gold,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Group')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final row in preview.rows)
                    DataRow(
                      cells: [
                        DataCell(Text('${row.data.rowNumber}')),
                        DataCell(Text(row.data.name)),
                        DataCell(Text(row.data.email)),
                        DataCell(Text(row.data.group)),
                        DataCell(
                          row.isOk
                              ? _pill('OK', Colors.green)
                              : Tooltip(
                                  message: row.message,
                                  child: _pill(row.message, AppColors.primary),
                                ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: preview.validCount == 0 || _busy ? null : _import,
                  icon: const Icon(Icons.group_add),
                  label: Text('Import ${preview.validCount} student(s)'),
                ),
                const SizedBox(width: 12),
                TextButton(onPressed: _reset, child: const Text('Cancel')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Result ---------------------------------------------------------------

  Widget _buildResult(StudentImportResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Imported ${result.created.length} student(s)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Copy these credentials now and give them to the students. The '
              'temporary passwords are also shown on each group in the '
              'dashboard.',
              style: TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 12),
            if (result.created.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _copyCredentials(result),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy all as CSV'),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Student ID')),
                    DataColumn(label: Text('Temp Password')),
                    DataColumn(label: Text('Group')),
                  ],
                  rows: [
                    for (final s in result.created)
                      DataRow(
                        cells: [
                          DataCell(Text(s.name)),
                          DataCell(SelectableText(s.studentId)),
                          DataCell(SelectableText(s.tempPassword)),
                          DataCell(Text(s.group)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            if (result.failures.isNotEmpty) ...[
              const SizedBox(height: 16),
              _messageCard(
                Icons.warning_amber_rounded,
                AppColors.gold,
                '${result.failures.length} row(s) could not be imported:\n'
                '${result.failures.map((f) => '- ${f.row.name}: ${f.message}').join('\n')}',
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Import another file'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Widgets --------------------------------------------------------------

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _messageCard(IconData icon, Color color, String message) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _pickAndParse() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the file. Please try again.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
      _result = null;
      _fileName = file.name;
    });

    try {
      final parsed = _service.parse(
        bytes: bytes,
        extension: file.extension ?? '',
      );
      if (parsed.isEmpty) {
        throw ImportException('No student rows found in the file.');
      }
      final preview = _service.validate(parsed, widget.groups);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null) return;

    setState(() => _busy = true);
    try {
      final result = await _service.commit(
        repo: widget.repo,
        validRows: preview.validRows.map((r) => r.data).toList(),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _preview = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _preview = null;
      _result = null;
      _error = null;
      _fileName = null;
    });
  }

  Future<void> _copyTemplate() async {
    const template =
        'Name,Email,Group\nJuan Cruz,juan.cruz@dct.edu,Capstone Group 1\n'
        'Maria Reyes,maria.reyes@dct.edu,Capstone Group 1\n';
    await Clipboard.setData(const ClipboardData(text: template));
    if (mounted) _snack('Template copied. Paste it into Excel and fill it in.');
  }

  Future<void> _copyCredentials(StudentImportResult result) async {
    final buffer = StringBuffer('Name,Email,Student ID,Temp Password,Group\n');
    for (final s in result.created) {
      buffer.writeln(
        '${s.name},${s.email},${s.studentId},${s.tempPassword},${s.group}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) _snack('Credentials copied as CSV.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
