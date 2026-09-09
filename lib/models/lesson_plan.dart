import 'verse.dart';

/// Represents a flattened point with its parent section context for easy traversal in Podium Mode
class FlatLessonPoint {
  final int globalIndex;
  final LessonSection? section;
  final LessonPoint point;

  const FlatLessonPoint({
    required this.globalIndex,
    required this.section,
    required this.point,
  });
}

/// Represents a single interleaved point coupling a scripture passage
/// with vocabulary definitions and teacher talking points.
class LessonPoint {
  final int order;
  final String rawCitation;
  final List<Verse> verses;
  final Map<String, String> definitions;
  final List<String> teacherNotes;

  const LessonPoint({
    required this.order,
    required this.rawCitation,
    this.verses = const [],
    this.definitions = const {},
    this.teacherNotes = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'raw_citation': rawCitation,
      'verses': verses.map((v) => v.toJson()).toList(),
      'definitions': definitions,
      'teacher_notes': teacherNotes,
    };
  }

  factory LessonPoint.fromJson(Map<String, dynamic> json) {
    return LessonPoint(
      order: (json['order'] as num?)?.toInt() ?? 0,
      rawCitation: (json['raw_citation'] ?? json['rawCitation'] ?? '') as String,
      verses: (json['verses'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((v) => Verse.fromJson(v))
              .toList() ??
          const [],
      definitions: (json['definitions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
      teacherNotes: (json['teacher_notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  LessonPoint copyWith({
    int? order,
    String? rawCitation,
    List<Verse>? verses,
    Map<String, String>? definitions,
    List<String>? teacherNotes,
  }) {
    return LessonPoint(
      order: order ?? this.order,
      rawCitation: rawCitation ?? this.rawCitation,
      verses: verses ?? this.verses,
      definitions: definitions ?? this.definitions,
      teacherNotes: teacherNotes ?? this.teacherNotes,
    );
  }
}

/// Represents a thematic grouping of lesson points (e.g. "# COVENANTS", "# SIN").
class LessonSection {
  final String? heading;
  final List<LessonPoint> points;

  const LessonSection({
    this.heading,
    this.points = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'heading': heading,
      'points': points.map((p) => p.toJson()).toList(),
    };
  }

  factory LessonSection.fromJson(Map<String, dynamic> json) {
    return LessonSection(
      heading: json['heading'] as String?,
      points: (json['points'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((p) => LessonPoint.fromJson(p))
              .toList() ??
          const [],
    );
  }
}

/// Complete structured lesson plan following systematic expository teaching architecture.
class LessonPlan {
  final String id;
  final String title;
  final String? teacher;
  final String? date;
  final String? prayerCitation;
  final List<Verse> prayerVerses;
  final String? introduction;
  final String? conclusion;
  final List<LessonSection> sections;

  const LessonPlan({
    required this.id,
    required this.title,
    this.teacher,
    this.date,
    this.prayerCitation,
    this.prayerVerses = const [],
    this.introduction,
    this.conclusion,
    this.sections = const [],
  });

  /// Total count of all points across all sections
  int get totalPointsCount {
    int count = 0;
    for (final section in sections) {
      count += section.points.length;
    }
    return count;
  }

  /// Flattened list of all points preserving section associations for sequential presentation
  List<FlatLessonPoint> get allPointsFlat {
    final List<FlatLessonPoint> list = [];
    int globalIndex = 0;
    for (final section in sections) {
      for (final point in section.points) {
        list.add(
          FlatLessonPoint(
            globalIndex: globalIndex++,
            section: section,
            point: point,
          ),
        );
      }
    }
    return list;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'teacher': teacher,
      'date': date,
      'prayer_citation': prayerCitation,
      'prayer_verses': prayerVerses.map((v) => v.toJson()).toList(),
      'introduction': introduction,
      'conclusion': conclusion,
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    return LessonPlan(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? 'Untitled Lesson') as String,
      teacher: json['teacher'] as String?,
      date: json['date'] as String?,
      prayerCitation: (json['prayer_citation'] ?? json['prayerCitation']) as String?,
      prayerVerses: (json['prayer_verses'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((v) => Verse.fromJson(v))
              .toList() ??
          const [],
      introduction: json['introduction'] as String?,
      conclusion: json['conclusion'] as String?,
      sections: (json['sections'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((s) => LessonSection.fromJson(s))
              .toList() ??
          const [],
    );
  }
}
