/// Metadata about a book of the Bible
class BookInfo {
  final int id;
  final String name;
  final int chapterCount;

  const BookInfo({
    required this.id,
    required this.name,
    required this.chapterCount,
  });

  /// Old Testament: Genesis (1) through Malachi (39)
  bool get isOldTestament => id >= 1 && id <= 39;

  /// New Testament: Matthew (40) through Revelation (66)
  bool get isNewTestament => id >= 40 && id <= 66;

  String get testamentName => isOldTestament ? 'Old Testament' : 'New Testament';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name (Book $id, $chapterCount chs)';
}
