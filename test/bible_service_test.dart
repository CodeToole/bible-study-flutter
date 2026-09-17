import 'package:flutter_test/flutter_test.dart';
import 'package:bible_study_app/services/bible_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BibleService getVerseRange Unit Tests', () {
    setUpAll(() async {
      await BibleService.instance.load();
    });

    test('returns correct list of verses for a valid multi-verse range', () {
      // Exodus is book 2, chapter 20, verses 1 to 17 (Ten Commandments)
      final verses = BibleService.instance.getVerseRange(2, 20, 1, 17);

      expect(verses.length, equals(17));
      expect(verses.first.verse, equals(1));
      expect(verses.last.verse, equals(17));
      expect(verses.first.bookName, equals('Exodus'));
      expect(verses.first.chapter, equals(20));
    });

    test('defaults endVerse to startVerse when endVerse is null', () {
      // John is book 43, chapter 3, verse 16
      final verses = BibleService.instance.getVerseRange(43, 3, 16, null);

      expect(verses.length, equals(1));
      expect(verses.single.verse, equals(16));
      expect(verses.single.reference, equals('John 3:16'));
    });

    test('returns single verse when startVerse equals endVerse', () {
      // Genesis is book 1, chapter 1, verse 1
      final verses = BibleService.instance.getVerseRange(1, 1, 1, 1);

      expect(verses.length, equals(1));
      expect(verses.single.verse, equals(1));
      expect(verses.single.reference, equals('Genesis 1:1'));
    });

    test('returns empty list for non-existent book or chapter', () {
      final invalidBook = BibleService.instance.getVerseRange(999, 1, 1, 5);
      expect(invalidBook, isEmpty);

      final invalidChapter = BibleService.instance.getVerseRange(1, 999, 1, 5);
      expect(invalidChapter, isEmpty);
    });

    test('returns empty list when startVerse is greater than available verses in chapter', () {
      // Malachi chapter 4 has 6 verses
      final outOfBoundsStart = BibleService.instance.getVerseRange(39, 4, 100, 105);
      expect(outOfBoundsStart, isEmpty);
    });

    test('returns empty list when startVerse is greater than endVerse', () {
      final invertedRange = BibleService.instance.getVerseRange(1, 1, 10, 5);
      expect(invertedRange, isEmpty);
    });

    test('handles full chapter ranges accurately', () {
      // Psalm 23 (book 19, chapter 23) has 6 verses
      final psalm23 = BibleService.instance.getVerseRange(19, 23, 1, 6);
      expect(psalm23.length, equals(6));
      expect(psalm23.map((v) => v.verse), equals([1, 2, 3, 4, 5, 6]));
    });
  });
}
