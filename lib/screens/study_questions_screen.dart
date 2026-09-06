import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/bible_service.dart';
import '../services/storage_service.dart';
import '../widgets/bible_navigator_dialog.dart';

/// Screen dedicated to structured chapter study questions and reflections
class StudyQuestionsScreen extends StatefulWidget {
  final int activeBookId;
  final int activeChapter;
  final void Function(int bookId, int chapter)? onNavigateToScripture;

  const StudyQuestionsScreen({
    super.key,
    required this.activeBookId,
    required this.activeChapter,
    this.onNavigateToScripture,
  });

  @override
  State<StudyQuestionsScreen> createState() => _StudyQuestionsScreenState();
}

class _StudyQuestionsScreenState extends State<StudyQuestionsScreen> {
  late int _selectedBookId;
  late int _selectedChapter;

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _selectedBookId = widget.activeBookId;
    _selectedChapter = widget.activeChapter;
  }

  @override
  void didUpdateWidget(covariant StudyQuestionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeBookId != widget.activeBookId ||
        oldWidget.activeChapter != widget.activeChapter) {
      _selectedBookId = widget.activeBookId;
      _selectedChapter = widget.activeChapter;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String key) {
    if (!_controllers.containsKey(key)) {
      final initial = StorageService.instance.getQuestionAnswer(key);
      _controllers[key] = TextEditingController(text: initial);
    }
    return _controllers[key]!;
  }

  Future<void> _saveAnswer(String key) async {
    final text = _getController(key).text;
    await StorageService.instance.saveQuestionAnswer(key, text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reflection answer saved!'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF1E1E1E),
        ),
      );
    }
  }

  void _openBookSelector() {
    BibleNavigatorDialog.show(
      context,
      currentBookId: _selectedBookId,
      currentChapter: _selectedChapter,
      onSelect: (BookInfo book, int chapter) {
        setState(() {
          _selectedBookId = book.id;
          _selectedChapter = chapter;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bible = BibleService.instance;
    final book = bible.getBook(_selectedBookId);
    final bookName = book?.name ?? 'Book';
    final isOT = book?.isOldTestament ?? true;

    // Study Questions based on Inductive Study Method & Testament Context
    final questions = [
      (
        id: 'observation',
        title: '1. Observation (What does it say?)',
        subtitle:
            'Identify key figures, repeated phrases, themes, commands, and chronological events occurring in $bookName $_selectedChapter.',
      ),
      (
        id: 'interpretation',
        title: '2. Interpretation (What does it mean?)',
        subtitle: isOT
            ? 'What is the covenantal message to Israel in this passage, and how does it foreshadow God\'s redemption in Christ?'
            : 'What theological truths did the original author communicate, and what is the gospel reality taught here?',
      ),
      (
        id: 'application',
        title: '3. Application (How do I live this out?)',
        subtitle:
            'What specific sin is convicted, promise is given to trust, or action is called for in your walk of faith today?',
      ),
      (
        id: 'cross_references',
        title: '4. Cross-References & Christ Connection',
        subtitle:
            'What related scriptures came to mind while studying $bookName $_selectedChapter, and how do they illuminate this text?',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.quiz_outlined, color: Color(0xFFFFC107), size: 24),
            SizedBox(width: 8),
            Text(
              'Questions for Study',
              style: TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book, color: Color(0xFFFFC107), size: 20),
            tooltip: 'Read this passage',
            onPressed: () {
              if (widget.onNavigateToScripture != null) {
                widget.onNavigateToScripture!(_selectedBookId, _selectedChapter);
              }
            },
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Current Study Passage Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFC107).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE STUDY FOCUS',
                        style: TextStyle(
                          color: const Color(0xFFFFC107).withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$bookName Chapter $_selectedChapter',
                        style: const TextStyle(
                          color: Color(0xFFE0E0E0),
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz, color: Color(0xFFFFC107), size: 18),
                  label: const Text(
                    'Change Chapter',
                    style: TextStyle(color: Color(0xFFFFC107), fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFC107), width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openBookSelector,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Guided Study Questions
          ...questions.map((q) {
            final key = '$_selectedBookId:$_selectedChapter:${q.id}';
            final controller = _getController(key);

            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    q.title,
                    style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Record your insights and answers here...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF262626),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF333333)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF333333)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16, color: Colors.black),
                      label: const Text(
                        'Save Answer',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _saveAnswer(key),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
