import 'package:bible_study_app/models/study_note.dart';
import 'package:bible_study_app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService.instance;
    await storage.init();
  });

  StudyNote makeNote({
    required String id,
    required DateTime createdAt,
    String title = 'A study note',
  }) {
    return StudyNote(
      id: id,
      title: title,
      content: 'Genesis 1:1',
      parsedReferences: const ['Genesis 1:1'],
      createdAt: createdAt,
    );
  }

  test('saveNote creates and persists a note', () async {
    final createdAt = DateTime(2024, 1, 2, 3, 4);
    final note = makeNote(id: 'note-1', createdAt: createdAt);

    await storage.saveNote(note);

    expect(storage.notes, hasLength(1));
    expect(storage.notes.single.id, 'note-1');
    expect(storage.notes.single.createdAt, createdAt);

    await storage.init();
    expect(storage.notes.single.title, note.title);
    expect(storage.notes.single.createdAt, createdAt);
  });

  test(
    'updateNote replaces the existing note in-place and preserves its identity and creation time',
    () async {
      final createdAt = DateTime(2024, 1, 2, 3, 4);
      await storage.saveNote(makeNote(id: 'note-1', createdAt: createdAt));
      await storage.saveNote(
        makeNote(id: 'note-2', createdAt: DateTime(2024, 2, 3)),
      );
      final countBeforeUpdate = storage.notes.length;

      await storage.updateNote(
        makeNote(
          id: 'note-1',
          createdAt: DateTime(2030, 1, 1),
          title: 'Updated title',
        ),
      );

      expect(storage.notes, hasLength(countBeforeUpdate));
      expect(storage.notes[1].id, 'note-1');
      expect(storage.notes[1].title, 'Updated title');
      expect(storage.notes[1].createdAt, createdAt);
      expect(storage.notes[1].updatedAt, isNotNull);
      expect(storage.notes[1].updatedAt!.isAfter(createdAt), isTrue);

      await storage.init();
      final persisted = storage.notes.singleWhere((note) => note.id == 'note-1');
      expect(persisted.createdAt, createdAt);
      expect(persisted.updatedAt, isNotNull);
    },
  );

  test('updateNote rejects an unknown id without appending a note', () async {
    await storage.saveNote(
      makeNote(id: 'saved-note', createdAt: DateTime(2024, 1, 2)),
    );

    await expectLater(
      storage.updateNote(
        makeNote(id: 'missing-note', createdAt: DateTime(2024, 3, 4)),
      ),
      throwsArgumentError,
    );

    expect(storage.notes, hasLength(1));
    expect(storage.notes.single.id, 'saved-note');
  });
}
