import 'package:flutter/material.dart';
import '../models/verse.dart';
import '../models/book.dart';
import '../services/bible_service.dart';
import '../services/storage_service.dart';
import '../widgets/verse_text.dart';
import '../widgets/bible_navigator_dialog.dart';
import '../widgets/highlight_bottom_sheet.dart';
import '../widgets/scripture_search_dialog.dart';

/// Main scripture reading interface with top jump controls, smooth ListView.builder,
/// and multi-verse highlighting.
class ReaderScreen extends StatefulWidget {
  final int initialBookId;
  final int initialChapter;
  final ValueChanged<List<Verse>>? onSendToNotes;

  const ReaderScreen({
    super.key,
    this.initialBookId = 1, // Genesis by default
    this.initialChapter = 1,
    this.onSendToNotes,
  });

  @override
  State<ReaderScreen> createState() => ReaderScreenState();
}

class ReaderScreenState extends State<ReaderScreen> {
  late int _currentBookId;
  late int _currentChapter;
  final ScrollController _scrollController = ScrollController();

  // Multi-verse selection state
  final Set<int> _selectedVerseNumbers = {};

  @override
  void initState() {
    super.initState();
    _currentBookId = widget.initialBookId;
    _currentChapter = widget.initialChapter;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void jumpTo(int bookId, int chapter) {
    setState(() {
      _currentBookId = bookId;
      _currentChapter = chapter;
      _selectedVerseNumbers.clear();
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void jumpToVerse(Verse verse) {
    setState(() {
      _currentBookId = verse.book;
      _currentChapter = verse.chapter;
      _selectedVerseNumbers.clear();
      _selectedVerseNumbers.add(verse.verse);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final verses = BibleService.instance.getVerses(verse.book, verse.chapter);
        final idx = verses.indexWhere((v) => v.verse == verse.verse);
        if (idx >= 0) {
          final target = (idx * 65.0).clamp(0.0, _scrollController.position.maxScrollExtent);
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  void _openSearchDialog() {
    ScriptureSearchDialog.show(
      context,
      onVerseSelected: (selectedVerse) {
        jumpToVerse(selectedVerse);
      },
    );
  }

  void _nextChapter() {
    final next = BibleService.instance.nextChapter(_currentBookId, _currentChapter);
    jumpTo(next.book, next.chapter);
  }

  void _previousChapter() {
    final prev = BibleService.instance.previousChapter(_currentBookId, _currentChapter);
    jumpTo(prev.book, prev.chapter);
  }

  void _openNavigatorDialog() {
    BibleNavigatorDialog.show(
      context,
      currentBookId: _currentBookId,
      currentChapter: _currentChapter,
      onSelect: (BookInfo book, int chapter) {
        jumpTo(book.id, chapter);
      },
    );
  }

  void _toggleVerseSelection(int verseNum) {
    setState(() {
      if (_selectedVerseNumbers.contains(verseNum)) {
        _selectedVerseNumbers.remove(verseNum);
      } else {
        _selectedVerseNumbers.add(verseNum);
      }
    });
  }

  Future<void> _applyHighlightColor(Color color) async {
    final list = _selectedVerseNumbers.map((v) => (
      book: _currentBookId,
      chapter: _currentChapter,
      verse: v,
    )).toList();

    await StorageService.instance.setHighlightsBatch(list, color);
    setState(() {
      _selectedVerseNumbers.clear();
    });
  }

  Future<void> _clearSelectedHighlights() async {
    final list = _selectedVerseNumbers.map((v) => (
      book: _currentBookId,
      chapter: _currentChapter,
      verse: v,
    )).toList();

    await StorageService.instance.removeHighlightsBatch(list);
    setState(() {
      _selectedVerseNumbers.clear();
    });
  }

  void _handleSendToNotes(List<Verse> allVerses) {
    final selected = allVerses
        .where((v) => _selectedVerseNumbers.contains(v.verse))
        .toList();
    if (widget.onSendToNotes != null && selected.isNotEmpty) {
      widget.onSendToNotes!(selected);
      setState(() {
        _selectedVerseNumbers.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bible = BibleService.instance;
    final currentBook = bible.getBook(_currentBookId);
    final bookTitle = currentBook?.name ?? 'Scripture';
    final verses = bible.getVerses(_currentBookId, _currentChapter);

    final selectedVersesList = verses
        .where((v) => _selectedVerseNumbers.contains(v.verse))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFFFC107).withValues(alpha: 0.2),
            height: 1,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left jump control <
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFFFFC107), size: 28),
              tooltip: 'Previous chapter',
              onPressed: (_currentBookId == 1 && _currentChapter == 1) ? null : _previousChapter,
            ),

            // Center interactive book & chapter title
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _openNavigatorDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$bookTitle $_currentChapter',
                      style: const TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFFFFC107), size: 22),
                  ],
                ),
              ),
            ),

            // Right jump control >
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFFFFC107), size: 28),
              tooltip: 'Next chapter',
              onPressed: (_currentBookId == 66 && _currentChapter == 22) ? null : _nextChapter,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFFFFC107), size: 24),
            tooltip: 'Search scripture',
            onPressed: _openSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_rounded, color: Color(0xFFFFC107), size: 22),
            tooltip: 'Browse books',
            onPressed: _openNavigatorDialog,
          ),
        ],
      ),

      // Scripture Reader List
      body: Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              selectedVersesList.isNotEmpty ? 140 : 40,
            ),
            itemCount: verses.length + 1, // +1 for chapter header
            itemBuilder: (context, index) {
              if (index == 0) {
                // Header badge
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18, top: 4),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFC107).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${currentBook?.testamentName ?? ""} • ${verses.length} verses',
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$bookTitle $_currentChapter',
                        style: const TextStyle(
                          color: Color(0xFFE0E0E0),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 48,
                        height: 2,
                        color: const Color(0xFFFFC107).withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                );
              }

              final verse = verses[index - 1];
              final isSelected = _selectedVerseNumbers.contains(verse.verse);
              final highlight = StorageService.instance.getHighlight(
                _currentBookId,
                _currentChapter,
                verse.verse,
              );

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: VerseTextWidget(
                  verse: verse,
                  isSelected: isSelected,
                  highlightColor: highlight,
                  onTap: () => _toggleVerseSelection(verse.verse),
                  onLongPress: () => _toggleVerseSelection(verse.verse),
                ),
              );
            },
          ),

          // Bottom Action Sheet for Highlights & Copying
          if (selectedVersesList.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: HighlightBottomSheet(
                selectedVerses: selectedVersesList,
                onApplyColor: _applyHighlightColor,
                onClearHighlight: _clearSelectedHighlights,
                onSendToNotes: () => _handleSendToNotes(verses),
                onDeselectAll: () {
                  setState(() {
                    _selectedVerseNumbers.clear();
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}
