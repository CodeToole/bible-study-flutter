import 'package:flutter/material.dart';
import '../models/source_snippet.dart';
import '../services/storage_service.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key, this.onOpenVerse});

  final void Function(String verseKey)? onOpenVerse;

  @override
  State<SourcesScreen> createState() => SourcesScreenState();
}

class SourcesScreenState extends State<SourcesScreen> {
  List<SourceSnippet> _sources = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _sources = StorageService.instance.sources;
    });
  }

  Future<void> _openEditor([SourceSnippet? existing]) async {
    final saved = await showModalBottomSheet<SourceSnippet>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SourceEditorSheet(existing: existing),
    );
    if (saved == null) return;
    await StorageService.instance.saveSource(saved);
    _reload();
  }

  Future<void> _delete(SourceSnippet source) async {
    await StorageService.instance.deleteSource(source.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Sources'),
        actions: [
          IconButton(
            tooltip: 'Add source',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _sources.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Pin a book page, article, chart, photo, or other text beside a verse. Type a short snippet. Do not scan the whole book.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: _sources.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final source = _sources[index];
                return _SourceCard(
                  source: source,
                  onEdit: () => _openEditor(source),
                  onDelete: () => _delete(source),
                  onOpenVerse: widget.onOpenVerse,
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.library_add_outlined),
        label: const Text('Add source'),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.onEdit,
    required this.onDelete,
    this.onOpenVerse,
  });

  final SourceSnippet source;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String verseKey)? onOpenVerse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  source.kind.label,
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          Text(
            source.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (source.citation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              source.citation,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          if (source.snippet.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(source.snippet, style: const TextStyle(height: 1.35)),
          ],
          if (source.verseKeys.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: source.verseKeys.map((key) {
                return ActionChip(
                  label: Text(key),
                  onPressed: onOpenVerse == null ? null : () => onOpenVerse!(key),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class SourceEditorSheet extends StatefulWidget {
  const SourceEditorSheet({super.key, this.existing});

  final SourceSnippet? existing;

  @override
  State<SourceEditorSheet> createState() => _SourceEditorSheetState();
}

class _SourceEditorSheetState extends State<SourceEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _citation;
  late final TextEditingController _snippet;
  late final TextEditingController _verses;
  late final TextEditingController _lesson;
  late SourceKind _kind;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? SourceKind.book;
    _title = TextEditingController(text: existing?.title ?? '');
    _citation = TextEditingController(text: existing?.citation ?? '');
    _snippet = TextEditingController(text: existing?.snippet ?? '');
    _verses = TextEditingController(text: existing?.verseKeys.join(', ') ?? '');
    _lesson = TextEditingController(text: existing?.lessonTitle ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _citation.dispose();
    _snippet.dispose();
    _verses.dispose();
    _lesson.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final keys = _verses.text
        .split(RegExp(r'[,;\n]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final now = DateTime.now();
    Navigator.pop(
      context,
      SourceSnippet(
        id: widget.existing?.id ?? now.microsecondsSinceEpoch.toString(),
        kind: _kind,
        title: title,
        citation: _citation.text.trim(),
        snippet: _snippet.text.trim(),
        verseKeys: keys,
        lessonTitle: _lesson.text.trim().isEmpty ? null : _lesson.text.trim(),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Source card',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SourceKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: SourceKind.values
                  .map(
                    (kind) => DropdownMenuItem(
                      value: kind,
                      child: Text(kind.label),
                    ),
                  )
                  .toList(),
              onChanged: (kind) {
                if (kind == null) return;
                setState(() => _kind = kind);
              },
            ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Last Two Million Years, Nature article, Quran',
              ),
            ),
            TextField(
              controller: _citation,
              decoration: const InputDecoration(
                labelText: 'Where',
                hintText: 'p. 87, Surah 3, Job chart',
              ),
            ),
            TextField(
              controller: _verses,
              decoration: const InputDecoration(
                labelText: 'Pinned verses',
                hintText: 'Deut 28:64, Job 26:7',
              ),
            ),
            TextField(
              controller: _lesson,
              decoration: const InputDecoration(labelText: 'Lesson title'),
            ),
            TextField(
              controller: _snippet,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Short snippet',
                hintText: 'A sentence or two the teacher is reading. Not the chapter.',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save source'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
