import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../app_colors.dart';

// Paper checker placeholder screen.
// File picking and real document analysis can be added later.
class PaperCheckerScreen extends StatefulWidget {
  const PaperCheckerScreen({super.key});

  @override
  State<PaperCheckerScreen> createState() => _PaperCheckerScreenState();
}

class _PaperCheckerScreenState extends State<PaperCheckerScreen> {
  // Used to show sample check results after pressing Run Basic Check.
  bool checked = false;
  PlatformFile? selectedFile;

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
                    'Upload and check your capstone paper format.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.upload_file,
                            color: AppColors.primary,
                            size: 56,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedFile?.name ?? 'Tap to select document',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedFile == null
                                ? 'PDF, DOC, DOCX - Max 10MB'
                                : fileSizeText(selectedFile!.size),
                            style: TextStyle(color: AppColors.textGrey),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: pickPaper,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Select File'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: runBasicCheck,
                    icon: const Icon(Icons.fact_check),
                    label: const Text('Run Basic Check'),
                  ),
                  if (checked) ...[
                    const SizedBox(height: 16),
                    const Card(
                      color: Colors.white,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            title: Text('Title page'),
                            subtitle: Text('Ready for review'),
                          ),
                          ListTile(
                            leading: Icon(Icons.warning, color: Colors.orange),
                            title: Text('Margins and spacing'),
                            subtitle: Text('Manual checking still needed'),
                          ),
                          ListTile(
                            leading: Icon(Icons.warning, color: Colors.orange),
                            title: Text('References'),
                            subtitle: Text('Manual checking still needed'),
                          ),
                        ],
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

  Future<void> pickPaper() async {
    // FilePicker opens the native file browser on mobile/desktop
    // and the browser file chooser on web.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;
    setState(() {
      selectedFile = result.files.single;
      checked = false;
    });
  }

  void runBasicCheck() {
    if (selectedFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a paper first.')));
      return;
    }
    setState(() => checked = true);
  }

  String fileSizeText(int bytes) {
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB selected';
    return '${(kb / 1024).toStringAsFixed(1)} MB selected';
  }
}
