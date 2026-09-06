import '../models/verse.dart';
import '../models/book.dart';
import 'bible_service.dart';

/// Represents a successfully parsed and resolved Scripture reference
class ParsedScriptureRef {
  final String rawMatch;
  final BookInfo book;
  final int chapter;
  final int startVerse;
  final int? endVerse;
  final List<Verse> verses;

  const ParsedScriptureRef({
    required this.rawMatch,
    required this.book,
    required this.chapter,
    required this.startVerse,
    this.endVerse,
    required this.verses,
  });

  String get referenceLabel {
    if (endVerse != null && endVerse != startVerse) {
      return '${book.name} $chapter:$startVerse-$endVerse';
    }
    return '${book.name} $chapter:$startVerse';
  }
}

/// Multi-reference regex engine that extracts multiple Bible references and ranges
/// without stripping numbered book prefixes (e.g. 1 Kings, 2 Samuel, 1 Peter).
class ScriptureParser {
  // Regex supporting numbered prefixes (1-3), book names (including "Song of Solomon"),
  // chapter, verse, and optional end verse range.
  static final RegExp _citationRegex = RegExp(
    r'\b((?:[1-3]\s+)?[A-Za-z]+(?:\s+of\s+[A-Za-z]+)?)\s+(\d+)[:\.](\d+)(?:\s*[-–—]\s*(\d+))?',
    caseSensitive: false,
  );

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
      final startVerseStr = match.group(3) ?? '1';
      final endVerseStr = match.group(4);

      final chapter = int.tryParse(chapterStr) ?? 1;
      final startVerse = int.tryParse(startVerseStr) ?? 1;
      final endVerse = endVerseStr != null ? int.tryParse(endVerseStr) : null;

      final book = _resolveBook(rawBook, bible);
      if (book == null) continue;

      // Avoid exact duplicate references in same parse
      final dedupeKey = '${book.id}:$chapter:$startVerse:${endVerse ?? startVerse}';
      if (processedKeys.contains(dedupeKey)) continue;
      processedKeys.add(dedupeKey);

      final verses = bible.getVerseRange(book.id, chapter, startVerse, endVerse);

      results.add(
        ParsedScriptureRef(
          rawMatch: match.group(0) ?? '',
          book: book,
          chapter: chapter,
          startVerse: startVerse,
          endVerse: endVerse,
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
    final canonicalName = _aliases[lower] ?? _aliases[lower.replaceAll(' ', '')];
    if (canonicalName != null) {
      book = bible.findBookByName(canonicalName);
      if (book != null) return book;
    }

    // Numbered books handling (e.g. "1st Kings" -> "1 Kings", "1Kings" -> "1 Kings")
    final numberedMatch = RegExp(r'^([1-3])(?:st|nd|rd)?\s*([a-zA-Z]+)').firstMatch(lower);
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
