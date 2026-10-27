import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../state/notes_state.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesState>().load();
    });
  }

  Future<void> _create() async {
    final notes = context.read<NotesState>();
    final note = await notes.create(title: 'Untitled', content: '');
    if (!mounted) return;
    if (note != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesState = context.watch<NotesState>();
    final notes = notesState.notes;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _create,
            tooltip: 'New note',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: notesState.setSearch,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: notesState.loading
                  ? const Center(child: CircularProgressIndicator())
                  : notes.isEmpty
                      ? Center(
                          child: Text(
                            'No notes yet. Tap + to create one.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320,
                            mainAxisExtent: 180,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return _NoteCard(note: note);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.note_add_outlined),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final Note note;

  String _preview(String content) {
    if (content.isEmpty) return 'No content';
    final cleaned = content.replaceAll('\n', ' ');
    if (cleaned.length <= 120) return cleaned;
    return '${cleaned.substring(0, 120)}...';
  }

  @override
  Widget build(BuildContext context) {
    final notesState = context.read<NotesState>();
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      if (note.isPinned)
                        Icon(Icons.push_pin, size: 16, color: Theme.of(context).colorScheme.primary),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.6)),
                        onSelected: (value) {
                          if (value == 'pin') {
                            notesState.togglePin(note);
                          } else if (value == 'delete') {
                            notesState.delete(note);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'pin', child: Text(note.isPinned ? 'Unpin' : 'Pin')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      _preview(note.content),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Updated ${note.updatedAt.substring(0, 10)}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
