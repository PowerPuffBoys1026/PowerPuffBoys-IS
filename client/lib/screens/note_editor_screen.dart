import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../state/notes_state.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.note});

  final Note note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  double _fontSize = 16;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  TextStyle _getTextStyle() {
    return TextStyle(
      fontSize: _fontSize,
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: _isUnderline ? TextDecoration.underline : TextDecoration.none,
      color: Colors.white.withValues(alpha: 0.92),
      height: 1.6,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notes = context.read<NotesState>();
    final updated = Note(
      id: widget.note.id,
      title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
      content: _contentController.text,
      isPinned: widget.note.isPinned,
      color: widget.note.color,
      tags: widget.note.tags,
      createdAt: widget.note.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await notes.update(updated);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
    }
  }

  void _toggleBold() => setState(() => _isBold = !_isBold);
  void _toggleItalic() => setState(() => _isItalic = !_isItalic);
  void _toggleUnderline() => setState(() => _isUnderline = !_isUnderline);
  void _increaseFont() => setState(() => _fontSize = (_fontSize + 2).clamp(12, 28));
  void _decreaseFont() => setState(() => _fontSize = (_fontSize - 2).clamp(12, 28));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TextField(
          controller: _titleController,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Untitled',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            onPressed: _saving ? null : _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: Icon(Icons.format_bold, color: _isBold ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.8)),
                          onPressed: _toggleBold,
                          tooltip: 'Bold',
                        ),
                        IconButton(
                          icon: Icon(Icons.format_italic, color: _isItalic ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.8)),
                          onPressed: _toggleItalic,
                          tooltip: 'Italic',
                        ),
                        IconButton(
                          icon: Icon(Icons.format_underline, color: _isUnderline ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.8)),
                          onPressed: _toggleUnderline,
                          tooltip: 'Underline',
                        ),
                        const VerticalDivider(width: 16),
                        IconButton(
                          icon: const Icon(Icons.text_decrease),
                          onPressed: _decreaseFont,
                          tooltip: 'Smaller',
                        ),
                        Text('${_fontSize.toInt()}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                        IconButton(
                          icon: const Icon(Icons.text_increase),
                          onPressed: _increaseFont,
                          tooltip: 'Larger',
                        ),
                        const VerticalDivider(width: 16),
                        IconButton(
                          icon: const Icon(Icons.format_list_bulleted),
                          onPressed: () {
                            _contentController.text += '\n• ';
                            _contentController.selection = TextSelection.fromPosition(TextPosition(offset: _contentController.text.length));
                          },
                          tooltip: 'Bullet',
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_list_numbered),
                          onPressed: () {
                            _contentController.text += '\n1. ';
                            _contentController.selection = TextSelection.fromPosition(TextPosition(offset: _contentController.text.length));
                          },
                          tooltip: 'Numbered',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        style: _getTextStyle(),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Start writing your notes...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
