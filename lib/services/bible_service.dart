import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/verse.dart';
import '../models/book.dart';

/// Internal data transfer container returned by the background isolate
class _BibleParsedData {
  final List<Verse> verses;
  final List<BookInfo> books;

  _BibleParsedData({required this.verses, required this.books});
}

/// Top-level parsing function executed in background isolate via compute()
_BibleParsedData _parseKjvJson(String jsonString) {
  final dynamic decoded = jsonDecode(jsonString);
  final List<dynamic> rawVerses = decoded['verses'] as List<dynamic>? ?? [];

  final List<Verse> verses = <Verse>[];
  final Map<int, String> bookNames = <int, String>{};
  final Map<int, Set<int>> bookChapters = <int, Set<int>>{};

  for (final raw in rawVerses) {
    if (raw is Map<String, dynamic>) {
      final verse = Verse.fromJson(raw);
      verses.add(verse);

      bookNames[verse.book] = verse.bookName;
      bookChapters.putIfAbsent(verse.book, () => <int>{}).add(verse.chapter);
    }
  }

  // Build sorted BookInfo list (1 to 66)
  final List<BookInfo> books = <BookInfo>[];
  final sortedBookIds = bookNames.keys.toList()..sort();
  for (final id in sortedBookIds) {
    final name = bookNames[id] ?? 'Book $id';
    final chapters = bookChapters[id]?.length ?? 1;
    books.add(BookInfo(
      id: id,
      name: name,
      chapterCount: chapters,
    ));
  }

  return _BibleParsedData(verses: verses, books: books);
}

/// Singleton service providing fast, indexed Bible text lookups and navigation
class BibleService {
  static final BibleService instance = BibleService._internal();
  BibleService._internal();

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<Verse> _allVerses = [];
  List<BookInfo> _books = [];

  // Indexed lookups for O(1) retrieval
  final Map<String, List<Verse>> _chapterVersesMap = {};
  final Map<int, BookInfo> _bookIdMap = {};
  final Map<String, BookInfo> _bookNameMap = {};

  /// Loads assets/kjv.json asynchronously off the UI thread via compute()
  Future<void> load() async {
    if (_isLoaded) return;

    final jsonString = await rootBundle.loadString('assets/kjv.json');
    final parsedData = await compute(_parseKjvJson, jsonString);

    _allVerses = parsedData.verses;
    _books = parsedData.books;

    _chapterVersesMap.clear();
    _bookIdMap.clear();
    _bookNameMap.clear();

    for (final book in _books) {
      _bookIdMap[book.id] = book;
      _bookNameMap[book.name.toLowerCase().trim()] = book;
    }

    for (final verse in _allVerses) {
      final key = '${verse.book}:${verse.chapter}';
      _chapterVersesMap.putIfAbsent(key, () => <Verse>[]).add(verse);
    }

    _isLoaded = true;
  }

  /// All 66 canonical books
  List<BookInfo> get books => List.unmodifiable(_books);

  /// Old Testament books (Genesis 1 to Malachi 39)
  List<BookInfo> get oldTestamentBooks =>
      _books.where((b) => b.isOldTestament).toList();

  /// New Testament books (Matthew 40 to Revelation 66)
  List<BookInfo> get newTestamentBooks =>
      _books.where((b) => b.isNewTestament).toList();

  /// Retrieve book by canonical ID (1-66)
  BookInfo? getBook(int bookId) => _bookIdMap[bookId];

  /// Find book by name (case-insensitive with normalized matching)
  BookInfo? findBookByName(String name) {
    final query = name.toLowerCase().trim();
    if (_bookNameMap.containsKey(query)) {
      return _bookNameMap[query];
    }
    // Partial or alias lookup
    for (final book in _books) {
      final bookLower = book.name.toLowerCase();
      if (bookLower == query || bookLower.startsWith(query)) {
        return book;
      }
    }
    return null;
  }

  /// Get all verses for a given book and chapter
  List<Verse> getVerses(int bookId, int chapter) {
    final key = '$bookId:$chapter';
    return _chapterVersesMap[key] ?? const [];
  }

  /// Get a specific range of verses
  List<Verse> getVerseRange(int bookId, int chapter, int startVerse, int? endVerse) {
    final verses = getVerses(bookId, chapter);
    if (verses.isEmpty) return const [];

    final targetEnd = endVerse ?? startVerse;
    return verses.where((v) => v.verse >= startVerse && v.verse <= targetEnd).toList();
  }

  /// Lookup a verse by reference coordinates
  Verse? getVerse(int bookId, int chapter, int verseNum) {
    final verses = getVerses(bookId, chapter);
    for (final v in verses) {
      if (v.verse == verseNum) return v;
    }
    return null;
  }

  /// Total chapter count for a book
  int getChapterCount(int bookId) {
    return _bookIdMap[bookId]?.chapterCount ?? 1;
  }

  /// Next chapter coordinate (moves to next book if at last chapter, stops at Rev 22)
  ({int book, int chapter}) nextChapter(int currentBook, int currentChapter) {
    final maxChapters = getChapterCount(currentBook);
    if (currentChapter < maxChapters) {
      return (book: currentBook, chapter: currentChapter + 1);
    } else if (currentBook < 66) {
      return (book: currentBook + 1, chapter: 1);
    }
    return (book: currentBook, chapter: currentChapter);
  }

  /// Previous chapter coordinate (moves to previous book's last chapter if at chapter 1, stops at Gen 1)
  ({int book, int chapter}) previousChapter(int currentBook, int currentChapter) {
    if (currentChapter > 1) {
      return (book: currentBook, chapter: currentChapter - 1);
    } else if (currentBook > 1) {
      final prevBook = currentBook - 1;
      final prevLastChapter = getChapterCount(prevBook);
      return (book: prevBook, chapter: prevLastChapter);
    }
    return (book: currentBook, chapter: currentChapter);
  }

  /// Performs a case-insensitive keyword search across all 31,102 verses checking
  /// if verse.plainText (cleaned of delimiters) contains the query.
  List<Verse> searchVerses(String query, {int limit = 100}) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return const [];

    final List<Verse> matches = [];
    for (final verse in _allVerses) {
      if (verse.plainText.toLowerCase().contains(cleanQuery)) {
        matches.add(verse);
        if (matches.length >= limit) {
          break;
        }
      }
    }
    return matches;
  }
}
