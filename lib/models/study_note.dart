import 'dart:convert';

/// Represents a user's study note with parsed scripture references
class StudyNote {
  final String id;
  final String title;
  final String content;
  final List<String> parsedReferences;
  final DateTime createdAt;

  StudyNote({
    required this.id,
    required this.title,
    required this.content,
    required this.parsedReferences,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'parsed_references': parsedReferences,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StudyNote.fromJson(Map<String, dynamic> json) {
    return StudyNote(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Note',
      content: json['content'] as String? ?? '',
      parsedReferences: (json['parsed_references'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

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
