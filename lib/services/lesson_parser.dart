import '../models/verse.dart';
import '../models/lesson_plan.dart';
import 'bible_service.dart';
import 'scripture_parser.dart';

/// Parses markdown-lite lesson syntax into structured LessonPlan objects,
/// extracting metadata, thematic sections, vocabulary definitions, teacher talking points,
/// and resolving King James scripture passages.
class LessonParser {
  LessonParser._();

  // Regex matching definitions: e.g. "Sanctify = to set apart" or "Heart = Mind"
  static final RegExp _defRegex = RegExp(
    r'([A-Za-z ]+)\s*=\s*([^,\n\r;]+)',
  );

  /// Main entry point to parse a lesson outline into a structured LessonPlan
  static LessonPlan parseLessonOutline(String rawText, BibleService bibleService) {
    if (rawText.trim().isEmpty) {
      return const LessonPlan(
        id: '',
        title: 'Untitled Lesson',
        sections: [],
      );
    }

    String? title;
    String? teacher;
    String? date;
    String? prayerCitation;
    List<Verse> prayerVerses = [];
    final StringBuffer introBuffer = StringBuffer();
    final StringBuffer conclusionBuffer = StringBuffer();

    bool inIntro = false;
    bool inConclusion = false;

    final List<String> lines = rawText.split('\n');

    // Section builder state
    final List<LessonSection> sections = [];
    String? currentSectionHeading;
    final List<LessonPoint> currentSectionPoints = [];

    // Current point builder state
    int currentOrder = 1;
    String? currentCitation;
    List<Verse> currentVerses = [];
    Map<String, String> currentDefinitions = {};
    List<String> currentNotes = [];
    bool hasActivePoint = false;

    void commitCurrentPoint() {
      if (!hasActivePoint || currentCitation == null) return;

      currentSectionPoints.add(
        LessonPoint(
          order: currentOrder++,
          rawCitation: currentCitation!,
          verses: currentVerses,
          definitions: Map<String, String>.from(currentDefinitions),
          teacherNotes: List<String>.from(currentNotes),
        ),
      );

      // Reset point state
      currentCitation = null;
      currentVerses = [];
      currentDefinitions = {};
      currentNotes = [];
      hasActivePoint = false;
    }

    void commitCurrentSection() {
      commitCurrentPoint();

      if (currentSectionHeading != null || currentSectionPoints.isNotEmpty) {
        sections.add(
          LessonSection(
            heading: currentSectionHeading,
            points: List<LessonPoint>.from(currentSectionPoints),
          ),
        );
        currentSectionPoints.clear();
      }
      currentSectionHeading = null;
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final lower = trimmed.toLowerCase();

      // Check metadata keys (Title, Teacher, Date, Prayer, Intro, Conclusion)
      if (lower.startsWith('title:')) {
        title = trimmed.substring(6).trim();
        inIntro = false;
        inConclusion = false;
        continue;
      }
      if (lower.startsWith('teacher:')) {
        teacher = trimmed.substring(8).trim();
        inIntro = false;
        inConclusion = false;
        continue;
      }
      if (lower.startsWith('date:')) {
        date = trimmed.substring(5).trim();
        inIntro = false;
        inConclusion = false;
        continue;
      }
      if (lower.startsWith('prayer:')) {
        prayerCitation = trimmed.substring(7).trim();
        final prayerRefs = ScriptureParser.parse(prayerCitation);
        if (prayerRefs.isNotEmpty) {
          prayerVerses = prayerRefs.expand((r) => r.verses).toList();
          prayerCitation = prayerRefs.first.referenceLabel;
        }
        inIntro = false;
        inConclusion = false;
        continue;
      }
      if (lower.startsWith('intro:') || lower.startsWith('introduction:')) {
        commitCurrentPoint();
        inIntro = true;
        inConclusion = false;
        final colonIdx = trimmed.indexOf(':');
        final afterColon = trimmed.substring(colonIdx + 1).trim();
        if (afterColon.isNotEmpty) {
          introBuffer.writeln(afterColon);
        }
        continue;
      }
      if (lower.startsWith('conclusion:')) {
        commitCurrentSection();
        inConclusion = true;
        inIntro = false;
        final colonIdx = trimmed.indexOf(':');
        final afterColon = trimmed.substring(colonIdx + 1).trim();
        if (afterColon.isNotEmpty) {
          conclusionBuffer.writeln(afterColon);
        }
        continue;
      }

      // Check section banner starting with '#'
      if (trimmed.startsWith('#')) {
        inIntro = false;
        inConclusion = false;
        commitCurrentSection();
        currentSectionHeading = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        continue;
      }

      // If we are currently accumulating intro text
      if (inIntro) {
        // Stop if this line looks like a point, section, or conclusion
        final parsedCheck = ScriptureParser.parse(trimmed);
        if (parsedCheck.isEmpty && !trimmed.startsWith('#') && !lower.startsWith('conclusion:')) {
          introBuffer.writeln(trimmed);
          continue;
        } else {
          inIntro = false;
        }
      }

      // If we are currently accumulating conclusion text
      if (inConclusion) {
        if (!trimmed.startsWith('#')) {
          conclusionBuffer.writeln(trimmed);
          continue;
        } else {
          inConclusion = false;
        }
      }

      // Check if this line introduces a new point
      // A line triggers a new point if it contains scripture citation AND is not a bullet comment
      final isBullet = trimmed.startsWith('-') ||
          trimmed.startsWith('•') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('–');

      final bool hasDefinition = _isDefinitionLine(trimmed);

      final parsedRefs = ScriptureParser.parse(trimmed);

      // Explicit point numbering e.g. "1.", "1)", "Point 1:"
      final isNumberedPoint = RegExp(r'^(?:point\s+)?\d+[\.\)\:]', caseSensitive: false).hasMatch(trimmed);

      final isPointHeader = (parsedRefs.isNotEmpty && !isBullet && !hasDefinition) ||
          (isNumberedPoint && parsedRefs.isNotEmpty);

      if (isPointHeader) {
        commitCurrentPoint();
        hasActivePoint = true;

        // Use the parsed reference as citation
        final primaryRef = parsedRefs.first;
        currentCitation = primaryRef.referenceLabel;
        currentVerses = primaryRef.verses;

        // Any definitions on the same line?
        final lineDefs = _extractDefinitions(trimmed);
        if (lineDefs.isNotEmpty) {
          currentDefinitions.addAll(lineDefs);
        }

        // Any trailing commentary on the citation line?
        // E.g. "1. EXODUS 20:1-17 (Ten Commandments)" -> extract trailing commentary if relevant
        final cleanCitationText = trimmed
            .replaceFirst(RegExp(r'^(?:point\s+)?\d+[\.\)\:]\s*', caseSensitive: false), '')
            .replaceAll(primaryRef.rawMatch, '')
            .replaceAll(RegExp(r'[\(\)]'), '')
            .trim();
        if (cleanCitationText.isNotEmpty && !lineDefs.keys.any((k) => cleanCitationText.contains(k))) {
          currentNotes.add(cleanCitationText);
        }

        continue;
      }

      // If we are inside an active point, process definitions or teacher notes
      if (hasActivePoint) {
        // 1. Vocabulary definitions
        final defs = _extractDefinitions(trimmed);
        if (defs.isNotEmpty) {
          currentDefinitions.addAll(defs);
          continue;
        }

        // 2. Teacher talking points / bullets
        if (isBullet) {
          final note = trimmed.replaceFirst(RegExp(r'^[-•*–]\s*'), '').trim();
          if (note.isNotEmpty) {
            currentNotes.add(note);
          }
          continue;
        }

        // 3. Regular non-empty commentary line within this point
        currentNotes.add(trimmed);
        continue;
      }

      // If no active point yet, and not intro/conclusion, check definitions or notes
      final strayDefs = _extractDefinitions(trimmed);
      if (strayDefs.isNotEmpty) {
        currentDefinitions.addAll(strayDefs);
      }
    }

    // Commit any lingering point and section
    commitCurrentSection();

    // Fallback title
    final effectiveTitle = title?.isNotEmpty == true
        ? title!
        : (sections.isNotEmpty && sections.first.points.isNotEmpty
            ? 'Lesson: ${sections.first.points.first.rawCitation}'
            : 'Bible Study Lesson');

    final introStr = introBuffer.toString().trim();
    final conclusionStr = conclusionBuffer.toString().trim();

    return LessonPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: effectiveTitle,
      teacher: teacher,
      date: date,
      prayerCitation: prayerCitation,
      prayerVerses: prayerVerses,
      introduction: introStr.isNotEmpty ? introStr : null,
      conclusion: conclusionStr.isNotEmpty ? conclusionStr : null,
      sections: sections,
    );
  }

  /// Extracts definitions matching "Word = Meaning"
  static Map<String, String> _extractDefinitions(String text) {
    final Map<String, String> definitions = {};
    for (final match in _defRegex.allMatches(text)) {
      final key = (match.group(1) ?? '').trim();
      final value = (match.group(2) ?? '').trim();
      // Filter out assignments that are likely not vocabulary (e.g. single character or equation)
      if (key.length >= 2 && value.isNotEmpty && !key.toLowerCase().startsWith('http')) {
        definitions[key] = value;
      }
    }
    return definitions;
  }

  static bool _isDefinitionLine(String text) {
    if (!text.contains('=')) return false;
    final defs = _extractDefinitions(text);
    return defs.isNotEmpty;
  }

  /// Converts a structured LessonPlan back into canonical markdown-lite syntax
  static String serializeToMarkdown(LessonPlan plan) {
    final buffer = StringBuffer();
    if (plan.title.isNotEmpty) buffer.writeln('Title: ${plan.title}');
    if (plan.teacher != null && plan.teacher!.isNotEmpty) buffer.writeln('Teacher: ${plan.teacher}');
    if (plan.date != null && plan.date!.isNotEmpty) buffer.writeln('Date: ${plan.date}');
    if (plan.prayerCitation != null && plan.prayerCitation!.isNotEmpty) buffer.writeln('Prayer: ${plan.prayerCitation}');
    if (plan.introduction != null && plan.introduction!.isNotEmpty) {
      buffer.writeln('Intro: ${plan.introduction}\n');
    }

    for (final section in plan.sections) {
      if (section.heading != null && section.heading!.isNotEmpty) {
        buffer.writeln('\n# ${section.heading}');
      }
      for (final point in section.points) {
        buffer.writeln('${point.order}. ${point.rawCitation}');
        for (final entry in point.definitions.entries) {
          buffer.writeln('${entry.key} = ${entry.value}');
        }
        for (final note in point.teacherNotes) {
          buffer.writeln('- $note');
        }
        buffer.writeln('');
      }
    }

    if (plan.conclusion != null && plan.conclusion!.isNotEmpty) {
      buffer.writeln('Conclusion: ${plan.conclusion}');
    }

    return buffer.toString().trim();
  }
}
