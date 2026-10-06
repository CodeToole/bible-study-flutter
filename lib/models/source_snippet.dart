import 'dart:convert';

/// A short exhibit pinned beside scripture: a book page, article, chart,
/// photo, dictionary entry, or another text. Not a second Bible.
enum SourceKind {
  book,
  article,
  chart,
  photo,
  dictionary,
  otherText,
}

extension SourceKindLabel on SourceKind {
  String get label {
    switch (this) {
      case SourceKind.book:
        return 'Book';
      case SourceKind.article:
        return 'Article';
      case SourceKind.chart:
        return 'Chart';
      case SourceKind.photo:
        return 'Photo';
      case SourceKind.dictionary:
        return 'Dictionary';
      case SourceKind.otherText:
        return 'Other text';
    }
  }

  static SourceKind fromName(String? raw) {
    return SourceKind.values.firstWhere(
      (kind) => kind.name == raw,
      orElse: () => SourceKind.book,
    );
  }
}

class SourceSnippet {
  final String id;
  final SourceKind kind;
  final String title;
  final String citation;
  final String snippet;
  final String? imagePath;
  final List<String> verseKeys;
  final String? lessonTitle;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SourceSnippet({
    required this.id,
    required this.kind,
    required this.title,
    required this.citation,
    required this.snippet,
    this.imagePath,
    this.verseKeys = const [],
    this.lessonTitle,
    required this.createdAt,
    this.updatedAt,
  });

  SourceSnippet copyWith({
    String? id,
    SourceKind? kind,
    String? title,
    String? citation,
    String? snippet,
    String? imagePath,
    List<String>? verseKeys,
    String? lessonTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SourceSnippet(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      citation: citation ?? this.citation,
      snippet: snippet ?? this.snippet,
      imagePath: imagePath ?? this.imagePath,
      verseKeys: verseKeys ?? this.verseKeys,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'title': title,
      'citation': citation,
      'snippet': snippet,
      'image_path': imagePath,
      'verse_keys': verseKeys,
      'lesson_title': lessonTitle,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory SourceSnippet.fromJson(Map<String, dynamic> json) {
    return SourceSnippet(
      id: json['id'] as String? ?? '',
      kind: SourceKindLabel.fromName(json['kind'] as String?),
      title: json['title'] as String? ?? 'Untitled source',
      citation: json['citation'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      imagePath: json['image_path'] as String?,
      verseKeys: (json['verse_keys'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      lessonTitle: json['lesson_title'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'] as String),
    );
  }

  static String encodeList(List<SourceSnippet> sources) =>
      jsonEncode(sources.map((source) => source.toJson()).toList());

  static List<SourceSnippet> decodeList(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SourceSnippet.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
