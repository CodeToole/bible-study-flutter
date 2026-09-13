import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Service responsible for capturing handwritten notes and extracting
/// clean, normalized Scripture outlines using on-device ML Kit text recognition.
class OcrService {
  final ImagePicker _picker;
  final TextRecognizer? _recognizer;
  bool _isDisposed = false;

  OcrService({
    ImagePicker? picker,
    TextRecognizer? recognizer,
  })  : _picker = picker ?? ImagePicker(),
        _recognizer = recognizer ??
            (kIsWeb
                ? null
                : TextRecognizer(script: TextRecognitionScript.latin));

  /// Picks an image from [source] with quality 90 and processes it with ML Kit.
  /// Returns the sanitized, normalized note text, or null if cancelled.
  Future<String?> scanNote({required ImageSource source}) async {
    if (kIsWeb) return null;

    if (_isDisposed) {
      throw StateError('Cannot scan with a disposed OcrService.');
    }

    if (_recognizer == null) return null;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image == null) return null;

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _recognizer.processImage(inputImage);

      return cleanHandwrittenScriptures(recognizedText.text);
    } catch (e) {
      debugPrint('OcrService.scanNote error: $e');
      rethrow;
    }
  }

  /// Normalizes handwritten scripture outlines, resolves common abbreviations,
  /// fixes OCR colon/semicolon confusions, and removes scribble artifacts.
  static String cleanHandwrittenScriptures(String raw) {
    if (raw.trim().isEmpty) return '';

    String cleaned = raw;

    // 1. Convert semicolons between chapter and verse to colons: (\d+)\s*;\s*(\d+) -> $1:$2
    // e.g. "22;14-15" -> "22:14-15", "Exodus 20; 1-17" -> "Exodus 20:1-17"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d+)\s*;\s*(\d+)'),
      (match) => '${match[1]}:${match[2]}',
    );

    // 2. Normalize Roman numerals and spacing in numbered books
    // e.g. (I|1) Thes -> 1 Thessalonians, (II|2) Thes -> 2 Thessalonians
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:I|1)\s*Thess?(?:\.|\b)', caseSensitive: false),
      '1 Thessalonians',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:II|2)\s*Thess?(?:\.|\b)', caseSensitive: false),
      '2 Thessalonians',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:I|1)\s*Cor(?:\.|\b)', caseSensitive: false),
      '1 Corinthians',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:II|2)\s*Cor(?:\.|\b)', caseSensitive: false),
      '2 Corinthians',
    );

    // 3. Normalize common handwritten scripture abbreviations
    // \bEx\b -> Exodus
    cleaned = cleaned.replaceAll(
      RegExp(r'\bEx(?:\.|\b)', caseSensitive: false),
      'Exodus',
    );
    // \bEccl\b -> Ecclesiastes
    cleaned = cleaned.replaceAll(
      RegExp(r'\bEccl(?:\.|\b)', caseSensitive: false),
      'Ecclesiastes',
    );
    // \bLev\b -> Leviticus
    cleaned = cleaned.replaceAll(
      RegExp(r'\bLev(?:\.|\b)', caseSensitive: false),
      'Leviticus',
    );
    // \bNum\b -> Numbers
    cleaned = cleaned.replaceAll(
      RegExp(r'\bNum(?:\.|\b)', caseSensitive: false),
      'Numbers',
    );
    // \bJosh\b -> Joshua
    cleaned = cleaned.replaceAll(
      RegExp(r'\bJosh(?:\.|\b)', caseSensitive: false),
      'Joshua',
    );
    // \bMat\b -> Matthew
    cleaned = cleaned.replaceAll(
      RegExp(r'\bMat(?:\.|\b)', caseSensitive: false),
      'Matthew',
    );
    // \bIsa\b -> Isaiah
    cleaned = cleaned.replaceAll(
      RegExp(r'\bIsa(?:\.|\b)', caseSensitive: false),
      'Isaiah',
    );
    // \bIs\b (only when preceding chapter or verse numbers) -> Isaiah
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bIs(?:\.|\b)(?=\s*\d+)', caseSensitive: false),
      (_) => 'Isaiah',
    );
    // \bZech\b -> Zechariah
    cleaned = cleaned.replaceAll(
      RegExp(r'\bZech(?:\.|\b)', caseSensitive: false),
      'Zechariah',
    );
    // \bDan\b -> Daniel
    cleaned = cleaned.replaceAll(
      RegExp(r'\bDan(?:\.|\b)', caseSensitive: false),
      'Daniel',
    );
    // \bMic\b -> Micah
    cleaned = cleaned.replaceAll(
      RegExp(r'\bMic(?:\.|\b)', caseSensitive: false),
      'Micah',
    );

    // 4. Remove stray scribble artifacts and crossed-out markings
    // Sequences of 3 or more squiggles, dashes, underscores, equals, or asterisks
    cleaned = cleaned.replaceAll(RegExp(r'[~_\-=*#]{3,}'), '');
    // Crossed-out "XXXXX" or "xxxxx" scribbles
    cleaned = cleaned.replaceAll(RegExp(r'\b[xX]{3,}\b'), '');

    // 5. Line-by-line cleanup: remove lines that consist entirely of scribble artifacts
    final lines = cleaned.split('\n');
    final processedLines = <String>[];

    for (final line in lines) {
      // Strip leading/trailing stray non-alphanumerics often left by margin scribbles
      final trimmed = line
          .replaceAll(RegExp(r'^[~`^|_|*#><]+\s*'), '')
          .replaceAll(RegExp(r'\s*[~`^|_|*#><]+$'), '')
          .trim();

      if (trimmed.isEmpty) {
        processedLines.add('');
        continue;
      }

      // Check if the line contains at least one letter or digit
      final hasContent = RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed);
      if (!hasContent) {
        continue; // drop scribble-only lines
      }

      processedLines.add(trimmed);
    }

    // Collapse consecutive empty lines (more than 2) down to 1 empty line
    return processedLines
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Cleans up resources.
  Future<void> dispose() async {
    _isDisposed = true;
    if (_recognizer != null) {
      await _recognizer.close();
    }
  }
}
