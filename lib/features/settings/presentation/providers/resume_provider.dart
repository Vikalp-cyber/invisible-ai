import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/common_providers.dart';
import '../../../../services/preference_service.dart';

class ResumeProfile {
  const ResumeProfile({
    required this.text,
    this.fileName = '',
  });

  final String text;
  final String fileName;

  bool get hasText => text.trim().isNotEmpty;

  int get charCount => text.trim().length;

  ResumeProfile copyWith({String? text, String? fileName}) {
    return ResumeProfile(
      text: text ?? this.text,
      fileName: fileName ?? this.fileName,
    );
  }
}

/// Local resume / candidate profile used for interview-grounded answers.
class ResumeProfileNotifier extends AsyncNotifier<ResumeProfile> {
  PreferenceService get _prefs => ref.read(preferenceServiceProvider);

  @override
  Future<ResumeProfile> build() async {
    ref.keepAlive();
    return ResumeProfile(
      text: _prefs.getResumeText(),
      fileName: _prefs.getResumeFileName(),
    );
  }

  Future<void> saveText(String text, {String? fileName}) async {
    await _prefs.saveResume(text: text, fileName: fileName);
    state = AsyncData(
      ResumeProfile(
        text: _prefs.getResumeText(),
        fileName: _prefs.getResumeFileName(),
      ),
    );
  }

  Future<void> clear() async {
    await _prefs.clearResume();
    state = const AsyncData(ResumeProfile(text: '', fileName: ''));
  }

  /// Opens a file picker and imports `.pdf` / `.txt` / `.md` as plain text.
  Future<void> importFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'md'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw Exception('Could not read the selected file path.');
    }

    final name = file.name;
    final lower = name.toLowerCase();
    late final String extracted;

    if (lower.endsWith('.pdf')) {
      extracted = await _extractPdfText(path);
    } else if (lower.endsWith('.txt') || lower.endsWith('.md')) {
      extracted = await File(path).readAsString(encoding: utf8);
    } else {
      throw Exception('Unsupported file type. Use PDF, TXT, or MD.');
    }

    final trimmed = extracted.trim();
    if (trimmed.isEmpty) {
      throw Exception(
        'No text found in that file. Scanned image PDFs are not supported — '
        'use a text PDF or paste the resume.',
      );
    }

    await saveText(trimmed, fileName: name);
  }

  Future<String> _extractPdfText(String path) async {
    final bytes = await File(path).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final buffer = StringBuffer();
      for (var i = 0; i < document.pages.count; i++) {
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (pageText.trim().isEmpty) continue;
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write(pageText.trim());
        if (buffer.length >= AppConstants.maxResumeChars) break;
      }
      return buffer.toString();
    } finally {
      document.dispose();
    }
  }
}

final resumeProfileProvider =
    AsyncNotifierProvider<ResumeProfileNotifier, ResumeProfile>(
  ResumeProfileNotifier.new,
);
