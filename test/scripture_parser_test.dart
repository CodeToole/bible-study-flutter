import 'package:flutter_test/flutter_test.dart';
import 'package:bible_study_app/services/bible_service.dart';
import 'package:bible_study_app/services/scripture_parser.dart';
import 'package:bible_study_app/services/lesson_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await BibleService.instance.load();
  });

  group('ScriptureParser Complex Verse Lists & Ranges', () {
    test('Hebrews 10:1,4,5,6,7 resolves 5 verses', () {
      const input = 'Hebrews 10:1,4,5,6,7';
      final results = ScriptureParser.parse(input);

      expect(results.length, equals(1));
      final ref = results.first;
      expect(ref.book.name, equals('Hebrews'));
      expect(ref.chapter, equals(10));
      expect(ref.verseNumbers, equals([1, 4, 5, 6, 7]));
      expect(ref.verses.length, equals(5));
      expect(ref.verses.map((v) => v.verse).toList(), equals([1, 4, 5, 6, 7]));
      expect(ref.startVerse, equals(1));
      expect(ref.endVerse, equals(7));
      expect(ref.referenceLabel, equals('Hebrews 10:1,4,5,6,7'));
    });

    test('Revelation 19:11,12,13 resolves 3 verses', () {
      const input = 'Revelation 19:11,12,13';
      final results = ScriptureParser.parse(input);

      expect(results.length, equals(1));
      final ref = results.first;
      expect(ref.book.name, equals('Revelation'));
      expect(ref.chapter, equals(19));
      expect(ref.verseNumbers, equals([11, 12, 13]));
      expect(ref.verses.length, equals(3));
      expect(ref.verses.map((v) => v.verse).toList(), equals([11, 12, 13]));
      expect(ref.referenceLabel, equals('Revelation 19:11,12,13'));
    });

    test('John 1:3, 10-14 resolves verses 3, 10, 11, 12, 13, 14', () {
      const input = 'John 1:3, 10-14';
      final results = ScriptureParser.parse(input);

      expect(results.length, equals(1));
      final ref = results.first;
      expect(ref.book.name, equals('John'));
      expect(ref.chapter, equals(1));
      expect(ref.verseNumbers, equals([3, 10, 11, 12, 13, 14]));
      expect(ref.verses.length, equals(6));
      expect(
        ref.verses.map((v) => v.verse).toList(),
        equals([3, 10, 11, 12, 13, 14]),
      );
      expect(ref.referenceLabel, equals('John 1:3, 10-14'));
    });

    test('Psalms 119:73,74,79 resolves space and comma-separated discrete verses', () {
      const input = 'Psalms 119:73, 74, 79';
      final results = ScriptureParser.parse(input);

      expect(results.length, equals(1));
      final ref = results.first;
      expect(ref.book.name, equals('Psalms'));
      expect(ref.chapter, equals(119));
      expect(ref.verseNumbers, equals([73, 74, 79]));
      expect(ref.verses.length, equals(3));
      expect(ref.verses.map((v) => v.verse).toList(), equals([73, 74, 79]));
    });

    test('Jeremiah 23:1-2, 14, 16-17, 21-22 resolves mixed sub-ranges and discrete verses', () {
      const input = 'Jeremiah 23:1-2, 14, 16-17, 21-22';
      final results = ScriptureParser.parse(input);

      expect(results.length, equals(1));
      final ref = results.first;
      expect(ref.book.name, equals('Jeremiah'));
      expect(ref.chapter, equals(23));
      expect(ref.verseNumbers, equals([1, 2, 14, 16, 17, 21, 22]));
      expect(ref.verses.length, equals(7));
      expect(
        ref.verses.map((v) => v.verse).toList(),
        equals([1, 2, 14, 16, 17, 21, 22]),
      );
    });

    test('parseVerseNumbers handles whitespace, deduplication, and bounds', () {
      final numbers = ScriptureParser.parseVerseNumbers(' 1 ,  2 , 2, 5-7 , 6 ');
      expect(numbers, equals([1, 2, 5, 6, 7]));
    });
  });

  group('BibleService getSpecificVerses', () {
    test('retrieves verses by book name in specified order', () {
      final verses = BibleService.instance.getSpecificVerses(
        'Hebrews',
        10,
        [1, 4, 5, 6, 7],
      );

      expect(verses.length, equals(5));
      expect(verses.map((v) => v.verse).toList(), equals([1, 4, 5, 6, 7]));
      expect(verses.every((v) => v.bookName == 'Hebrews'), isTrue);
    });

    test('retrieves verses by numeric book ID string', () {
      // Hebrews is book 58
      final verses = BibleService.instance.getSpecificVerses(
        '58',
        10,
        [1, 4],
      );

      expect(verses.length, equals(2));
      expect(verses[0].verse, equals(1));
      expect(verses[1].verse, equals(4));
    });

    test('skips nonexistent verse numbers safely', () {
      // Hebrews 10 has 39 verses, verse 999 does not exist
      final verses = BibleService.instance.getSpecificVerses(
        'Hebrews',
        10,
        [1, 999, 4],
      );

      expect(verses.length, equals(2));
      expect(verses.map((v) => v.verse).toList(), equals([1, 4]));
    });
  });

  group('LessonParser Talking Points & Commentary Cleanliness', () {
    test('Consumes comma lists without leaving residual numbers in talking points', () {
      const outline = '''
1. Hebrews 10:1,4,5,6,7
- The law having a shadow of good things to come.
- Animal sacrifices could never make the comers thereunto perfect.
''';

      final lesson = LessonParser.parseLessonOutline(outline, BibleService.instance);
      expect(lesson.sections.isNotEmpty, isTrue);
      final point = lesson.sections.first.points.first;

      expect(point.rawCitation, equals('Hebrews 10:1,4,5,6,7'));
      expect(point.verses.length, equals(5));
      expect(point.teacherNotes.length, equals(2));
      expect(point.teacherNotes[0], equals('The law having a shadow of good things to come.'));
      expect(
        point.teacherNotes[1],
        equals('Animal sacrifices could never make the comers thereunto perfect.'),
      );

      // Verify no residual commas or stray verse numbers leaked into talking points
      for (final note in point.teacherNotes) {
        expect(note.startsWith(','), isFalse);
        expect(note.contains('4,5,6,7'), isFalse);
      }
    });

    test('Does not duplicate bracketed verse numbers when already fetched by citation', () {
      const outline = '''
1. John 5:39
[39] Search the scriptures; for in them ye think ye have eternal life: and they are they which testify of me.
- Jesus rebukes the Pharisees for not believing Moses.
''';

      final lesson = LessonParser.parseLessonOutline(outline, BibleService.instance);
      final point = lesson.sections.first.points.first;

      expect(point.verses.length, equals(1));
      expect(point.verses.first.verse, equals(39));
      expect(point.teacherNotes.length, equals(1));
      expect(point.teacherNotes.first, equals('Jesus rebukes the Pharisees for not believing Moses.'));
      expect(point.teacherNotes.any((n) => n.contains('[39]')), isFalse);
    });

    test('Filters bracketed verses inside bullet lines as well', () {
      const outline = '''
1. Hebrews 10:1, 4
- [1] For the law having a shadow of good things to come...
- [4] For it is not possible that the blood of bulls...
- The earthly priesthood was symbolic.
''';

      final lesson = LessonParser.parseLessonOutline(outline, BibleService.instance);
      final point = lesson.sections.first.points.first;

      expect(point.verses.length, equals(2));
      expect(point.teacherNotes.length, equals(1));
      expect(point.teacherNotes.first, equals('The earthly priesthood was symbolic.'));
    });
  });
}
