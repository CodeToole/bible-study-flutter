import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:bible_study_app/services/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrService Scripture Sanitization Tests', () {
    test('Converts semicolons between chapter and verse to colons', () {
      const input = 'Revelation 22;14-15 and Exodus 20;1-17 and Luke 1; 37';
      final result = OcrService.cleanHandwrittenScriptures(input);
      expect(result, contains('Revelation 22:14-15'));
      expect(result, contains('Exodus 20:1-17'));
      expect(result, contains('Luke 1:37'));
    });

    test('Normalizes common handwritten scripture abbreviations', () {
      const input = '''
Ex 20:1-17
Eccl 3:1-8
Lev 19:18
Num 6:24-26
Josh 1:8
Mat 5:14-16
Isa 40:28-31
Is 53:5
1 Thes 5:16-18
I Thes 4:13
2 Thes 3:3
II Thes 2:1-3
1 Cor 13:4-8
I Cor 15:51-57
2 Cor 5:17
II Cor 12:9
Zech 4:6
Dan 12:3
Mic 6:8
''';

      final result = OcrService.cleanHandwrittenScriptures(input);

      expect(result, contains('Exodus 20:1-17'));
      expect(result, contains('Ecclesiastes 3:1-8'));
      expect(result, contains('Leviticus 19:18'));
      expect(result, contains('Numbers 6:24-26'));
      expect(result, contains('Joshua 1:8'));
      expect(result, contains('Matthew 5:14-16'));
      expect(result, contains('Isaiah 40:28-31'));
      expect(result, contains('Isaiah 53:5'));
      expect(result, contains('1 Thessalonians 5:16-18'));
      expect(result, contains('1 Thessalonians 4:13'));
      expect(result, contains('2 Thessalonians 3:3'));
      expect(result, contains('2 Thessalonians 2:1-3'));
      expect(result, contains('1 Corinthians 13:4-8'));
      expect(result, contains('1 Corinthians 15:51-57'));
      expect(result, contains('2 Corinthians 5:17'));
      expect(result, contains('2 Corinthians 12:9'));
      expect(result, contains('Zechariah 4:6'));
      expect(result, contains('Daniel 12:3'));
      expect(result, contains('Micah 6:8'));
    });

    test('Removes scribble artifacts, stray symbols, and crossed-out markings', () {
      const input = '''
~~~~~
=== Title: Covenant Study ===
xxxxx
Ex 20;1-17
---
####
Notes: Keep the Sabbath day holy.
***
~~~~~
''';

      final result = OcrService.cleanHandwrittenScriptures(input);
      expect(result, isNot(contains('~~~~~')));
      expect(result, isNot(contains('xxxxx')));
      expect(result, isNot(contains('***')));
      expect(result, contains('Exodus 20:1-17'));
      expect(result, contains('Notes: Keep the Sabbath day holy.'));
    });
  });

  group('OcrService Screenshot UI Artifact Filtering Tests', () {
    test('Identifies timestamps, battery percentages, and nav bar symbols as artifacts', () {
      // Timestamps
      expect(OcrService.isScreenshotArtifact('11:58'), isTrue);
      expect(OcrService.isScreenshotArtifact('09:41'), isTrue);
      expect(OcrService.isScreenshotArtifact('1:30 PM'), isTrue);
      expect(OcrService.isScreenshotArtifact('11:58am'), isTrue);
      expect(OcrService.isScreenshotArtifact('23:59'), isTrue);

      // Battery percentages
      expect(OcrService.isScreenshotArtifact('100%'), isTrue);
      expect(OcrService.isScreenshotArtifact('98%'), isTrue);
      expect(OcrService.isScreenshotArtifact('⚡ 85%'), isTrue);
      expect(OcrService.isScreenshotArtifact('50 %'), isTrue);

      // Android navigation button OCR artifacts
      expect(OcrService.isScreenshotArtifact('lll'), isTrue);
      expect(OcrService.isScreenshotArtifact('|||'), isTrue);
      expect(OcrService.isScreenshotArtifact('III'), isTrue);
      expect(OcrService.isScreenshotArtifact('///'), isTrue);
      expect(OcrService.isScreenshotArtifact('||'), isTrue);

      // Status bar network indicators
      expect(OcrService.isScreenshotArtifact('5G'), isTrue);
      expect(OcrService.isScreenshotArtifact('LTE'), isTrue);
      expect(OcrService.isScreenshotArtifact('Wi-Fi'), isTrue);
    });

    test('Preserves valid scriptures and outline titles', () {
      expect(OcrService.isScreenshotArtifact('Romans 8:28'), isFalse);
      expect(OcrService.isScreenshotArtifact('1. The Way of Peace'), isFalse);
      expect(OcrService.isScreenshotArtifact('Exodus 20:1-17'), isFalse);
      expect(OcrService.isScreenshotArtifact('Hebrews 11:1'), isFalse);
      expect(OcrService.isScreenshotArtifact('Keep the commandments'), isFalse);
    });

    test('cleanHandwrittenScriptures filters out screenshot artifacts directly', () {
      const input = '''
11:58
100%
=== Lesson: The Faith ===
1. Faith Hebrews 11:1
lll
''';
      final result = OcrService.cleanHandwrittenScriptures(input);
      expect(result, isNot(contains('11:58')));
      expect(result, isNot(contains('100%')));
      expect(result, isNot(contains('lll')));
      expect(result, contains('Lesson: The Faith'));
      expect(result, contains('1. Faith Hebrews 11:1'));
    });
  });

  group('OcrService Spatial Line Sorting & Merging Tests', () {
    TextLine makeLine(
      String text, {
      required double top,
      required double left,
      double height = 24.0,
      double width = 120.0,
    }) {
      return TextLine(
        text: text,
        elements: const [],
        boundingBox: Rect.fromLTWH(left, top, width, height),
        recognizedLanguages: const ['en'],
        cornerPoints: const [],
        confidence: 1.0,
        angle: 0.0,
      );
    }

    test('Reconstructs multi-column lines horizontally by vertical baseline', () {
      // Column 1 (Left): Outline points
      // Column 2 (Right): Scripture citations
      // Simulated out-of-order block lines:
      final lines = [
        // Column 1
        makeLine('1. Creation', top: 100, left: 30),
        makeLine('2. The Fall', top: 150, left: 30),
        makeLine('3. Redemption', top: 200, left: 30),

        // Column 2 (slight baseline variation of 2-3px)
        makeLine('Gen 1:1', top: 102, left: 250),
        makeLine('Gen 3;1-6', top: 149, left: 250),
        makeLine('Rom 5:8', top: 203, left: 250),
      ];

      final merged = OcrService.reconstructSpatialTextFromLines(lines);
      final cleaned = OcrService.cleanHandwrittenScriptures(merged);

      final resultLines = cleaned.split('\n');
      expect(resultLines.length, equals(3));
      expect(resultLines[0], equals('1. Creation Gen 1:1'));
      expect(resultLines[1], equals('2. The Fall Gen 3:1-6'));
      expect(resultLines[2], equals('3. Redemption Rom 5:8'));
    });

    test('Filters screenshot UI artifacts during spatial reconstruction', () {
      final lines = [
        makeLine('11:58', top: 10, left: 20),
        makeLine('100%', top: 10, left: 350),
        makeLine('Title: Faith Study', top: 60, left: 50),
        makeLine('1. Faith', top: 110, left: 30),
        makeLine('Hebrews 11:1', top: 112, left: 200),
        makeLine('lll', top: 800, left: 180),
      ];

      final merged = OcrService.reconstructSpatialTextFromLines(lines);
      expect(merged, isNot(contains('11:58')));
      expect(merged, isNot(contains('100%')));
      expect(merged, isNot(contains('lll')));
      expect(merged, contains('Title: Faith Study'));
      expect(merged, contains('1. Faith Hebrews 11:1'));
    });

    test('reconstructSpatialText merges across multiple TextBlocks', () {
      // Simulate ML Kit separating columns into two distinct TextBlocks
      final block1 = TextBlock(
        text: '1. Creation\n2. The Fall',
        lines: [
          makeLine('1. Creation', top: 100, left: 30),
          makeLine('2. The Fall', top: 150, left: 30),
        ],
        boundingBox: const Rect.fromLTWH(30, 100, 150, 80),
        recognizedLanguages: const ['en'],
        cornerPoints: const [],
      );

      final block2 = TextBlock(
        text: 'Gen 1:1\nGen 3:1-6',
        lines: [
          makeLine('Gen 1:1', top: 104, left: 220),
          makeLine('Gen 3:1-6', top: 152, left: 220),
        ],
        boundingBox: const Rect.fromLTWH(220, 100, 150, 80),
        recognizedLanguages: const ['en'],
        cornerPoints: const [],
      );

      final recognizedText = RecognizedText(
        text: '1. Creation\n2. The Fall\nGen 1:1\nGen 3:1-6',
        blocks: [block1, block2],
      );

      final reconstructed = OcrService.reconstructSpatialText(recognizedText);
      expect(
        reconstructed,
        equals('1. Creation Gen 1:1\n2. The Fall Gen 3:1-6'),
      );
    });
  });
}
