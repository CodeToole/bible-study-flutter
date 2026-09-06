import 'package:flutter_test/flutter_test.dart';
import 'package:bible_study_app/models/verse.dart';
import 'package:bible_study_app/models/book.dart';
import 'package:bible_study_app/services/scripture_parser.dart';
import 'package:bible_study_app/services/bible_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_study_app/models/study_note.dart';
import 'package:bible_study_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Verse Model Tests', () {
    test('Correctly parses JSON schema from assets/kjv.json', () {
      final json = {
        'book_name': 'Matthew',
        'book': 40,
        'chapter': 4,
        'verse': 4,
        'text':
            'But he answered and said, \u2039It is written, Man shall not live by bread alone\u203a',
      };

      final verse = Verse.fromJson(json);

      expect(verse.bookName, 'Matthew');
      expect(verse.book, 40);
      expect(verse.chapter, 4);
      expect(verse.verse, 4);
      expect(verse.hasRedLetters, isTrue);
      expect(verse.reference, 'Matthew 4:4');
      expect(
        verse.plainText,
        'But he answered and said, It is written, Man shall not live by bread alone',
      );
    });

    test('Old and New Testament distinction in BookInfo', () {
      const genesis = BookInfo(id: 1, name: 'Genesis', chapterCount: 50);
      const malachi = BookInfo(id: 39, name: 'Malachi', chapterCount: 4);
      const matthew = BookInfo(id: 40, name: 'Matthew', chapterCount: 28);
      const revelation = BookInfo(id: 66, name: 'Revelation', chapterCount: 22);

      expect(genesis.isOldTestament, isTrue);
      expect(genesis.isNewTestament, isFalse);

      expect(malachi.isOldTestament, isTrue);
      expect(malachi.isNewTestament, isFalse);

      expect(matthew.isOldTestament, isFalse);
      expect(matthew.isNewTestament, isTrue);

      expect(revelation.isOldTestament, isFalse);
      expect(revelation.isNewTestament, isTrue);
    });
  });

  group('ScriptureParser Regex Engine Tests', () {
    setUpAll(() async {
      await BibleService.instance.load();
    });

    test('Parses multi-reference citations without stripping numbered book prefixes', () {
      const sampleText = '''
Here are the study passages for tonight:
1. EXODUS 20:1-17 (Ten Commandments)
2. 1 KINGS 8:27-30 (Solomon's temple prayer)
3. 1 John 1:9
4. Song of Solomon 2:1
5. John 3:16
''';

      final results = ScriptureParser.parse(sampleText);

      expect(results.length, 5);

      expect(results[0].book.name, 'Exodus');
      expect(results[0].chapter, 20);
      expect(results[0].startVerse, 1);
      expect(results[0].endVerse, 17);
      expect(results[0].referenceLabel, 'Exodus 20:1-17');
      expect(results[0].verses.length, 17);

      expect(results[1].book.name, '1 Kings');
      expect(results[1].chapter, 8);
      expect(results[1].startVerse, 27);
      expect(results[1].endVerse, 30);
      expect(results[1].referenceLabel, '1 Kings 8:27-30');
      expect(results[1].verses.length, 4);

      expect(results[2].book.name, '1 John');
      expect(results[2].chapter, 1);
      expect(results[2].startVerse, 9);
      expect(results[2].referenceLabel, '1 John 1:9');
      expect(results[2].verses.length, 1);

      expect(results[3].book.name, 'Song of Solomon');
      expect(results[3].chapter, 2);
      expect(results[3].startVerse, 1);
      expect(results[3].referenceLabel, 'Song of Solomon 2:1');

      expect(results[4].book.name, 'John');
      expect(results[4].chapter, 3);
      expect(results[4].startVerse, 16);
      expect(results[4].referenceLabel, 'John 3:16');
      expect(results[4].verses.first.hasRedLetters, isTrue);
    });

    test('Searches scripture verses by keyword across the dataset', () {
      final matches = BibleService.instance.searchVerses('peace');
      expect(matches, isNotEmpty);
      expect(matches.first.plainText.toLowerCase(), contains('peace'));

      final empty = BibleService.instance.searchVerses('');
      expect(empty, isEmpty);
    });
  });

  group('PDF Sanitizer Tests', () {
    test('Scrubs smart quotes, dashes, and non-breaking spaces for PDF', () {
      const input = '“Grace”\u00A0—\u2013\u2212 ‘Peace’';
      // “ -> ", ” -> ", \u00A0 -> " ", — -> -, – -> -, − -> -, ‘ -> ', ’ -> '
      final sanitized = input
          .replaceAll('\u2013', '-')
          .replaceAll('\u2014', '-')
          .replaceAll('\u2212', '-')
          .replaceAll('\u2018', "'")
          .replaceAll('\u2019', "'")
          .replaceAll('\u201C', '"')
          .replaceAll('\u201D', '"')
          .replaceAll('\u00A0', ' ');

      expect(sanitized, '"Grace" --- \'Peace\'');
    });
  });

  group('StorageService Study Note Tests', () {
    test('deleteStudyNote removes note by id and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService.instance;
      await storage.init();

      final note1 = StudyNote(
        id: 'note_1',
        title: 'Title 1',
        content: 'Content 1',
        parsedReferences: ['Exodus 20:1-17'],
        createdAt: DateTime.now(),
      );
      final note2 = StudyNote(
        id: 'note_2',
        title: 'Title 2',
        content: 'Content 2',
        parsedReferences: ['John 3:16'],
        createdAt: DateTime.now(),
      );

      await storage.saveNote(note1);
      await storage.saveNote(note2);

      expect(storage.notes.any((n) => n.id == 'note_1'), isTrue);
      expect(storage.notes.any((n) => n.id == 'note_2'), isTrue);

      await storage.deleteStudyNote('note_1');

      expect(storage.notes.any((n) => n.id == 'note_1'), isFalse);
      expect(storage.notes.any((n) => n.id == 'note_2'), isTrue);

      // Re-initialize from storage to confirm persistence
      await storage.init();
      expect(storage.notes.any((n) => n.id == 'note_1'), isFalse);
      expect(storage.notes.any((n) => n.id == 'note_2'), isTrue);

      // Clean up
      await storage.deleteStudyNote('note_2');
      expect(storage.notes, isEmpty);
    });
  });
}
