import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/notes_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/v2_kit.dart';
import 'note_editor_screen.dart';

class NoteReaderScreen extends StatelessWidget {
  const NoteReaderScreen({super.key, required this.noteId});

  final int noteId;

  @override
  Widget build(BuildContext context) {
    final notesState = context.watch<NotesState>();
    final colors = context.colors;
    final matches = notesState.notes.where((n) => n.id == noteId);
    final note = matches.isEmpty ? null : matches.first;

    if (note == null) {
      return Scaffold(
        backgroundColor: colors.bgPrimary,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const V2Empty(
          icon: Icons.sticky_note_2_outlined,
          title: 'This flashnote is gone',
          message: 'It may have been deleted from another device.',
        ),
      );
    }

    final accent = hexToColor(
      note.color ?? note.subjectColor,
      fallback: colors.primary,
    );
    final tags = (note.tags ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: note.isPinned ? 'Unpin' : 'Pin',
            icon: Icon(
              note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            onPressed: () => notesState.togglePin(note),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Delete flashnote?'),
                  content: const Text('The note moves to the recycle bin.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              final deleted = await notesState.delete(note);
              if (deleted && context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (note.subjectCode != null)
                        V2Badge(note.subjectCode!, color: accent, dense: true)
                      else
                        V2Badge('FLASHNOTE', color: accent, dense: true),
                      const SizedBox(width: 8),
                      if (note.updatedAt.isNotEmpty)
                        Text(
                          formatDate(note.updatedAt),
                          style: TextStyle(color: colors.textDim, fontSize: 10),
                        ),
                      const Spacer(),
                      if (note.isPinned)
                        V2Badge(
                          'Pinned',
                          icon: Icons.push_pin,
                          color: accent,
                          dense: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    style: TextStyle(
                      color: colors.textMain,
                      fontFamily: 'serif',
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      letterSpacing: -0.6,
                    ),
                  ),
                  if (note.subjectTitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      note.subjectTitle!,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags)
                          V2Badge(
                            '#$tag',
                            color: colors.textMuted,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(height: 2, width: 44, color: accent),
                  const SizedBox(height: 18),
                  SelectableText(
                    note.content.trim().isEmpty
                        ? 'This note is empty. Tap edit to add content.'
                        : note.content,
                    style: TextStyle(
                      color: note.content.trim().isEmpty
                          ? colors.textDim
                          : colors.textMain,
                      fontSize: 14,
                      height: 1.75,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Divider(color: colors.border),
                  const SizedBox(height: 8),
                  Text(
                    'Updated ${note.updatedAt.isEmpty ? 'recently' : formatDate(note.updatedAt)}',
                    style: TextStyle(color: colors.textDim, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
