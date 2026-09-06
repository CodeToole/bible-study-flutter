import 'package:flutter/material.dart';
import '../models/verse.dart';
import '../services/bible_service.dart';

/// Modal dialog for live keyword search across all 31,102 verses
class ScriptureSearchDialog extends StatefulWidget {
  final ValueChanged<Verse> onVerseSelected;

  const ScriptureSearchDialog({
    super.key,
    required this.onVerseSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<Verse> onVerseSelected,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => ScriptureSearchDialog(onVerseSelected: onVerseSelected),
    );
  }

  @override
  State<ScriptureSearchDialog> createState() => _ScriptureSearchDialogState();
}

class _ScriptureSearchDialogState extends State<ScriptureSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  List<Verse> _results = [];
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _controller.text.trim();
    if (query == _currentQuery) return;

    setState(() {
      _currentQuery = query;
      if (query.isEmpty) {
        _results = [];
      } else {
        _results = BibleService.instance.searchVerses(query, limit: 120);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFFFC107).withValues(alpha: 0.3), width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF181818),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFFFFC107), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Scripture Keyword Search',
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

            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search words (e.g. grace, light, faith, covenant)...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFFFC107), size: 20),
                  suffixIcon: _currentQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () => _controller.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Results count status badge
            if (_currentQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _results.isNotEmpty
                        ? 'Found ${_results.length}${_results.length >= 120 ? "+" : ""} matches for "$_currentQuery"'
                        : 'No matches found for "$_currentQuery"',
                    style: TextStyle(
                      color: _results.isNotEmpty
                          ? const Color(0xFFFFC107).withValues(alpha: 0.9)
                          : Colors.white54,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            const Divider(color: Color(0xFF333333), height: 16),

            // Search Results List
            Expanded(
              child: _buildResultsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    if (_currentQuery.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.manage_search, size: 56, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              const Text(
                'Search the entire King James Bible',
                style: TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Type any keyword or phrase to jump directly to that chapter and verse.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 52, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              Text(
                'No verses found matching "$_currentQuery"',
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try checking for alternative spellings or common King James terms.',
                style: TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFF282828), height: 8),
      itemBuilder: (context, index) {
        final verse = _results[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).pop();
              widget.onVerseSelected(verse);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reference Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFFFC107).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      verse.reference,
                      style: const TextStyle(
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Scripture snippet with query term highlighted
                  RichText(
                    text: TextSpan(
                      children: _buildHighlightedSnippet(verse.plainText, _currentQuery),
                      style: const TextStyle(
                        color: Color(0xFFD0D0D0),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Highlights all occurrences of the query term inside the verse text
  List<InlineSpan> _buildHighlightedSnippet(String text, String query) {
    final List<InlineSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      final matchText = text.substring(index, index + query.length);
      spans.add(
        TextSpan(
          text: matchText,
          style: const TextStyle(
            color: Color(0xFFFFC107),
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0x33FFC107),
          ),
        ),
      );

      start = index + query.length;
    }

    return spans;
  }
}
