import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../state/app_state.dart';
import '../state/notes_state.dart';
import '../theme.dart';
import '../widgets/attachments_panel.dart';
import '../widgets/v2_kit.dart';

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
  double _fontSize = 15;
  bool _saving = false;
  int? _subjectId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _subjectId = widget.note.subjectId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  TextStyle _getTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: _fontSize,
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: _isUnderline ? TextDecoration.underline : TextDecoration.none,
      color: context.colors.textMain,
      height: 1.65,
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
      subjectId: _subjectId,
      subjectCode: widget.note.subjectCode,
      subjectTitle: widget.note.subjectTitle,
      subjectColor: widget.note.subjectColor,
    );
    final ok = await notes.update(updated);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Flashnote saved' : 'Could not save note')),
      );
    }
  }

  void _toggleBold() => setState(() => _isBold = !_isBold);
  void _toggleItalic() => setState(() => _isItalic = !_isItalic);
  void _toggleUnderline() => setState(() => _isUnderline = !_isUnderline);
  void _increaseFont() =>
      setState(() => _fontSize = (_fontSize + 2).clamp(12, 28));
  void _decreaseFont() =>
      setState(() => _fontSize = (_fontSize - 2).clamp(12, 28));

  void _insert(String text) {
    _contentController.text += text;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subjects = context.watch<AppState>().subjects;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Flashnote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () => AttachmentsPanel.show(
              context,
              resourceType: 'notes',
              resourceId: widget.note.id,
            ),
            tooltip: 'Attachments',
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            onPressed: _saving ? null : _save,
            tooltip: 'Save',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(
                color: colors.textMain,
                fontFamily: 'serif',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Untitled flashnote',
                hintStyle: TextStyle(
                  color: colors.textDim,
                  fontFamily: 'serif',
                  fontSize: 26,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: subjects.any((s) => s.id == _subjectId)
                        ? _subjectId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Linked subject',
                      prefixIcon: Icon(Icons.book_outlined, size: 18),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No subject'),
                      ),
                      for (final subject in subjects)
                        DropdownMenuItem(
                          value: subject.id,
                          child: Text('${subject.code} · ${subject.title}'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _subjectId = value),
                  ),
                ),
                const SizedBox(width: 10),
                V2Badge(
                  widget.note.tags?.isNotEmpty == true
                      ? widget.note.tags!
                      : 'no tags',
                  color: colors.textMuted,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Tool(
                      icon: Icons.format_bold,
                      tooltip: 'Bold',
                      active: _isBold,
                      onPressed: _toggleBold,
                    ),
                    _Tool(
                      icon: Icons.format_italic,
                      tooltip: 'Italic',
                      active: _isItalic,
                      onPressed: _toggleItalic,
                    ),
                    _Tool(
                      icon: Icons.format_underline,
                      tooltip: 'Underline',
                      active: _isUnderline,
                      onPressed: _toggleUnderline,
                    ),
                    Container(width: 1, height: 20, color: colors.border),
                    _Tool(
                      icon: Icons.text_decrease,
                      tooltip: 'Smaller',
                      onPressed: _decreaseFont,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${_fontSize.toInt()}',
                        style: TextStyle(color: colors.textMuted, fontSize: 11),
                      ),
                    ),
                    _Tool(
                      icon: Icons.text_increase,
                      tooltip: 'Larger',
                      onPressed: _increaseFont,
                    ),
                    Container(width: 1, height: 20, color: colors.border),
                    _Tool(
                      icon: Icons.format_list_bulleted,
                      tooltip: 'Bullet',
                      onPressed: () => _insert('\n• '),
                    ),
                    _Tool(
                      icon: Icons.format_list_numbered,
                      tooltip: 'Numbered',
                      onPressed: () => _insert('\n1. '),
                    ),
                    _Tool(
                      icon: Icons.short_text,
                      tooltip: 'Divider',
                      onPressed: () => _insert('\n---\n'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  style: _getTextStyle(context),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Start writing your notes…',
                    hintStyle: TextStyle(
                      color: colors.textDim,
                      fontSize: _fontSize,
                    ),
                  ),
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),
            const SizedBox(height: 10),
            PillButton(
              label: _saving ? 'Saving…' : 'Save flashnote',
              icon: Icons.save_outlined,
              tone: colors.primary,
              expand: true,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: active ? colors.primary : colors.textMuted,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
