import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/verse.dart';
import '../services/storage_service.dart';

/// Bottom action bar/sheet shown when verses are selected in the reader
class HighlightBottomSheet extends StatelessWidget {
  final List<Verse> selectedVerses;
  final ValueChanged<Color> onApplyColor;
  final VoidCallback onClearHighlight;
  final VoidCallback onSendToNotes;
  final VoidCallback onDeselectAll;

  const HighlightBottomSheet({
    super.key,
    required this.selectedVerses,
    required this.onApplyColor,
    required this.onClearHighlight,
    required this.onSendToNotes,
    required this.onDeselectAll,
  });

  void _copyToClipboard(BuildContext context) {
    if (selectedVerses.isEmpty) return;

    // Sort verses by verse number
    final sorted = List<Verse>.from(selectedVerses)..sort((a, b) => a.verse.compareTo(b.verse));
    final buffer = StringBuffer();
    final first = sorted.first;
    buffer.writeln('${first.bookName} ${first.chapter}:${sorted.map((v) => v.verse).join(",")}');
    for (final v in sorted) {
      buffer.writeln('[${v.verse}] ${v.plainText}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selectedVerses.length} verse(s) copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedVerses.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: const Color(0xFFFFC107).withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selection count header & controls
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedVerses.length} verse${selectedVerses.length > 1 ? "s" : ""} selected',
                    style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Color(0xFFE0E0E0), size: 20),
                  tooltip: 'Copy verses',
                  onPressed: () => _copyToClipboard(context),
                ),
                IconButton(
                  icon: const Icon(Icons.note_add_outlined, color: Color(0xFFFFC107), size: 21),
                  tooltip: 'Create study note',
                  onPressed: onSendToNotes,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  tooltip: 'Clear selection',
                  onPressed: onDeselectAll,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Color Chips for Highlighting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorChip('Gold', StorageService.colorGold),
                _buildColorChip('Emerald', StorageService.colorEmerald),
                _buildColorChip('Sky Blue', StorageService.colorSkyBlue),
                _buildColorChip('Pink', StorageService.colorPink),
                _buildClearChip(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorChip(String label, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onApplyColor(color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearChip() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onClearHighlight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E2E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Icon(Icons.format_color_reset, color: Colors.white70, size: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Clear',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
