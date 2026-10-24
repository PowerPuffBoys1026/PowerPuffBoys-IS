import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class NotesDialog extends StatefulWidget {
  const NotesDialog({super.key, this.initialSubjectId});

  final int? initialSubjectId;

  @override
  State<NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<NotesDialog> {
  int? _subjectFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _subjectFilter = widget.initialSubjectId;
  }

  Future<void> _openNoteForm([SubjectNote? note]) async {
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');
    final tagsCtrl = TextEditingController(text: note?.tags ?? '');
    int? selectedSubId = note?.subjectId ?? _subjectFilter;
    bool isPinned = note?.isPinned ?? false;

    final app = context.read<AppState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(note == null ? 'New Study Note' : 'Edit Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: selectedSubId,
                  decoration: const InputDecoration(labelText: 'Course'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('General Note'),
                    ),
                    for (final s in app.subjects)
                      DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text('${s.code} · ${s.title}'),
                      ),
                  ],
                  onChanged: (val) => setDialogState(() => selectedSubId = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Midterm Cheat Sheet / Formula Summary',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Key Takeaways',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    hintText: 'formulas, exam, summary',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Pin to top'),
                  value: isPinned,
                  onChanged: (v) =>
                      setDialogState(() => isPinned = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Note'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      if (note == null) {
        await app.addNote(
          subjectId: selectedSubId,
          title: titleCtrl.text.trim(),
          content: contentCtrl.text.trim(),
          tags: tagsCtrl.text.trim(),
          isPinned: isPinned,
        );
      } else {
        await app.editNote(
          note.id,
          subjectId: selectedSubId,
          title: titleCtrl.text.trim(),
          content: contentCtrl.text.trim(),
          tags: tagsCtrl.text.trim(),
          isPinned: isPinned,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final notes = app.notes.where((n) {
      if (_subjectFilter != null && n.subjectId != _subjectFilter) return false;
      if (_search.isNotEmpty) {
        final query = _search.toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(query);
        final matchContent = n.content.toLowerCase().contains(query);
        final matchTags = n.tags?.toLowerCase().contains(query) ?? false;
        if (!matchTitle && !matchContent && !matchTags) return false;
      }
      return true;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PortalColors.amber.withAlpha(24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.note_alt_outlined,
                      color: PortalColors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study Flashnotes & Cheat Sheets',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Quick formulas, exam reminders & study summaries.',
                          style: TextStyle(
                            fontSize: 12,
                            color: PortalColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openNoteForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Note'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter & Search Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Search notes by keyword, tag, or formula...',
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _search = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int?>(
                    value: _subjectFilter,
                    hint: const Text('All Courses'),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Courses'),
                      ),
                      for (final s in app.subjects)
                        DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(s.code),
                        ),
                    ],
                    onChanged: (val) => setState(() => _subjectFilter = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes List
              Expanded(
                child: notes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_note_outlined,
                              size: 48,
                              color: PortalColors.muted,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No study notes found',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create a note for exam tips, formulas, or syllabus cheat sheets.',
                              style: TextStyle(
                                fontSize: 12,
                                color: PortalColors.muted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: notes.length,
                        itemBuilder: (context, idx) {
                          final n = notes[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (n.isPinned) ...[
                                        const Icon(
                                          Icons.push_pin,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      if (n.subjectCode != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: (n.subjectColor != null
                                                    ? hexToColor(n.subjectColor!)
                                                    : PortalColors.primary)
                                                .withAlpha(24),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            n.subjectCode!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: n.subjectColor != null
                                                  ? hexToColor(n.subjectColor!)
                                                  : PortalColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 18),
                                        onPressed: () => _openNoteForm(n),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18),
                                        onPressed: () =>
                                            app.removeNote(n.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    n.content,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: isDark
                                          ? PortalColors.inkDark
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                  if (n.tags != null &&
                                      n.tags!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        for (final tag in n.tags!.split(','))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1E293B)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '#${tag.trim()}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: PortalColors.muted,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
