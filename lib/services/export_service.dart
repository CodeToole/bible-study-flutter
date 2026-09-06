import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/verse.dart';
import 'scripture_parser.dart';

/// Service providing plain-text lesson formatting, native system sharing,
/// clipboard copying, and complete PDF generation & export.
class ExportService {
  ExportService._();

  /// Generates a comprehensive plain-text representation of the lesson
  static String formatPlainTextLesson({
    required String title,
    String? timestamp,
    required String commentary,
    required List<ParsedScriptureRef> sections,
  }) {
    final buffer = StringBuffer();
    final dateStr = timestamp ?? DateTime.now().toLocal().toString().split('.')[0];

    buffer.writeln('========================================');
    buffer.writeln(title.trim().toUpperCase());
    buffer.writeln('Date: $dateStr');
    buffer.writeln('========================================\n');

    if (commentary.trim().isNotEmpty) {
      buffer.writeln('STUDY COMMENTARY & NOTES:');
      buffer.writeln('----------------------------------------');
      buffer.writeln(commentary.trim());
      buffer.writeln('\n');
    }

    if (sections.isNotEmpty) {
      buffer.writeln('SCRIPTURE READINGS (KING JAMES VERSION):');
      buffer.writeln('----------------------------------------\n');

      for (final section in sections) {
        buffer.writeln('--- ${section.referenceLabel.toUpperCase()} ---');
        for (final verse in section.verses) {
          buffer.writeln('${verse.verse}. ${verse.plainText}');
        }
        buffer.writeln('');
      }
    }

    return buffer.toString().trim();
  }

  /// Copies text to clipboard with a SnackBar notification
  static void copyToClipboard(BuildContext context, String text, {String message = 'Lesson copied to clipboard!'}) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFFFFC107), size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Opens the native system share sheet (WhatsApp, Keep, Messages, Email, etc.)
  static Future<void> shareText(
    BuildContext context, {
    required String title,
    required String text,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: title,
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Sanitizes text for PDF output, converting common Unicode punctuation into ASCII equivalents
  /// to eliminate missing-glyph tofu "X" boxes in standard PDF fonts.
  static String sanitizeForPdf(String text) {
    return text
        .replaceAll('\u2013', '-') // en-dash
        .replaceAll('\u2014', '-') // em-dash
        .replaceAll('\u2212', '-') // minus sign
        .replaceAll('\u2018', "'") // smart single quote left
        .replaceAll('\u2019', "'") // smart single quote right
        .replaceAll('\u201C', '"') // smart double quote left
        .replaceAll('\u201D', '"') // smart double quote right
        .replaceAll('\u00A0', ' '); // non-breaking space
  }

  /// Generates a complete PDF document and invokes Printing.sharePdf
  static Future<void> generateAndSharePdf({
    required BuildContext context,
    required String title,
    String? timestamp,
    required String noteText,
    required List<ParsedScriptureRef> sections,
  }) async {
    final dateStr = timestamp ?? DateTime.now().toLocal().toString().split('.')[0];
    final doc = pw.Document();
    final sanitizedDocTitle = sanitizeForPdf(title.isNotEmpty ? title : 'Study Notes');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context pdfContext) {
          return [
            // Document Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.amber800, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BIBLE STUDY LESSON',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.amber900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          sanitizedDocTitle,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    dateStr,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // User Commentary Section
            if (noteText.trim().isNotEmpty) ...[
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 18),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'COMMENTARY & REFLECTION',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    for (final line in noteText.trim().split('\n'))
                      if (line.trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 3),
                          child: pw.Text(
                            sanitizeForPdf(line.trim()),
                            style: const pw.TextStyle(
                              fontSize: 9.5,
                              color: PdfColors.grey900,
                            ),
                          ),
                        )
                      else
                        pw.SizedBox(height: 4),
                  ],
                ),
              ),
            ],

            // Scripture Readings with Full Text and Red-Letters
            if (sections.isNotEmpty) ...[
              pw.Text(
                'SCRIPTURE PASSAGES',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.amber900,
                ),
              ),
              pw.SizedBox(height: 8),

              for (final section in sections) ...[
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 14),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.amber100,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          sanitizeForPdf(section.referenceLabel),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.amber900,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),

                      // All verses rendered in full
                      for (final verse in section.verses) ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: _buildPdfVerseSpans(verse),
                              style: const pw.TextStyle(
                                fontSize: 10,
                                lineSpacing: 1.5,
                                color: PdfColors.grey900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ];
        },
      ),
    );

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    final sanitizedTitle = title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_')
        .toLowerCase();
    final filename = sanitizedTitle.isNotEmpty ? '$sanitizedTitle.pdf' : 'bible_study_notes.pdf';

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: filename,
      bounds: origin,
    );
  }

  /// Builds TextSpan tree for PDF with bold verse number, red-letter speech, and standard text
  static List<pw.InlineSpan> _buildPdfVerseSpans(Verse verse) {
    final List<pw.InlineSpan> spans = [];

    // Verse number
    spans.add(
      pw.TextSpan(
        text: '${verse.verse} ',
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.amber900,
          fontSize: 9.5,
        ),
      ),
    );

    // Clean out pilcrow and sanitize all Unicode punctuation for PDF
    final cleanText = sanitizeForPdf(
      verse.text
          .replaceAll('¶', '')
          .replaceAll('\u00b6', ''),
    );

    final redLetterRegex = RegExp(r'[‹\u2039](.*?)[›\u203a]');
    int lastIdx = 0;

    for (final match in redLetterRegex.allMatches(cleanText)) {
      if (match.start > lastIdx) {
        final standard = cleanText.substring(lastIdx, match.start);
        _addPdfItalicsAndStandard(spans, standard, isRed: false);
      }

      final speech = match.group(1) ?? '';
      _addPdfItalicsAndStandard(spans, speech, isRed: true);

      lastIdx = match.end;
    }

    if (lastIdx < cleanText.length) {
      final remaining = cleanText.substring(lastIdx);
      _addPdfItalicsAndStandard(spans, remaining, isRed: false);
    }

    return spans;
  }

  static void _addPdfItalicsAndStandard(List<pw.InlineSpan> spans, String text, {required bool isRed}) {
    if (text.isEmpty) return;

    final baseColor = isRed ? PdfColors.red800 : PdfColors.grey900;
    final bracketRegex = RegExp(r'\[([^\]]+)\]');

    int last = 0;
    for (final bMatch in bracketRegex.allMatches(text)) {
      if (bMatch.start > last) {
        final before = text.substring(last, bMatch.start);
        spans.add(pw.TextSpan(text: before, style: pw.TextStyle(color: baseColor)));
      }

      final italicWords = bMatch.group(1) ?? '';
      spans.add(
        pw.TextSpan(
          text: italicWords,
          style: pw.TextStyle(
            color: baseColor,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      );

      last = bMatch.end;
    }

    if (last < text.length) {
      final after = text.substring(last);
      spans.add(pw.TextSpan(text: after, style: pw.TextStyle(color: baseColor)));
    }
  }
}
