import 'package:flutter_test/flutter_test.dart';
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
}
