import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lesson_plan.dart';
import '../models/study_note.dart';
import '../services/storage_service.dart';
import '../services/lesson_parser.dart';
import '../services/export_service.dart';
import '../widgets/verse_text.dart';

/// Presentation-optimized, distraction-free screen designed for teachers at the podium.
/// Supports hardware clickers, keyboard arrows, 22pt high-contrast typography,
/// Words of Christ in red, docked speaker cue drawer, and live inline cue/note editing.
class PodiumScreen extends StatefulWidget {
  final LessonPlan lessonPlan;
  final int initialIndex;
  final ValueChanged<LessonPlan>? onLessonPlanUpdated;

  const PodiumScreen({
    super.key,
    required this.lessonPlan,
    this.initialIndex = 0,
    this.onLessonPlanUpdated,
  });

  @override
  State<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends State<PodiumScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late LessonPlan _currentPlan;
  late List<FlatLessonPoint> _flatPoints;
  bool _isCueDrawerExpanded = true;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _quickCueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.lessonPlan;
    _flatPoints = _currentPlan.allPointsFlat;
    final maxIdx = _flatPoints.isNotEmpty ? _flatPoints.length - 1 : 0;
    _currentIndex = widget.initialIndex.clamp(0, maxIdx);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    _quickCueController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < _flatPoints.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    }
  }

  void _jumpTo(int index) {
    if (index >= 0 && index < _flatPoints.length) {
      _pageController.jumpToPage(index);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.pageDown) {
        _goToNext();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.pageUp) {
        _goToPrevious();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Updates cues in memory and persists to StorageService
  Future<void> _updatePointCues(
    FlatLessonPoint flat, {
    List<String>? teacherNotes,
    Map<String, String>? definitions,
  }) async {
    final updatedNotes = teacherNotes ?? flat.point.teacherNotes;
    final updatedDefs = definitions ?? flat.point.definitions;
    final newPoint = flat.point.copyWith(
      teacherNotes: updatedNotes,
      definitions: updatedDefs,
    );

    final List<LessonSection> newSections = [];
    for (final section in _currentPlan.sections) {
      if (identical(section, flat.section) || section.heading == flat.section?.heading) {
        final newPoints = section.points.map((p) => p.order == flat.point.order ? newPoint : p).toList();
        newSections.add(LessonSection(heading: section.heading, points: newPoints));
      } else {
        newSections.add(section);
      }
    }

    final newPlan = LessonPlan(
      id: _currentPlan.id,
      title: _currentPlan.title,
      teacher: _currentPlan.teacher,
      date: _currentPlan.date,
      prayerCitation: _currentPlan.prayerCitation,
      prayerVerses: _currentPlan.prayerVerses,
      introduction: _currentPlan.introduction,
      conclusion: _currentPlan.conclusion,
      sections: newSections,
    );

    setState(() {
      _currentPlan = newPlan;
      _flatPoints = newPlan.allPointsFlat;
    });

    await _persistUpdatedPlan(newPlan);
    widget.onLessonPlanUpdated?.call(newPlan);
  }

  Future<void> _persistUpdatedPlan(LessonPlan plan) async {
    final markdown = LessonParser.serializeToMarkdown(plan);
    final storage = StorageService.instance;
    final existingNoteIdx = storage.notes.indexWhere((n) => n.id == plan.id || n.title == plan.title);

    final noteToSave = StudyNote(
      id: existingNoteIdx >= 0 ? storage.notes[existingNoteIdx].id : plan.id,
      title: plan.title,
      content: markdown,
      parsedReferences: plan.allPointsFlat.map((p) => p.point.rawCitation).toList(),
      createdAt: existingNoteIdx >= 0 ? storage.notes[existingNoteIdx].createdAt : DateTime.now(),
    );

    await storage.saveNote(noteToSave);
  }

  void _addQuickTalkingPoint(FlatLessonPoint flat) {
    final text = _quickCueController.text.trim();
    if (text.isEmpty) return;
    final updated = List<String>.from(flat.point.teacherNotes)..add(text);
    _quickCueController.clear();
    _updatePointCues(flat, teacherNotes: updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Talking point added & saved to lesson plan!'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1E1E1E),
      ),
    );
  }

  void _deleteTalkingPoint(FlatLessonPoint flat, int index) {
    final updated = List<String>.from(flat.point.teacherNotes)..removeAt(index);
    _updatePointCues(flat, teacherNotes: updated);
  }

  void _deleteDefinition(FlatLessonPoint flat, String key) {
    final updated = Map<String, String>.from(flat.point.definitions)..remove(key);
    _updatePointCues(flat, definitions: updated);
  }

  /// Opens an edit sheet to edit/reorder cues and definitions
  Future<void> _openEditCuesModal(FlatLessonPoint flat) async {
    final List<TextEditingController> noteControllers = flat.point.teacherNotes
        .map((n) => TextEditingController(text: n))
        .toList();

    final List<MapEntry<TextEditingController, TextEditingController>> defControllers = flat.point.definitions.entries
        .map((e) => MapEntry(TextEditingController(text: e.key), TextEditingController(text: e.value)))
        .toList();

    final newPointController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
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
                      // Header
                      Row(
                        children: [
                          const Icon(Icons.edit_note, color: Color(0xFFFFC107), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Edit Cues: ${flat.point.rawCitation}',
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

                      // Teacher Talking Points Section
                      const Text(
                        'TEACHER TALKING POINTS',
                        style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (noteControllers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No talking points added yet.',
                            style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ),

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
                                    fillColor: const Color(0xFF242424),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

                      // Add new talking point
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newPointController,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: 'New talking point...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFF222222),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 16, color: Colors.black),
                            label: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onPressed: () {
                              final text = newPointController.text.trim();
                              if (text.isNotEmpty) {
                                setSheetState(() {
                                  noteControllers.add(TextEditingController(text: text));
                                  newPointController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Vocabulary Definitions Section
                      const Text(
                        'VOCABULARY DEFINITIONS',
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
                                    fillColor: const Color(0xFF242424),
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
                                    fillColor: const Color(0xFF242424),
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

                      // Save Button
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
                          _updatePointCues(flat, teacherNotes: updatedNotes, definitions: updatedDefs);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cues successfully saved & synchronized!'),
                              backgroundColor: Color(0xFF1E1E1E),
                            ),
                          );
                        },
                        child: const Text(
                          'SAVE CUES',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
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

    // Dispose temporary controllers
    for (final c in noteControllers) {
      c.dispose();
    }
    for (final e in defControllers) {
      e.key.dispose();
      e.value.dispose();
    }
    newPointController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_flatPoints.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF181818),
          title: Text(_currentPlan.title),
        ),
        body: const Center(
          child: Text(
            'No scripture points in this lesson.',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    final currentFlat = _flatPoints[_currentIndex];
    final currentSection = currentFlat.section;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161616),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Exit Podium Mode',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentPlan.title,
                style: const TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (currentSection?.heading != null && currentSection!.heading!.isNotEmpty)
                Text(
                  '# ${currentSection.heading!.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          actions: [
            // Point progress indicator badge
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Point ${_currentIndex + 1} of ${_flatPoints.length}',
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            // Quick point selection jump menu
            PopupMenuButton<int>(
              icon: const Icon(Icons.list_alt, color: Color(0xFFFFC107)),
              tooltip: 'Jump to Point',
              color: const Color(0xFF222222),
              onSelected: _jumpTo,
              itemBuilder: (context) {
                return _flatPoints.map((item) {
                  final isCurrent = item.globalIndex == _currentIndex;
                  final secHeading = item.section?.heading;
                  return PopupMenuItem<int>(
                    value: item.globalIndex,
                    child: Row(
                      children: [
                        Text(
                          '${item.globalIndex + 1}. ',
                          style: TextStyle(
                            color: isCurrent ? const Color(0xFFFFC107) : Colors.white60,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.point.rawCitation +
                                (secHeading != null ? ' ($secHeading)' : ''),
                            style: TextStyle(
                              color: isCurrent ? const Color(0xFFFFC107) : Colors.white,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent)
                          const Icon(Icons.check, size: 16, color: Color(0xFFFFC107)),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
            // Syllabus PDF Export
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFFFC107)),
              tooltip: 'Export Syllabus PDF',
              onPressed: () {
                ExportService.exportLessonSyllabusPdf(
                  context: context,
                  lesson: _currentPlan,
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // PageView containing scripture passages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _flatPoints.length,
                onPageChanged: (idx) {
                  setState(() {
                    _currentIndex = idx;
                  });
                },
                itemBuilder: (context, index) {
                  final flat = _flatPoints[index];
                  return _buildScriptureBody(flat);
                },
              ),
            ),

            // Docked Speaker Cue Drawer with Live Inline Editing
            _buildDockedSpeakerCueDrawer(currentFlat),

            // Fixed Bottom Thumb Controls (< Previous, Next >)
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  /// Scrollable main body displaying large 22pt high-contrast scripture text
  Widget _buildScriptureBody(FlatLessonPoint flat) {
    final point = flat.point;
    final section = flat.section;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thematic Section Banner
          if (section?.heading != null && section!.heading!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border, color: Color(0xFFFFC107), size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      section.heading!.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Scripture Citation Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'POINT ${flat.globalIndex + 1}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  point.rawCitation,
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A2A2A), thickness: 1.2),
          const SizedBox(height: 12),

          // Scripture Verses in 22pt high-contrast typography
          if (point.verses.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'Scripture reference "${point.rawCitation}" could not be resolved from dataset.',
                style: const TextStyle(color: Colors.white60, fontSize: 16),
              ),
            )
          else
            ...point.verses.map((v) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: VerseTextWidget(
                  verse: v,
                  fontSize: 22,
                  showVerseNumber: true,
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Docked Speaker Cue Drawer displaying definitions & teacher prompts with live editing
  Widget _buildDockedSpeakerCueDrawer(FlatLessonPoint flat) {
    final point = flat.point;
    final hasDefs = point.definitions.isNotEmpty;
    final hasNotes = point.teacherNotes.isNotEmpty;
    final hasCues = hasDefs || hasNotes;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFFFC107).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drawer Header Toggle with Edit Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isCueDrawerExpanded = !_isCueDrawerExpanded;
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Color(0xFFFFC107), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'SPEAKER CUES & TALKING POINTS',
                        style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasCues)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${point.definitions.length + point.teacherNotes.length}',
                            style: const TextStyle(
                              color: Color(0xFFFFC107),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                // Edit / + Add Cue Button
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Color(0xFFFFC107), size: 22),
                  tooltip: 'Edit / + Add Cue',
                  onPressed: () => _openEditCuesModal(flat),
                ),
                IconButton(
                  icon: Icon(
                    _isCueDrawerExpanded ? Icons.expand_more : Icons.expand_less,
                    color: const Color(0xFFFFC107),
                    size: 20,
                  ),
                  tooltip: _isCueDrawerExpanded ? 'Collapse Drawer' : 'Expand Drawer',
                  onPressed: () {
                    setState(() {
                      _isCueDrawerExpanded = !_isCueDrawerExpanded;
                    });
                  },
                ),
              ],
            ),
          ),

          // Drawer Body
          if (_isCueDrawerExpanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Vocabulary Definition Chips
                    if (hasDefs) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: point.definitions.entries.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFFC107).withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${e.key} = ',
                                        style: const TextStyle(
                                          color: Color(0xFFFFC107),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: e.value,
                                        style: const TextStyle(
                                          color: Color(0xFFEEEEEE),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _deleteDefinition(flat, e.key),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white60),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Teacher Talking Points
                    if (hasNotes) ...[
                      ...List.generate(point.teacherNotes.length, (nIdx) {
                        final note = point.teacherNotes[nIdx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6, right: 8),
                                child: Icon(Icons.circle, color: Color(0xFFFFC107), size: 7),
                              ),
                              Expanded(
                                child: Text(
                                  note,
                                  style: const TextStyle(
                                    color: Color(0xFFF0F0F0),
                                    fontSize: 15,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _deleteTalkingPoint(flat, nIdx),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.close, size: 16, color: Colors.white38),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],

                    if (!hasCues)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'No speaker cues or notes for this point yet.',
                          style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ),

                    // Inline Quick Add Talking Point Field
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quickCueController,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                              decoration: const InputDecoration(
                                hintText: 'Quick add a talking point...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _addQuickTalkingPoint(flat),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFFFFC107), size: 22),
                            tooltip: 'Add point',
                            onPressed: () => _addQuickTalkingPoint(flat),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Fixed Bottom Thumb Controls for one-tap podium navigation
  Widget _buildBottomControls() {
    final bool canGoBack = _currentIndex > 0;
    final bool canGoForward = _currentIndex < _flatPoints.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF121212),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Previous Button
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: canGoBack ? _goToPrevious : null,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  label: const Text(
                    'Previous',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF262626),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF1A1A1A),
                    disabledForegroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: canGoBack ? const Color(0xFFFFC107).withValues(alpha: 0.3) : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Next Button
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: canGoForward ? _goToNext : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  label: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFF1A1A1A),
                    disabledForegroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
