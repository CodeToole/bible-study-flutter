import 'package:flutter/material.dart';
import '../models/verse.dart';
import '../models/study_note.dart';
import '../models/lesson_plan.dart';
import '../services/storage_service.dart';
import '../services/bible_service.dart';
import '../services/scripture_parser.dart';
import '../services/lesson_parser.dart';
import '../services/export_service.dart';
import '../widgets/verse_text.dart';
import 'podium_screen.dart';

/// Study Notes screen featuring decoupled Parse & Save workflows,
/// instant sharing, full PDF export, and full-text scripture viewing for saved notes.
class StudyNotesScreen extends StatefulWidget {
  final List<Verse>? preloadedVerses;
  final void Function(int bookId, int chapter)? onNavigateToScripture;

  const StudyNotesScreen({
    super.key,
    this.preloadedVerses,
    this.onNavigateToScripture,
  });

  @override
  State<StudyNotesScreen> createState() => StudyNotesScreenState();
}

class StudyNotesScreenState extends State<StudyNotesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // Parsed references preview state
  List<ParsedScriptureRef> _parsedReferences = [];
  bool _hasParsed = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.preloadedVerses != null && widget.preloadedVerses!.isNotEmpty) {
      _applyPreloadedVerses(widget.preloadedVerses!);
    }
  }

  void _applyPreloadedVerses(List<Verse> verses) {
    final first = verses.first;
    final sorted = List<Verse>.from(verses)..sort((a, b) => a.verse.compareTo(b.verse));
    final startVerse = sorted.first.verse;
    final endVerse = sorted.last.verse;
    final ref = startVerse == endVerse
        ? '${first.bookName} ${first.chapter}:$startVerse'
        : '${first.bookName} ${first.chapter}:$startVerse-$endVerse';

    _titleController.text = 'Study on $ref';
    _contentController.text = 'Reflection on $ref:\n\n';
    _parseScriptures();
  }

  void publicInsertVerses(List<Verse> verses) {
    _applyPreloadedVerses(verses);
    _tabController.animateTo(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _parseScriptures() {
    final text = _contentController.text;
    final parsed = ScriptureParser.parse(text);

    setState(() {
      _parsedReferences = parsed;
      _hasParsed = true;
    });

    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No scripture citations detected in text. Try e.g. "EXODUS 20:1-17" or "1 KINGS 8:27-30".'),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
    }
  }

  String _getActiveTitle() {
    final t = _titleController.text.trim();
    if (t.isNotEmpty) return t;
    if (_parsedReferences.isNotEmpty) {
      return 'Lesson: ${_parsedReferences.map((p) => p.referenceLabel).join(", ")}';
    }
    return 'Bible Study Notes';
  }

  void _shareCurrentLesson() {
    final title = _getActiveTitle();
    final commentary = _contentController.text.trim();
    final text = ExportService.formatPlainTextLesson(
      title: title,
      commentary: commentary,
      sections: _parsedReferences,
    );
    ExportService.shareText(context, title: title, text: text);
  }

  Future<void> _exportCurrentPdf() async {
    final title = _getActiveTitle();
    final commentary = _contentController.text.trim();
    await ExportService.generateAndSharePdf(
      context: context,
      title: title,
      noteText: commentary,
      sections: _parsedReferences,
    );
  }

  void _copyCurrentText() {
    final title = _getActiveTitle();
    final commentary = _contentController.text.trim();
    final text = ExportService.formatPlainTextLesson(
      title: title,
      commentary: commentary,
      sections: _parsedReferences,
    );
    ExportService.copyToClipboard(context, text);
  }

  LessonPlan _getCurrentLessonPlan() {
    final title = _getActiveTitle();
    final text = _contentController.text.trim();
    final parsed = LessonParser.parseLessonOutline(text, BibleService.instance);
    if (parsed.title == 'Untitled Lesson' || parsed.title == 'Bible Study Lesson') {
      return LessonPlan(
        id: parsed.id,
        title: title,
        teacher: parsed.teacher,
        date: parsed.date,
        prayerCitation: parsed.prayerCitation,
        prayerVerses: parsed.prayerVerses,
        introduction: parsed.introduction,
        conclusion: parsed.conclusion,
        sections: parsed.sections,
      );
    }
    return parsed;
  }

  void _launchPodiumModeCurrent() {
    final lesson = _getCurrentLessonPlan();
    if (lesson.totalPointsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please parse at least one scripture reference first to launch Podium Mode.'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PodiumScreen(
          lessonPlan: lesson,
          onLessonPlanUpdated: (updatedPlan) {
            setState(() {
              _contentController.text = LessonParser.serializeToMarkdown(updatedPlan);
              _parseScriptures();
            });
          },
        ),
      ),
    );
  }

  Future<void> _exportSyllabusPdfCurrent() async {
    final lesson = _getCurrentLessonPlan();
    await ExportService.exportLessonSyllabusPdf(
      context: context,
      lesson: lesson,
    );
  }

  void _insertLessonTemplate() {
    const template = '''Title: The Two Covenants: Law, Sacrifice, and Grace
Teacher: Brother Cornelius
Date: October 14, 2026
Prayer: Psalms 100:1-5
Intro: Understanding the transition from the Old Covenant under animal sacrifice to the New Covenant established by the blood of Jesus Christ.

# THE OLD COVENANT & ANIMAL SACRIFICE
1. EXODUS 24:1-8
Sanctify = to set apart
- The first covenant was confirmed and dedicated with the blood of oxen.
- Moses sprinkled the altar, the book, and the people.

2. HEBREWS 9:18-22
Remission = forgiveness or release from penalty
- Neither the first testament was dedicated without blood.
- Without shedding of blood is no remission.

# THE NEW COVENANT & LAW WRITTEN IN THE HEART
3. JEREMIAH 31:31-34
Heart = Mind
- The Lord promised a new covenant with the House of Israel and Judah.
- The law was not abolished, but written in inward parts and hearts.

4. HEBREWS 8:6-10
Mediator = one who reconciles two parties
- Christ is the mediator of a better covenant with better promises.
- In their mind will I put my laws, and write them in their hearts.

Conclusion: The law of God remains eternal; the animal sacrifices pointed forward to Jesus Christ, who offered Himself once for all.''';

    setState(() {
      _titleController.text = 'The Two Covenants: Law, Sacrifice, and Grace';
      _contentController.text = template;
    });
    _parseScriptures();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expository lesson template inserted and parsed!'),
        backgroundColor: Color(0xFF1E1E1E),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveCurrentNote() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some note content or commentary before saving.'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Auto-parse if not done yet
    final parsed = ScriptureParser.parse(content);
    final refLabels = parsed.map((p) => p.referenceLabel).toList();

    var title = _titleController.text.trim();
    if (title.isEmpty) {
      if (refLabels.isNotEmpty) {
        title = 'Notes: ${refLabels.join(", ")}';
      } else {
        title = 'Study Note - ${DateTime.now().month}/${DateTime.now().day}';
      }
    }

    final note = StudyNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      parsedReferences: refLabels,
      createdAt: DateTime.now(),
    );

    await StorageService.instance.saveNote(note);

    setState(() {
      _isSaving = false;
      _titleController.clear();
      _contentController.clear();
      _parsedReferences.clear();
      _hasParsed = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note saved successfully!'),
          backgroundColor: const Color(0xFF1E1E1E),
          action: SnackBarAction(
            label: 'VIEW NOTES',
            textColor: const Color(0xFFFFC107),
            onPressed: () {
              _tabController.animateTo(1);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFFFFC107), size: 24),
            SizedBox(width: 8),
            Text(
              'Study Notes & Commentary',
              style: TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFC107),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFC107),
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            const Tab(text: 'Compose & Parse'),
            Tab(text: 'Saved Notes (${StorageService.instance.notes.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildComposerTab(),
          _buildSavedNotesTab(),
        ],
      ),
    );
  }

  // --- Compose & Parse Tab ---
  Widget _buildComposerTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Action: Insert Lesson Template
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LESSON COMPOSER',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.auto_stories, color: Color(0xFFFFC107), size: 16),
                label: const Text(
                  'Insert Lesson Template',
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
                  ),
                ),
                onPressed: _insertLessonTemplate,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title Input
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Note Title (e.g. Solomon\'s Prayer or Ten Commandments)...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              prefixIcon: const Icon(Icons.title, color: Color(0xFFFFC107), size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Content Input
          TextField(
            controller: _contentController,
            maxLines: 7,
            style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 15, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Type your study notes or commentary here...\nInclude citations like:\n- EXODUS 20:1-17\n- 1 KINGS 8:27-30\n- John 3:16\n- 1 John 1:9',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13.5),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Decoupled Actions: Parse Scriptures vs Save Note
          Row(
            children: [
              // Button 1: Parse Scriptures
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.travel_explore, color: Color(0xFFFFC107), size: 20),
                  label: const Text(
                    'Parse Scriptures',
                    style: TextStyle(
                      color: Color(0xFFFFC107),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFC107), width: 1.2),
                    backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _parseScriptures,
                ),
              ),
              const SizedBox(width: 12),

              // Button 2: Save Note
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.bookmark_add, color: Colors.black, size: 20),
                  label: const Text(
                    'Save Note',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _saveCurrentNote,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Parsed References Preview Section
          if (_hasParsed) ...[
            // Header Row
            Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFFFFC107), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Parsed Scripture Previews (${_parsedReferences.length})',
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action bar for immediate export: Podium Mode, Syllabus PDF, Share, Standard PDF, Copy
            if (_parsedReferences.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.co_present, color: Colors.black, size: 18),
                      label: const Text(
                        'PODIUM MODE',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _launchPodiumModeCurrent,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.menu_book, color: Color(0xFFFFC107), size: 17),
                      label: const Text(
                        'Syllabus PDF',
                        style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFFC107), width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _exportSyllabusPdfCurrent,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.share, color: Color(0xFFFFC107), size: 17),
                      label: const Text(
                        'Share All',
                        style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: _shareCurrentLesson,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFFFC107), size: 17),
                      label: const Text(
                        'PDF',
                        style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: _exportCurrentPdf,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, color: Color(0xFFFFC107), size: 17),
                      label: const Text(
                        'Copy',
                        style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: _copyCurrentText,
                    ),
                  ],
                ),
              ),

            if (_parsedReferences.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'No valid Scripture citations were found. Check spelling or try standard references like "Exodus 20:1-17" or "1 Kings 8:27-30".',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              )
            else
              ...List.generate(_parsedReferences.length, (index) {
                final ref = _parsedReferences[index];
                return _buildParsedRefCard(ref);
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildParsedRefCard(ParsedScriptureRef ref) {
    final lessonPlan = _getCurrentLessonPlan();
    final flatList = lessonPlan.allPointsFlat;
    final flatMatch = flatList.cast<FlatLessonPoint?>().firstWhere(
          (p) => p?.point.rawCitation.toLowerCase().trim() == ref.referenceLabel.toLowerCase().trim(),
          orElse: () => null,
        );
    final point = flatMatch?.point;
    final hasDefs = point != null && point.definitions.isNotEmpty;
    final hasNotes = point != null && point.teacherNotes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFC107).withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header with Badge, Edit Notes Button and Jump to Reader Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ref.referenceLabel,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${ref.verses.length} verses',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                // Inline Edit Notes Button
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.edit_note, color: Color(0xFFFFC107), size: 16),
                  label: Text(
                    hasNotes || hasDefs ? 'Edit Notes' : '+ Add Notes',
                    style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _editNotesForPoint(ref, flatMatch),
                ),
                if (widget.onNavigateToScripture != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.open_in_new, color: Color(0xFFFFC107), size: 16),
                    label: const Text(
                      'Read',
                      style: TextStyle(color: Color(0xFFFFC107), fontSize: 12),
                    ),
                    onPressed: () {
                      widget.onNavigateToScripture!(ref.book.id, ref.chapter);
                    },
                  ),
              ],
            ),
          ),

          // Teacher Notes / Talking Points & Definitions Banner if present
          if (hasDefs || hasNotes) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF181818),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasDefs) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: point.definitions.entries.map((e) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.5)),
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${e.key} = ',
                                  style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                TextSpan(
                                  text: e.value,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (hasNotes)
                    ...point.teacherNotes.map((note) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 5, right: 6),
                              child: Icon(Icons.circle, color: Color(0xFFFFC107), size: 6),
                            ),
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13.5, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
          ],

          // Verse Content with Red-Letter Tokenization
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ref.verses.map((verse) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: VerseTextWidget(
                    verse: verse,
                    fontSize: 14.5,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNotesForPoint(ParsedScriptureRef ref, FlatLessonPoint? flatMatch) async {
    final existingNotes = flatMatch?.point.teacherNotes ?? <String>[];
    final existingDefs = flatMatch?.point.definitions ?? <String, String>{};

    final List<TextEditingController> noteControllers =
        existingNotes.map((n) => TextEditingController(text: n)).toList();
    final List<MapEntry<TextEditingController, TextEditingController>> defControllers = existingDefs.entries
        .map((e) => MapEntry(TextEditingController(text: e.key), TextEditingController(text: e.value)))
        .toList();

    final newNoteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF2E2E2E)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note, color: Color(0xFFFFC107), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Teacher Notes: ${ref.referenceLabel}',
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF2E2E2E)),
                      const SizedBox(height: 8),
                      const Text(
                        'TALKING POINTS / COMMENTARY',
                        style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(noteControllers.length, (idx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.circle, size: 7, color: Color(0xFFFFC107)),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: noteControllers[idx],
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF252525),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setSheetState(() {
                                    noteControllers.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newNoteController,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                              decoration: const InputDecoration(
                                hintText: 'Add a talking point...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                                filled: true,
                                fillColor: Color(0xFF252525),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107)),
                            onPressed: () {
                              final text = newNoteController.text.trim();
                              if (text.isNotEmpty) {
                                setSheetState(() {
                                  noteControllers.add(TextEditingController(text: text));
                                  newNoteController.clear();
                                });
                              }
                            },
                            child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'VOCABULARY DEFINITIONS (Word = Meaning)',
                        style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(defControllers.length, (dIdx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: defControllers[dIdx].key,
                                  style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Term',
                                    filled: true,
                                    fillColor: const Color(0xFF252525),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('=', style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: defControllers[dIdx].value,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Definition',
                                    filled: true,
                                    fillColor: const Color(0xFF252525),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setSheetState(() {
                                    defControllers.removeAt(dIdx);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.add, color: Color(0xFFFFC107), size: 16),
                        label: const Text('Add Vocabulary Term', style: TextStyle(color: Color(0xFFFFC107))),
                        onPressed: () {
                          setSheetState(() {
                            defControllers.add(MapEntry(TextEditingController(), TextEditingController()));
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final updatedNotes = noteControllers
                              .map((c) => c.text.trim())
                              .where((t) => t.isNotEmpty)
                              .toList();
                          final Map<String, String> updatedDefs = {};
                          for (final d in defControllers) {
                            final k = d.key.text.trim();
                            final v = d.value.text.trim();
                            if (k.isNotEmpty && v.isNotEmpty) {
                              updatedDefs[k] = v;
                            }
                          }

                          Navigator.of(ctx).pop();
                          _applyPointEditsToComposer(ref, updatedNotes, updatedDefs, flatMatch);
                        },
                        child: const Text('SAVE NOTES & SYNC', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    for (final c in noteControllers) {
      c.dispose();
    }
    for (final e in defControllers) {
      e.key.dispose();
      e.value.dispose();
    }
    newNoteController.dispose();
  }

  void _applyPointEditsToComposer(
    ParsedScriptureRef ref,
    List<String> updatedNotes,
    Map<String, String> updatedDefs,
    FlatLessonPoint? flatMatch,
  ) {
    final currentPlan = _getCurrentLessonPlan();
    final List<LessonSection> newSections = [];
    bool foundAndUpdated = false;

    for (final section in currentPlan.sections) {
      final List<LessonPoint> newPoints = [];
      for (final point in section.points) {
        if (point.rawCitation.toLowerCase().trim() == ref.referenceLabel.toLowerCase().trim()) {
          newPoints.add(
            point.copyWith(
              teacherNotes: updatedNotes,
              definitions: updatedDefs,
            ),
          );
          foundAndUpdated = true;
        } else {
          newPoints.add(point);
        }
      }
      newSections.add(LessonSection(heading: section.heading, points: newPoints));
    }

    if (!foundAndUpdated) {
      final newPoint = LessonPoint(
        order: currentPlan.totalPointsCount + 1,
        rawCitation: ref.referenceLabel,
        verses: ref.verses,
        teacherNotes: updatedNotes,
        definitions: updatedDefs,
      );
      if (newSections.isEmpty) {
        newSections.add(LessonSection(points: [newPoint]));
      } else {
        final lastSec = newSections.removeLast();
        newSections.add(LessonSection(heading: lastSec.heading, points: [...lastSec.points, newPoint]));
      }
    }

    final updatedPlan = LessonPlan(
      id: currentPlan.id,
      title: currentPlan.title,
      teacher: currentPlan.teacher,
      date: currentPlan.date,
      prayerCitation: currentPlan.prayerCitation,
      prayerVerses: currentPlan.prayerVerses,
      introduction: currentPlan.introduction,
      conclusion: currentPlan.conclusion,
      sections: newSections,
    );

    setState(() {
      _contentController.text = LessonParser.serializeToMarkdown(updatedPlan);
      _parseScriptures();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notes updated & synced to composer!'),
        backgroundColor: Color(0xFF1E1E1E),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // --- Saved Notes Tab ---
  Widget _buildSavedNotesTab() {
    final notes = StorageService.instance.notes;

    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notes, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            const Text(
              'No Saved Study Notes Yet',
              style: TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Compose notes and parse scriptures in the first tab to save them here.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        // Resolve full scripture passages for this saved note
        final resolvedPassages = ScriptureParser.parse(
          '${note.content}\n${note.parsedReferences.join("\n")}',
        );
        final lessonPlan = LessonParser.parseLessonOutline(note.content, BibleService.instance);
        final bool isLessonPlan = lessonPlan.totalPointsCount > 0;

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2E2E2E)),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              note.title,
              style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLessonPlan)
                  IconButton(
                    icon: const Icon(Icons.co_present, color: Color(0xFFFFC107), size: 22),
                    tooltip: 'Launch Podium Mode',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PodiumScreen(lessonPlan: lessonPlan),
                        ),
                      );
                    },
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.share, color: Color(0xFFFFC107), size: 20),
                  tooltip: 'Export / Share',
                  color: const Color(0xFF252525),
                  onSelected: (action) {
                    if (action == 'podium') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PodiumScreen(lessonPlan: lessonPlan),
                        ),
                      );
                    } else if (action == 'syllabus_pdf') {
                      ExportService.exportLessonSyllabusPdf(
                        context: context,
                        lesson: lessonPlan,
                      );
                    } else if (action == 'share') {
                      final text = ExportService.formatPlainTextLesson(
                        title: note.title,
                        timestamp: note.formattedDate,
                        commentary: note.content,
                        sections: resolvedPassages,
                      );
                      ExportService.shareText(context, title: note.title, text: text);
                    } else if (action == 'pdf') {
                      ExportService.generateAndSharePdf(
                        context: context,
                        title: note.title,
                        timestamp: note.formattedDate,
                        noteText: note.content,
                        sections: resolvedPassages,
                      );
                    } else if (action == 'copy') {
                      final text = ExportService.formatPlainTextLesson(
                        title: note.title,
                        timestamp: note.formattedDate,
                        commentary: note.content,
                        sections: resolvedPassages,
                      );
                      ExportService.copyToClipboard(context, text);
                    }
                  },
                  itemBuilder: (context) => [
                    if (isLessonPlan) ...[
                      const PopupMenuItem(
                        value: 'podium',
                        child: Row(
                          children: [
                            Icon(Icons.co_present, size: 18, color: Color(0xFFFFC107)),
                            SizedBox(width: 8),
                            Text('Podium Mode', style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'syllabus_pdf',
                        child: Row(
                          children: [
                            Icon(Icons.menu_book, size: 18, color: Color(0xFFFFC107)),
                            SizedBox(width: 8),
                            Text('Export Syllabus PDF', style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                    ],
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 18, color: Color(0xFFFFC107)),
                          SizedBox(width: 8),
                          Text('Share Text', style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFFFFC107)),
                          SizedBox(width: 8),
                          Text('Export PDF', style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 18, color: Color(0xFFE0E0E0)),
                          SizedBox(width: 8),
                          Text('Copy', style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent.shade100, size: 20),
                  tooltip: 'Delete Note',
                  onPressed: () => _confirmDeleteNote(note),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      note.formattedDate,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    if (isLessonPlan) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LESSON PLAN (${lessonPlan.totalPointsCount} ${lessonPlan.totalPointsCount == 1 ? "POINT" : "POINTS"})',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (note.parsedReferences.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: note.parsedReferences.map((ref) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFFC107).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          ref,
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(color: Color(0xFF2E2E2E)),
                    const SizedBox(height: 8),

                    // User Commentary Section
                    if (note.content.trim().isNotEmpty) ...[
                      const Text(
                        'COMMENTARY & REFLECTION',
                        style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        note.content,
                        style: const TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Top Action Bar (right beneath commentary/reflection and before verses)
                    _buildSavedNoteActionBar(note, resolvedPassages, lessonPlan: isLessonPlan ? lessonPlan : null, showDelete: false),
                    const SizedBox(height: 12),

                    // Full-Text Scripture Passages
                    if (resolvedPassages.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.menu_book, color: Color(0xFFFFC107), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'SCRIPTURE PASSAGES (${resolvedPassages.length})',
                            style: const TextStyle(
                              color: Color(0xFFFFC107),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      for (final passage in resolvedPassages) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF242424),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF383838)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Passage Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      passage.referenceLabel,
                                      style: const TextStyle(
                                        color: Color(0xFFFFC107),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (widget.onNavigateToScripture != null)
                                      InkWell(
                                        onTap: () {
                                          widget.onNavigateToScripture!(
                                            passage.book.id,
                                            passage.chapter,
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.open_in_new, color: Color(0xFFFFC107), size: 14),
                                              SizedBox(width: 4),
                                              Text(
                                                'Read',
                                                style: TextStyle(color: Color(0xFFFFC107), fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Full Verses with Red-Letters
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: passage.verses.map((v) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: VerseTextWidget(verse: v, fontSize: 13.5),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFF2E2E2E)),
                    const SizedBox(height: 8),

                    // Bottom Action Bar with Delete
                    _buildSavedNoteActionBar(note, resolvedPassages, lessonPlan: isLessonPlan ? lessonPlan : null, showDelete: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteNote(StudyNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text(
          'Delete Study Note?',
          style: TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently remove this note and its attached scriptures.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent.shade100,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.instance.deleteStudyNote(note.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Study note deleted'),
            backgroundColor: Color(0xFF2A2A2A),
          ),
        );
      }
    }
  }

  Widget _buildSavedNoteActionBar(
    StudyNote note,
    List<ParsedScriptureRef> resolvedPassages, {
    LessonPlan? lessonPlan,
    bool showDelete = false,
  }) {
    final bool hasLessonPlan = lessonPlan != null && lessonPlan.totalPointsCount > 0;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // Launch Podium Mode
        if (hasLessonPlan)
          ElevatedButton.icon(
            icon: const Icon(Icons.co_present, size: 16, color: Colors.black),
            label: const Text(
              'PODIUM MODE',
              style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PodiumScreen(lessonPlan: lessonPlan),
                ),
              );
            },
          ),

        // Export Syllabus PDF
        if (hasLessonPlan)
          OutlinedButton.icon(
            icon: const Icon(Icons.menu_book, size: 16, color: Color(0xFFFFC107)),
            label: const Text(
              'Syllabus PDF',
              style: TextStyle(color: Color(0xFFFFC107), fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFC107), width: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ExportService.exportLessonSyllabusPdf(
                context: context,
                lesson: lessonPlan,
              );
            },
          ),

        // Share to Chat
        OutlinedButton.icon(
          icon: const Icon(Icons.share, size: 16, color: Color(0xFFFFC107)),
          label: const Text(
            'Share to Chat',
            style: TextStyle(color: Color(0xFFFFC107), fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFFC107), width: 0.9),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            final text = ExportService.formatPlainTextLesson(
              title: note.title,
              timestamp: note.formattedDate,
              commentary: note.content,
              sections: resolvedPassages,
            );
            ExportService.shareText(context, title: note.title, text: text);
          },
        ),

        // Export PDF
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFFFC107)),
          label: const Text(
            'Export PDF',
            style: TextStyle(color: Color(0xFFFFC107), fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFFC107), width: 0.9),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            ExportService.generateAndSharePdf(
              context: context,
              title: note.title,
              timestamp: note.formattedDate,
              noteText: note.content,
              sections: resolvedPassages,
            );
          },
        ),

        // Copy Lesson
        OutlinedButton.icon(
          icon: const Icon(Icons.copy, size: 16, color: Color(0xFFE0E0E0)),
          label: const Text(
            'Copy Lesson',
            style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white24, width: 0.9),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            final text = ExportService.formatPlainTextLesson(
              title: note.title,
              timestamp: note.formattedDate,
              commentary: note.content,
              sections: resolvedPassages,
            );
            ExportService.copyToClipboard(context, text);
          },
        ),

        if (showDelete)
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.redAccent.shade100, size: 20),
            tooltip: 'Delete Note',
            onPressed: () => _confirmDeleteNote(note),
          ),
      ],
    );
  }
}
