import 'package:flutter/material.dart';
import '../models/verse.dart';

/// Renders a Bible verse with red-letter formatting for Christ's speech,
/// gold verse numbers, and support for highlights and multi-selection.
class VerseTextWidget extends StatelessWidget {
  final Verse verse;
  final bool showVerseNumber;
  final bool isSelected;
  final Color? highlightColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double fontSize;

  const VerseTextWidget({
    super.key,
    required this.verse,
    this.showVerseNumber = true,
    this.isSelected = false,
    this.highlightColor,
    this.onTap,
    this.onLongPress,
    this.fontSize = 16.5,
  });

  // Palette constants
  static const Color goldVerseColor = Color(0xFFFFC107);
  static const Color redLetterColor = Color(0xFFFF5252);
  static const Color standardTextColor = Color(0xFFE0E0E0);
  static const Color italicBracketColor = Color(0xFFB0BEC5);

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> spans = [];

    // Optional gold verse marker
    if (showVerseNumber) {
      spans.add(
        TextSpan(
          text: '${verse.verse} ',
          style: TextStyle(
            color: goldVerseColor,
            fontWeight: FontWeight.bold,
            fontSize: fontSize * 0.9,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    // Tokenize verse text for red-letter speech and italics
    spans.addAll(_tokenizeVerseText(verse.text, fontSize));

    // Determine background highlight
    Color? backgroundColor;
    if (isSelected) {
      backgroundColor = goldVerseColor.withValues(alpha: 0.22);
    } else if (highlightColor != null) {
      backgroundColor = highlightColor!.withValues(alpha: 0.25);
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: goldVerseColor.withValues(alpha: 0.15),
      highlightColor: goldVerseColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: goldVerseColor.withValues(alpha: 0.6), width: 1.2)
              : highlightColor != null
                  ? Border(
                      left: BorderSide(color: highlightColor!, width: 3.5),
                    )
                  : null,
        ),
        child: RichText(
          text: TextSpan(
            children: spans,
            style: TextStyle(
              color: standardTextColor,
              fontSize: fontSize,
              height: 1.6,
              fontFamily: 'Roboto',
            ),
          ),
        ),
      ),
    );
  }

  /// Parses text into TextSpan tree with red-letters, italics, and standard text.
  /// Matches Christ's speech in \u2039...\u203a or ‹...›
  static List<InlineSpan> _tokenizeVerseText(String text, double baseFontSize) {
    final List<InlineSpan> spans = [];

    // Regex to detect red letters: [‹\u2039](.*?)[›\u203a]
    // Also captures paragraph marker ¶ or \u00b6
    final redLetterRegex = RegExp(r'[‹\u2039](.*?)[›\u203a]');

    int lastIndex = 0;
    for (final match in redLetterRegex.allMatches(text)) {
      // Preceding normal text before red-letter section
      if (match.start > lastIndex) {
        final segment = text.substring(lastIndex, match.start);
        spans.addAll(_parseItalicsAndParagraphs(segment, baseFontSize, isRedLetter: false));
      }

      // Red-letter speech
      final speechText = match.group(1) ?? '';
      spans.addAll(_parseItalicsAndParagraphs(speechText, baseFontSize, isRedLetter: true));

      lastIndex = match.end;
    }

    // Remaining normal text after last match
    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex);
      spans.addAll(_parseItalicsAndParagraphs(remaining, baseFontSize, isRedLetter: false));
    }

    return spans;
  }

  /// Handles translator italics [...] and paragraph symbols within segments
  static List<InlineSpan> _parseItalicsAndParagraphs(
    String segment,
    double baseFontSize, {
    required bool isRedLetter,
  }) {
    final List<InlineSpan> spans = [];
    final baseColor = isRedLetter ? redLetterColor : standardTextColor;
    final italicColor = isRedLetter ? redLetterColor.withValues(alpha: 0.85) : italicBracketColor;

    // Pattern to match bracketed translator words: \[([^\]]+)\]
    final bracketRegex = RegExp(r'\[([^\]]+)\]');

    int lastIdx = 0;
    for (final bMatch in bracketRegex.allMatches(segment)) {
      if (bMatch.start > lastIdx) {
        final before = segment.substring(lastIdx, bMatch.start);
        _addCleanedTextSpan(spans, before, baseColor, baseFontSize, isItalic: false);
      }

      final bracketedContent = bMatch.group(1) ?? '';
      _addCleanedTextSpan(spans, bracketedContent, italicColor, baseFontSize, isItalic: true);

      lastIdx = bMatch.end;
    }

    if (lastIdx < segment.length) {
      final after = segment.substring(lastIdx);
      _addCleanedTextSpan(spans, after, baseColor, baseFontSize, isItalic: false);
    }

    return spans;
  }

  /// Adds text span while handling paragraph marker ¶ or \u00b6
  static void _addCleanedTextSpan(
    List<InlineSpan> spans,
    String text,
    Color color,
    double fontSize, {
    required bool isItalic,
  }) {
    if (text.isEmpty) return;

    // Replace paragraph mark with styled small pilcrow or space
    if (text.contains('¶') || text.contains('\u00b6')) {
      final parts = text.split(RegExp(r'[¶\u00b6]'));
      for (int i = 0; i < parts.length; i++) {
        if (i > 0) {
          // Render subtle pilcrow
          spans.add(
            TextSpan(
              text: '¶ ',
              style: TextStyle(
                color: goldVerseColor.withValues(alpha: 0.6),
                fontSize: fontSize * 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        if (parts[i].isNotEmpty) {
          spans.add(
            TextSpan(
              text: parts[i],
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          );
        }
      }
    } else {
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      );
    }
  }
}
