/// Represents a single Bible verse from the canonical dataset.
class Verse {
  final String bookName;
  final int book;
  final int chapter;
  final int verse;
  final String text;

  const Verse({
    required this.bookName,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  /// Factory constructor to parse verse from assets/kjv.json schema
  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      bookName: (json['book_name'] ?? json['bookName'] ?? '') as String,
      book: (json['book'] as num?)?.toInt() ?? 0,
      chapter: (json['chapter'] as num?)?.toInt() ?? 0,
      verse: (json['verse'] as num?)?.toInt() ?? 0,
      text: (json['text'] ?? '') as String,
    );
  }

  /// Converts verse to JSON matching the dataset schema
  Map<String, dynamic> toJson() {
    return {
      'book_name': bookName,
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
    };
  }

  /// Canonical reference string, e.g. "John 3:16" or "1 Kings 8:27"
  String get reference => '$bookName $chapter:$verse';

  /// Returns true if this verse contains words of Jesus enclosed in unicode brackets \u2039...\u203a or ‹...›
  bool get hasRedLetters =>
      text.contains('\u2039') ||
      text.contains('‹') ||
      text.contains('\u203a') ||
      text.contains('›');

  /// Clean plain text without formatting symbols (\u00b6, \u2039, \u203a, etc.)
  String get plainText {
    return text
        .replaceAll('\u00b6', '')
        .replaceAll('¶', '')
        .replaceAll('\u2039', '')
        .replaceAll('\u203a', '')
        .replaceAll('‹', '')
        .replaceAll('›', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .trim();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Verse &&
          runtimeType == other.runtimeType &&
          book == other.book &&
          chapter == other.chapter &&
          verse == other.verse;

  @override
  int get hashCode => Object.hash(book, chapter, verse);

  @override
  String toString() => '$reference: $text';
}
