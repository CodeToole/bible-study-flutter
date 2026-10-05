import 'package:bible_study_app/models/study_note.dart';
import 'package:bible_study_app/screens/study_notes_screen.dart';
import 'package:bible_study_app/services/bible_service.dart';
import 'package:bible_study_app/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await BibleService.instance.load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    await StorageService.instance.saveNote(
      StudyNote(
        id: 'edit-flow-note',
        title: 'Genesis study',
        content: 'Reflection on Genesis 1:1',
        parsedReferences: const ['Genesis 1:1'],
        createdAt: DateTime(2024, 1, 2),
      ),
    );
  });

  testWidgets(
    'editing a saved note populates the composer, switches tabs, and parses scripture',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StudyNotesScreen()));

      await tester.tap(find.text('Saved Notes (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Note'));
      await tester.pumpAndSettle();

      final composerFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((field) => field.controller != null)
          .map((field) => field.controller!.text)
          .toList();
      expect(composerFields, contains('Genesis study'));
      expect(composerFields, contains('Reflection on Genesis 1:1'));
      expect(find.text('Editing: Genesis study'), findsOneWidget);
      expect(find.text('Parsed Scripture Previews (1)'), findsOneWidget);
    },
  );

  testWidgets('Cancel / New Note clears the edit state and composer fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudyNotesScreen()));

    await tester.tap(find.text('Saved Notes (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Note'));
    await tester.pumpAndSettle();

    final cancelButton = find.text('Cancel / New Note');
    await tester.ensureVisible(cancelButton);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    final composerFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.controller != null)
        .map((field) => field.controller!.text)
        .toList();
    expect(composerFields, contains(''));
    expect(find.text('Editing: Genesis study'), findsNothing);
    expect(find.text('Cancel / New Note'), findsNothing);
  });

  testWidgets('a failed update preserves the title and content draft', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudyNotesScreen()));

    await tester.tap(find.text('Saved Notes (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Note'));
    await tester.pumpAndSettle();

    await StorageService.instance.deleteStudyNote('edit-flow-note');
    await tester.enterText(find.byType(TextField).at(0), 'Unsaved title draft');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Unsaved content draft on Genesis 1:1',
    );
    await tester.tap(find.text('Update Note'));
    await tester.pumpAndSettle();

    final composerFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.controller != null)
        .map((field) => field.controller!.text)
        .toList();
    expect(composerFields, contains('Unsaved title draft'));
    expect(composerFields, contains('Unsaved content draft on Genesis 1:1'));
    expect(find.text('Editing: Genesis study'), findsOneWidget);
    expect(
      find.text('Unable to save note. Your draft has been preserved.'),
      findsOneWidget,
    );
  });
}
