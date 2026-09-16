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

  /// Whether the current platform supports ML Kit OCR (Android and iOS).
  static bool get isSupportedMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  OcrService({
    ImagePicker? picker,
    TextRecognizer? recognizer,
  })  : _picker = picker ?? ImagePicker(),
        _recognizer = recognizer ??
            (isSupportedMobilePlatform
                ? TextRecognizer(script: TextRecognitionScript.latin)
                : null);

  /// Picks an image from [source] with quality 90 and processes it with ML Kit.
  /// Returns the sanitized, normalized note text, or null if cancelled.
  Future<String?> scanNote({required ImageSource source}) async {
    if (!isSupportedMobilePlatform) return null;

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

      final reconstructedText = reconstructSpatialText(recognizedText);
      return cleanHandwrittenScriptures(reconstructedText);
    } catch (e) {
      debugPrint('OcrService.scanNote error: $e');
      rethrow;
    }
  }

  /// Extracts, filters, and clusters [TextLine]s spatially from [RecognizedText]
  /// across all blocks to reconstruct multi-column / tabbed notes into natural reading order.
  static String reconstructSpatialText(RecognizedText recognizedText) {
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    return reconstructSpatialTextFromLines(allLines);
  }

  /// Spatially sorts and clusters a list of [TextLine]s into merged lines of text,
  /// filtering out screenshot UI artifacts and joining segments horizontally.
  static String reconstructSpatialTextFromLines(List<TextLine> lines) {
    // 1. Filter out empty lines and screenshot UI artifacts
    final validLines = lines.where((line) {
      final text = line.text.trim();
      if (text.isEmpty) return false;
      if (isScreenshotArtifact(text)) return false;
      return true;
    }).toList();

    if (validLines.isEmpty) return '';

    // 2. Sort lines primarily by vertical baseline (Y-axis / boundingBox.top)
    validLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    // 3. Cluster lines into vertical row groups whose boundingBox.top values
    // fall within a reasonable threshold (e.g. within 12-16 pixels, or ~half the line height).
    final List<List<TextLine>> rowGroups = [];

    for (final line in validLines) {
      if (rowGroups.isEmpty) {
        rowGroups.add([line]);
        continue;
      }

      final currentGroup = rowGroups.last;
      final avgHeight = currentGroup
              .map((l) => l.boundingBox.height)
              .reduce((a, b) => a + b) /
          currentGroup.length;

      // Group lines whose boundingBox.top falls within ~half the line height (or 12-16 px default)
      final threshold = avgHeight > 0
          ? (avgHeight * 0.5).clamp(12.0, 32.0)
          : 14.0;

      final groupTop = currentGroup
              .map((l) => l.boundingBox.top)
              .reduce((a, b) => a + b) /
          currentGroup.length;

      if ((line.boundingBox.top - groupTop).abs() <= threshold) {
        currentGroup.add(line);
      } else {
        rowGroups.add([line]);
      }
    }

    // 4. Within each vertical row group, sort elements horizontally (X-axis / boundingBox.left)
    // from left to right, and join segments with a single space.
    // Then join rows with newlines to reconstruct the natural reading order.
    final rowStrings = <String>[];
    for (final group in rowGroups) {
      group.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final mergedRow = group
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .join(' ');
      if (mergedRow.isNotEmpty) {
        rowStrings.add(mergedRow);
      }
    }

    return rowStrings.join('\n');
  }

  /// Identifies whether [text] is a known screenshot UI artifact (e.g. standalone
  /// timestamps like "11:58", battery percentages like "100%", Android navigation
  /// bar strings like "lll", or status bar indicators like "5G").
  static bool isScreenshotArtifact(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;

    // Single timestamps: e.g. "11:58", "09:41", "1:30 PM", "11:58am"
    final timestampRegex = RegExp(
      r'^(?:(?:0?[1-9]|1[0-2]):[0-5][0-9](?:\s*[AaPp][Mm])?|(?:[01]?[0-9]|2[0-3]):[0-5][0-9])$',
    );
    if (timestampRegex.hasMatch(trimmed)) {
      return true;
    }

    // Battery percentages: e.g. "100%", "98%", "⚡ 85%", "50 %"
    final batteryRegex = RegExp(r'^[⚡🔋]?\s*\d{1,3}\s*%$');
    if (batteryRegex.hasMatch(trimmed)) {
      return true;
    }

    // Android navigation bar button artifacts: e.g. "lll", "|||", "III", "///", "||"
    final navRegex = RegExp(r'^(?:[lI|\/\\]\s*){2,5}$');
    if (navRegex.hasMatch(trimmed)) {
      return true;
    }

    // Common mobile status bar network indicators when standalone: e.g. "LTE", "5G", "Wi-Fi"
    final statusRegex = RegExp(
      r'^(?:LTE|5G|4G|3G|VoLTE|Wi-Fi|WiFi)$',
      caseSensitive: false,
    );
    if (statusRegex.hasMatch(trimmed)) {
      return true;
    }

    return false;
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

      // Check if the line is a screenshot UI artifact (e.g. timestamp, battery, nav buttons)
      if (isScreenshotArtifact(trimmed)) {
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
