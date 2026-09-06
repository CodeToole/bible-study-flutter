import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_note.dart';

/// Manages local persistence for verse highlights, study notes, and study question answers.
class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  SharedPreferences? _prefs;

  // Preset highlight colors per specification
  static const Color colorGold = Color(0xFFFFC107);
  static const Color colorEmerald = Color(0xFF00E676);
  static const Color colorSkyBlue = Color(0xFF40C4FF);
  static const Color colorPink = Color(0xFFFF4081);

  static const List<Color> highlightPalette = [
    colorGold,
    colorEmerald,
    colorSkyBlue,
    colorPink,
  ];

  static const String _highlightsKey = 'bsa_verse_highlights';
  static const String _notesKey = 'bsa_study_notes';
  static const String _questionsKey = 'bsa_study_questions';

  // In-memory cache of highlights: "$bookId:$chapter:$verse" -> Color Value (int)
  final Map<String, int> _highlights = {};
  final List<StudyNote> _notes = [];
  final Map<String, String> _questionAnswers = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadHighlights();
    _loadNotes();
    _loadQuestionAnswers();
  }

  void _loadHighlights() {
    _highlights.clear();
    final raw = _prefs?.getString(_highlightsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is num) {
            _highlights[entry.key] = (entry.value as num).toInt();
          }
        }
      } catch (_) {}
    }
  }

  void _loadNotes() {
    _notes.clear();
    final raw = _prefs?.getString(_notesKey);
    if (raw != null && raw.isNotEmpty) {
      _notes.addAll(StudyNote.decodeList(raw));
    }
  }

  void _loadQuestionAnswers() {
    _questionAnswers.clear();
    final raw = _prefs?.getString(_questionsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _questionAnswers[entry.key] = entry.value.toString();
        }
      } catch (_) {}
    }
  }

  // --- Highlights API ---

  String _verseKey(int book, int chapter, int verse) => '$book:$chapter:$verse';

  Color? getHighlight(int book, int chapter, int verse) {
    final value = _highlights[_verseKey(book, chapter, verse)];
    return value != null ? Color(value) : null;
  }

  Future<void> setHighlight(int book, int chapter, int verse, Color color) async {
    _highlights[_verseKey(book, chapter, verse)] = color.toARGB32();
    await _saveHighlights();
  }

  Future<void> setHighlightsBatch(List<({int book, int chapter, int verse})> verses, Color color) async {
    final colorInt = color.toARGB32();
    for (final v in verses) {
      _highlights[_verseKey(v.book, v.chapter, v.verse)] = colorInt;
    }
    await _saveHighlights();
  }

  Future<void> removeHighlight(int book, int chapter, int verse) async {
    _highlights.remove(_verseKey(book, chapter, verse));
    await _saveHighlights();
  }

  Future<void> removeHighlightsBatch(List<({int book, int chapter, int verse})> verses) async {
    for (final v in verses) {
      _highlights.remove(_verseKey(v.book, v.chapter, v.verse));
    }
    await _saveHighlights();
  }

  Future<void> _saveHighlights() async {
    await _prefs?.setString(_highlightsKey, jsonEncode(_highlights));
  }

  // --- Study Notes API ---

  List<StudyNote> get notes => List.unmodifiable(_notes);

  Future<void> saveNote(StudyNote note) async {
    final existingIndex = _notes.indexWhere((n) => n.id == note.id);
    if (existingIndex >= 0) {
      _notes[existingIndex] = note;
    } else {
      _notes.insert(0, note);
    }
    await _prefs?.setString(_notesKey, StudyNote.encodeList(_notes));
  }

  Future<void> deleteStudyNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _prefs?.setString(_notesKey, StudyNote.encodeList(_notes));
  }

  Future<void> deleteNote(String noteId) => deleteStudyNote(noteId);

  // --- Study Questions / Reflection API ---

  String getQuestionAnswer(String questionKey) => _questionAnswers[questionKey] ?? '';

  Future<void> saveQuestionAnswer(String questionKey, String answer) async {
    _questionAnswers[questionKey] = answer;
    await _prefs?.setString(_questionsKey, jsonEncode(_questionAnswers));
  }
}
