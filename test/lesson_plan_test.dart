import 'package:flutter_test/flutter_test.dart';
import 'package:bible_study_app/models/verse.dart';
import 'package:bible_study_app/models/lesson_plan.dart';
import 'package:bible_study_app/services/bible_service.dart';
import 'package:bible_study_app/services/lesson_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await BibleService.instance.load();
  });

  group('LessonPlan Model & Serialization Tests', () {
    test('LessonPoint JSON round-trip maintains all properties', () {
      const verse = Verse(
        bookName: 'Exodus',
        book: 2,
        chapter: 24,
        verse: 8,
        text: 'And Moses took the blood...',
      );

      const point = LessonPoint(
        order: 1,
        rawCitation: 'Exodus 24:1-8',
        verses: [verse],
        definitions: {'Sanctify': 'to set apart', 'Heart': 'Mind'},
        teacherNotes: [
          'The covenant was confirmed with blood.',
          'Moses sprinkled both the altar and the people.',
        ],
      );

      final json = point.toJson();
      final decoded = LessonPoint.fromJson(json);

      expect(decoded.order, 1);
      expect(decoded.rawCitation, 'Exodus 24:1-8');
      expect(decoded.verses.length, 1);
      expect(decoded.verses.first.reference, 'Exodus 24:8');
      expect(decoded.definitions['Sanctify'], 'to set apart');
      expect(decoded.definitions['Heart'], 'Mind');
      expect(decoded.teacherNotes.length, 2);
    });

    test('LessonPlan JSON round-trip and flat points calculations', () {
      const p1 = LessonPoint(
        order: 1,
        rawCitation: 'Exodus 20:1-17',
        teacherNotes: ['Ten Commandments'],
      );
      const p2 = LessonPoint(
        order: 2,
        rawCitation: 'Romans 6:1-14',
        definitions: {'Grace': 'Unmerited favor'},
      );
      const p3 = LessonPoint(
        order: 3,
        rawCitation: 'Hebrews 9:1-10',
      );

      const s1 = LessonSection(heading: 'THE LAW', points: [p1]);
      const s2 = LessonSection(heading: 'GRACE & SANCTUARY', points: [p2, p3]);

      const plan = LessonPlan(
        id: 'plan_1',
        title: 'Law and Grace',
        teacher: 'Brother Cornelius',
        date: '2026-10-14',
        prayerCitation: 'Psalms 100:1-5',
        introduction: 'Introductory notes',
        conclusion: 'Concluding synthesis',
        sections: [s1, s2],
      );

      expect(plan.totalPointsCount, 3);
      final flat = plan.allPointsFlat;
      expect(flat.length, 3);
      expect(flat[0].globalIndex, 0);
      expect(flat[0].section?.heading, 'THE LAW');
      expect(flat[0].point.rawCitation, 'Exodus 20:1-17');
      expect(flat[1].globalIndex, 1);
      expect(flat[1].section?.heading, 'GRACE & SANCTUARY');
      expect(flat[2].globalIndex, 2);

      final json = plan.toJson();
      final decoded = LessonPlan.fromJson(json);

      expect(decoded.id, 'plan_1');
      expect(decoded.title, 'Law and Grace');
      expect(decoded.teacher, 'Brother Cornelius');
      expect(decoded.date, '2026-10-14');
      expect(decoded.prayerCitation, 'Psalms 100:1-5');
      expect(decoded.introduction, 'Introductory notes');
      expect(decoded.conclusion, 'Concluding synthesis');
      expect(decoded.totalPointsCount, 3);
      expect(decoded.sections.length, 2);
    });
  });

  group('LessonParser Service Tests', () {
    test('Parses full markdown-lite IOG outline with prayer, definitions, and sections', () {
      const outline = '''
Title: The Two Covenants
Teacher: Brother Cornelius
Date: October 14, 2026
Prayer: Psalms 100:1-5
Intro: Overview of the two covenants from Sinai to Calvary.

# THE OLD COVENANT & ANIMAL SACRIFICE
1. EXODUS 24:1-8
Sanctify = to set apart
- The first covenant was confirmed with animal blood.
- Moses sprinkled the altar and the people.

2. HEBREWS 9:18-22
Remission = forgiveness of sins
- Without shedding of blood is no remission.

# THE NEW COVENANT
3. JEREMIAH 31:31-34
Heart = Mind
- God promised a new covenant with Israel and Judah.
- Laws will be written in their hearts.

Conclusion: Jesus Christ is the mediator of the New Testament through His own blood.
''';

      final lesson = LessonParser.parseLessonOutline(outline, BibleService.instance);

      expect(lesson.title, 'The Two Covenants');
      expect(lesson.teacher, 'Brother Cornelius');
      expect(lesson.date, 'October 14, 2026');
      expect(lesson.prayerCitation, 'Psalms 100:1-5');
      expect(lesson.prayerVerses.length, 5);
      expect(lesson.introduction, contains('Overview of the two covenants'));
      expect(lesson.conclusion, contains('mediator of the New Testament'));

      expect(lesson.sections.length, 2);
      expect(lesson.sections[0].heading, 'THE OLD COVENANT & ANIMAL SACRIFICE');
      expect(lesson.sections[0].points.length, 2);

      // Point 1
      final p1 = lesson.sections[0].points[0];
      expect(p1.order, 1);
      expect(p1.rawCitation, 'Exodus 24:1-8');
      expect(p1.verses.length, 8);
      expect(p1.definitions['Sanctify'], 'to set apart');
      expect(p1.teacherNotes.length, 2);
      expect(p1.teacherNotes[0], 'The first covenant was confirmed with animal blood.');

      // Point 2
      final p2 = lesson.sections[0].points[1];
      expect(p2.order, 2);
      expect(p2.rawCitation, 'Hebrews 9:18-22');
      expect(p2.verses.length, 5);
      expect(p2.definitions['Remission'], 'forgiveness of sins');
      expect(p2.teacherNotes.length, 1);

      // Section 2
      expect(lesson.sections[1].heading, 'THE NEW COVENANT');
      expect(lesson.sections[1].points.length, 1);
      final p3 = lesson.sections[1].points[0];
      expect(p3.order, 3);
      expect(p3.rawCitation, 'Jeremiah 31:31-34');
      expect(p3.verses.length, 4);
      expect(p3.definitions['Heart'], 'Mind');
      expect(p3.teacherNotes.length, 2);

      expect(lesson.totalPointsCount, 3);
    });

    test('Handles unnumbered outlines and inline definitions gracefully', () {
      const outline = '''
# FAITH AND WORKS
James 2:14-26
Faith = Belief and conviction
Works = Deeds of obedience
- Faith without works is dead being alone.
''';

      final lesson = LessonParser.parseLessonOutline(outline, BibleService.instance);

      expect(lesson.sections.length, 1);
      expect(lesson.sections.first.heading, 'FAITH AND WORKS');
      expect(lesson.sections.first.points.length, 1);

      final point = lesson.sections.first.points.first;
      expect(point.rawCitation, 'James 2:14-26');
      expect(point.verses.length, 13);
      expect(point.definitions['Faith'], 'Belief and conviction');
      expect(point.definitions['Works'], 'Deeds of obedience');
      expect(point.teacherNotes.length, 1);
      expect(point.teacherNotes.first, 'Faith without works is dead being alone.');
    });
  });
}
