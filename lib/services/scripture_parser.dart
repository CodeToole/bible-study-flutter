import '../models/verse.dart';
import '../models/book.dart';
import 'bible_service.dart';

/// Represents a successfully parsed and resolved Scripture reference
class ParsedScriptureRef {
  final String rawMatch;
  final BookInfo book;
  final int chapter;
  final List<int> verseNumbers;
  final List<Verse> verses;
  final String? verseSpec;
  final int? _startVerse;
  final int? _endVerse;

  ParsedScriptureRef({
    required this.rawMatch,
    required this.book,
    required this.chapter,
    required this.verseNumbers,
    int? startVerse,
    int? endVerse,
    required this.verses,
    this.verseSpec,
  })  : _startVerse = startVerse,
        _endVerse = endVerse;

  int get startVerse =>
      _startVerse ?? (verseNumbers.isNotEmpty ? verseNumbers.first : 1);

  int? get endVerse =>
      _endVerse ?? (verseNumbers.length > 1 ? verseNumbers.last : null);

  String get referenceLabel {
    if (verseSpec != null && verseSpec!.isNotEmpty) {
      return '${book.name} $chapter:$verseSpec';
    }
    if (verseNumbers.isEmpty) {
      return '${book.name} $chapter:$startVerse';
    }
    if (verseNumbers.length == 1) {
      return '${book.name} $chapter:${verseNumbers.first}';
    }
    if (endVerse != null && endVerse != startVerse) {
      return '${book.name} $chapter:$startVerse-$endVerse';
    }
    return '${book.name} $chapter:${verseNumbers.join(",")}';
  }
}

/// Type alias for backward and naming compatibility
typedef ParsedScriptureReference = ParsedScriptureRef;

/// Multi-reference regex engine that extracts multiple Bible references and ranges
/// without stripping numbered book prefixes (e.g. 1 Kings, 2 Samuel, 1 Peter).
class ScriptureParser {
  // Regex supporting numbered prefixes (1-3), book names (including "Song of Solomon"),
  // chapter, and comma-separated verses and mixed sub-ranges.
  // e.g. "Hebrews 10:1,4,5,6,7", "Revelation 19:11,12,13", "John 1:3, 10-14", "Jeremiah 23:1-2, 14, 16-17, 21-22".
  static final RegExp _citationRegex = RegExp(
    r'\b((?:[1-3]\s+)?[A-Za-z]+(?:\s+of\s+(?:Solomon|Songs))?)\s+(\d+)[:\.](\d+(?:\s*[-–—]\s*\d+)?(?:\s*,\s*\d+(?:\s*[-–—]\s*\d+)?)*)',
    caseSensitive: false,
  );

  /// Parses a verse specification string into an ordered, deduplicated list of verse numbers.
  /// Handles individual numbers ("1,4,5"), sub-ranges ("10-14", "1-2"), and space-tolerant formatting ("1, 2").
  static List<int> parseVerseNumbers(String verseSpec) {
    final segments = verseSpec.split(',');
    final List<int> expanded = [];

    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;

      final rangeMatch = RegExp(r'^(\d+)\s*[-–—]\s*(\d+)$').firstMatch(trimmed);
      if (rangeMatch != null) {
        final start = int.tryParse(rangeMatch.group(1)!);
        final end = int.tryParse(rangeMatch.group(2)!);
        if (start != null && end != null) {
          if (start <= end) {
            for (int i = start; i <= end; i++) {
              expanded.add(i);
            }
          } else {
            for (int i = start; i >= end; i--) {
              expanded.add(i);
            }
          }
        }
      } else {
        final single = int.tryParse(trimmed);
        if (single != null) {
          expanded.add(single);
        }
      }
    }

    // Deduplicate and preserve the specified order of verse numbers
    final Set<int> seen = {};
    final List<int> ordered = [];
    for (final v in expanded) {
      if (seen.add(v)) {
        ordered.add(v);
      }
    }
    return ordered;
  }

  // Common aliases and abbreviations mapped to canonical book names
  static final Map<String, String> _aliases = {
    'gen': 'Genesis',
    'ex': 'Exodus',
    'exo': 'Exodus',
    'exod': 'Exodus',
    'lev': 'Leviticus',
    'num': 'Numbers',
    'deut': 'Deuteronomy',
    'dt': 'Deuteronomy',
    'josh': 'Joshua',
    'judg': 'Judges',
    'psalm': 'Psalms',
    'ps': 'Psalms',
    'prov': 'Proverbs',
    'pr': 'Proverbs',
    'eccl': 'Ecclesiastes',
    'ecc': 'Ecclesiastes',
    'song': 'Song of Solomon',
    'songs': 'Song of Solomon',
    'isa': 'Isaiah',
    'jer': 'Jeremiah',
    'lam': 'Lamentations',
    'ezek': 'Ezekiel',
    'dan': 'Daniel',
    'hos': 'Hosea',
    'hab': 'Habakkuk',
    'zech': 'Zechariah',
    'mal': 'Malachi',
    'matt': 'Matthew',
    'mt': 'Matthew',
    'mk': 'Mark',
    'lk': 'Luke',
    'jn': 'John',
    'rom': 'Romans',
    '1cor': '1 Corinthians',
    '2cor': '2 Corinthians',
    'gal': 'Galatians',
    'eph': 'Ephesians',
    'phil': 'Philippians',
    'col': 'Colossians',
    '1thess': '1 Thessalonians',
    '2thess': '2 Thessalonians',
    '1tim': '1 Timothy',
    '2tim': '2 Timothy',
    'tit': 'Titus',
    'phlm': 'Philemon',
    'heb': 'Hebrews',
    'jas': 'James',
    '1pet': '1 Peter',
    '2pet': '2 Peter',
    '1jn': '1 John',
    '2jn': '2 John',
    '3jn': '3 John',
    'rev': 'Revelation',
  };

  /// Parses any freeform text and resolves all detected scripture citations
  /// into actual Verse objects using BibleService.
  static List<ParsedScriptureRef> parse(String text) {
    if (text.isEmpty) return [];

    final bible = BibleService.instance;
    final List<ParsedScriptureRef> results = [];
    final Set<String> processedKeys = {};

    final matches = _citationRegex.allMatches(text);

    for (final match in matches) {
      final rawBook = (match.group(1) ?? '').trim();
      final chapterStr = match.group(2) ?? '1';
      final rawVerseSpec = match.group(3) ?? '1';

      final chapter = int.tryParse(chapterStr) ?? 1;
      final verseNumbers = parseVerseNumbers(rawVerseSpec);
      if (verseNumbers.isEmpty) continue;

      final startVerse = verseNumbers.first;
      final endVerse = verseNumbers.length > 1 ? verseNumbers.last : null;

      final book = _resolveBook(rawBook, bible);
      if (book == null) continue;

      // Avoid exact duplicate references in same parse
      final dedupeKey = '${book.id}:$chapter:${verseNumbers.join(",")}';
      if (processedKeys.contains(dedupeKey)) continue;
      processedKeys.add(dedupeKey);

      final verses = bible.getSpecificVerses(
        book.name,
        chapter,
        verseNumbers,
      );

      results.add(
        ParsedScriptureRef(
          rawMatch: match.group(0) ?? '',
          book: book,
          chapter: chapter,
          verseNumbers: verseNumbers,
          startVerse: startVerse,
          endVerse: endVerse,
          verseSpec: rawVerseSpec.trim(),
          verses: verses,
        ),
      );
    }

    return results;
  }

  /// Resolves book name accounting for numbered prefixes and aliases
  static BookInfo? _resolveBook(String name, BibleService bible) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final lower = clean.toLowerCase();

    // Direct lookup
    var book = bible.findBookByName(clean);
    if (book != null) return book;

    // Check aliases
    final canonicalName =
        _aliases[lower] ?? _aliases[lower.replaceAll(' ', '')];
    if (canonicalName != null) {
      book = bible.findBookByName(canonicalName);
      if (book != null) return book;
    }

    // Numbered books handling (e.g. "1st Kings" -> "1 Kings", "1Kings" -> "1 Kings")
    final numberedMatch = RegExp(
      r'^([1-3])(?:st|nd|rd)?\s*([a-zA-Z]+)',
    ).firstMatch(lower);
    if (numberedMatch != null) {
      final numPrefix = numberedMatch.group(1);
      final rest = numberedMatch.group(2);
      final normalizedNumbered = '$numPrefix $rest';
      book = bible.findBookByName(normalizedNumbered);
      if (book != null) return book;

      if (_aliases.containsKey(rest)) {
        final aliasTarget = _aliases[rest]!;
        book = bible.findBookByName('$numPrefix $aliasTarget');
        if (book != null) return book;
      }
    }

    return null;
  }
}
