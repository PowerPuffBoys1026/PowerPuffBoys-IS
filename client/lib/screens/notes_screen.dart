import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../state/notes_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/v2_kit.dart';
import 'note_editor_screen.dart';
import 'note_reader_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotesState>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final notes = context.read<NotesState>();
    final note = await notes.create(title: 'Untitled', content: '');
    if (!mounted) return;
    if (note != null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesState = context.watch<NotesState>();
    final notes = notesState.notes;
    final colors = context.colors;

    return RefreshIndicator(
      onRefresh: notesState.load,
      child: ListView(
        padding: v2PagePadding(context),
        children: [
          v2Centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final search = TextField(
                      controller: _search,
                      onChanged: notesState.setSearch,
                      decoration: InputDecoration(
                        hintText: 'Search flashnotes…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  notesState.setSearch('');
                                  setState(() {});
                                },
                              ),
                        isDense: true,
                      ),
                    );
                    final add = PillButton(
                      label: 'New flashnote',
                      icon: Icons.add,
                      tone: colors.primary,
                      onPressed: _create,
                    );
                    if (constraints.maxWidth < 620) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [search, const SizedBox(height: 10), add],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 10),
                        add,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (notes.any((n) => n.isPinned))
                      V2Badge(
                        '${notes.where((n) => n.isPinned).length} pinned',
                        icon: Icons.push_pin,
                        color: colors.primary,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (notesState.loading && notes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (notes.isEmpty)
                  V2Empty(
                    icon: Icons.sticky_note_2_outlined,
                    title: _search.text.isEmpty
                        ? 'No flashnotes yet'
                        : 'No matches',
                    message: _search.text.isEmpty
                        ? 'Capture a lecture insight, formula, or reminder before it slips away.'
                        : 'Try a different keyword.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1150
                          ? 4
                          : constraints.maxWidth >= 860
                          ? 3
                          : constraints.maxWidth >= 560
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 10) / columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final note in notes)
                            SizedBox(
                              width: width,
                              child: _NoteCard(
                                note: note,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        NoteReaderScreen(noteId: note.id),
                                  ),
                                ),
                                onEdit: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        NoteEditorScreen(note: note),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onEdit,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  String _preview(String content) {
    if (content.trim().isEmpty) return 'No content yet';
    final cleaned = content.replaceAll('\n', ' ').trim();
    if (cleaned.length <= 150) return cleaned;
    return '${cleaned.substring(0, 150)}…';
  }

  @override
  Widget build(BuildContext context) {
    final notesState = context.read<NotesState>();
    final colors = context.colors;
    final accent = hexToColor(
      note.color ?? note.subjectColor,
      fallback: colors.primary,
    );
    final tags = (note.tags ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      accent: note.isPinned ? accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (note.subjectCode != null)
                V2Badge(note.subjectCode!, color: accent, dense: true)
              else
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 15,
                  color: colors.textDim,
                ),
              const Spacer(),
              if (note.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(Icons.push_pin, size: 14, color: accent),
                ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, size: 17, color: colors.textDim),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'pin':
                      notesState.togglePin(note);
                    case 'delete':
                      notesState.delete(note);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(note.isPinned ? 'Unpin' : 'Pin'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note.title.isEmpty ? 'Untitled' : note.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textMain,
              fontFamily: 'serif',
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _preview(note.content),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final tag in tags.take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(color: colors.textMuted, fontSize: 8.5),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            note.updatedAt.isEmpty
                ? ''
                : 'Updated ${note.updatedAt.substring(0, 10)}',
            style: TextStyle(color: colors.textDim, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}
