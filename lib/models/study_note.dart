import 'dart:convert';

/// Represents a user's study note with parsed scripture references
class StudyNote {
  final String id;
  final String title;
  final String content;
  final List<String> parsedReferences;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StudyNote({
    required this.id,
    required this.title,
    required this.content,
    required this.parsedReferences,
    required this.createdAt,
    this.updatedAt,
  });

  StudyNote copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? parsedReferences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      parsedReferences: parsedReferences ?? this.parsedReferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'parsed_references': parsedReferences,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory StudyNote.fromMap(Map<String, dynamic> map) {
    return StudyNote(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled Note',
      content: map['content'] as String? ?? '',
      parsedReferences: (map['parsed_references'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory StudyNote.fromJson(Map<String, dynamic> json) =>
      StudyNote.fromMap(json);

  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  static String encodeList(List<StudyNote> notes) =>
      jsonEncode(notes.map((n) => n.toJson()).toList());

  static List<StudyNote> decodeList(String raw) {
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((item) => StudyNote.fromJson(item))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
