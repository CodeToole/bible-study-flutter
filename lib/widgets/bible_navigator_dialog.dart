import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/bible_service.dart';

/// Modal dialog with accordion canonical navigation for Old & New Testaments
class BibleNavigatorDialog extends StatefulWidget {
  final int currentBookId;
  final int currentChapter;
  final void Function(BookInfo book, int chapter) onSelect;

  const BibleNavigatorDialog({
    super.key,
    required this.currentBookId,
    required this.currentChapter,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required int currentBookId,
    required int currentChapter,
    required void Function(BookInfo book, int chapter) onSelect,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => BibleNavigatorDialog(
        currentBookId: currentBookId,
        currentChapter: currentChapter,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<BibleNavigatorDialog> createState() => _BibleNavigatorDialogState();
}

class _BibleNavigatorDialogState extends State<BibleNavigatorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  int? _expandedBookId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Default tab based on current book: OT if <= 39, NT if >= 40
    final initialTab = widget.currentBookId >= 40 ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialTab);
    _expandedBookId = widget.currentBookId;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bible = BibleService.instance;
    final otBooks = bible.oldTestamentBooks;
    final ntBooks = bible.newTestamentBooks;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFFFC107).withValues(alpha: 0.3), width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF181818),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories, color: Color(0xFFFFC107), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Canonical Scripture Navigator',
                      style: TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search Filter
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search books (e.g. Genesis, 1 Kings, John)...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFFFC107), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Tabs for Old & New Testament
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFFC107),
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFFFFC107),
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                tabs: const [
                  Tab(text: 'Old Testament (1–39)'),
                  Tab(text: 'New Testament (40–66)'),
                ],
              ),
            ),

            // Accordion Book & Chapter Lists
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBookList(otBooks),
                  _buildBookList(ntBooks),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList(List<BookInfo> books) {
    final filtered = _searchQuery.isEmpty
        ? books
        : books.where((b) => b.name.toLowerCase().contains(_searchQuery)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No books matching "$_searchQuery"',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final book = filtered[index];
        final isExpanded = _expandedBookId == book.id;
        final isCurrentBook = widget.currentBookId == book.id;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isExpanded ? const Color(0xFF252525) : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrentBook
                  ? const Color(0xFFFFC107).withValues(alpha: 0.5)
                  : const Color(0xFF333333),
              width: isCurrentBook ? 1.2 : 0.8,
            ),
          ),
          child: Column(
            children: [
              // Book Accordion Header Tile
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedBookId = null;
                    } else {
                      _expandedBookId = book.id;
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Book Index Badge (1-66)
                      Container(
                        width: 32,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrentBook
                              ? const Color(0xFFFFC107)
                              : const Color(0xFF323232),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${book.id}',
                          style: TextStyle(
                            color: isCurrentBook ? Colors.black : const Color(0xFFE0E0E0),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Book Title
                      Expanded(
                        child: Text(
                          book.name,
                          style: TextStyle(
                            color: isCurrentBook
                                ? const Color(0xFFFFC107)
                                : const Color(0xFFE0E0E0),
                            fontSize: 15,
                            fontWeight:
                                isCurrentBook ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      // Chapter count label
                      Text(
                        '${book.chapterCount} chs',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Animated Chevron
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: isExpanded ? const Color(0xFFFFC107) : Colors.white54,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Inline Grid of Chapters when expanded
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Color(0xFF383838), height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(book.chapterCount, (cIndex) {
                          final chapterNum = cIndex + 1;
                          final isSelected =
                              isCurrentBook && widget.currentChapter == chapterNum;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onSelect(book, chapterNum);
                              },
                              child: Container(
                                width: 44,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFC107)
                                      : const Color(0xFF2E2E2E),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFFC107)
                                        : const Color(0xFF404040),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$chapterNum',
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : const Color(0xFFE0E0E0),
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
