import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  Future<void> _openForm(BuildContext context, {Subject? existing}) async {
    final result = await showDialog<_SubjectFormResult>(
      context: context,
      builder: (_) => _SubjectFormDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;
    final app = context.read<AppState>();
    try {
      if (existing == null) {
        await app.addSubject(
          code: result.code,
          title: result.title,
          instructor: result.instructor,
          units: result.units,
          color: result.color,
        );
      } else {
        await app.editSubject(
          existing.id,
          code: result.code,
          title: result.title,
          instructor: result.instructor,
          units: result.units,
          color: result.color,
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Subject subject) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${subject.code}?'),
        content: const Text('This also removes its schedule and attendance records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<AppState>().removeSubject(subject.id);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = context.watch<AppState>().subjects;
    return Scaffold(
      body: subjects.isEmpty
          ? const Center(child: Text('No subjects yet. Tap + to add one.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final s in subjects)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: hexToColor(s.color),
                        child: Text(s.code.isEmpty ? '?' : s.code[0], style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text('${s.code} · ${s.title}'),
                      subtitle: Text('${s.instructor ?? 'No instructor'} · ${s.units} units'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openForm(context, existing: s);
                          if (value == 'delete') _confirmDelete(context, s);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Subject'),
      ),
    );
  }
}

class _SubjectFormResult {
  const _SubjectFormResult({
    required this.code,
    required this.title,
    this.instructor,
    this.units = 0,
    this.color = '#4F46E5',
  });
  final String code;
  final String title;
  final String? instructor;
  final int units;
  final String color;
}

class _SubjectFormDialog extends StatefulWidget {
  const _SubjectFormDialog({this.existing});
  final Subject? existing;

  @override
  State<_SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends State<_SubjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _instructor;
  late final TextEditingController _units;
  late String _color;

  static const _palette = ['#4F46E5', '#0EA5E9', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?.code ?? '');
    _title = TextEditingController(text: e?.title ?? '');
    _instructor = TextEditingController(text: e?.instructor ?? '');
    _units = TextEditingController(text: (e?.units ?? 3).toString());
    _color = e?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _instructor.dispose();
    _units.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SubjectFormResult(
        code: _code.text.trim(),
        title: _title.text.trim(),
        instructor: _instructor.text.trim(),
        units: int.tryParse(_units.text.trim()) ?? 0,
        color: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add subject' : 'Edit subject'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Code (e.g. CS101)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _instructor,
                decoration: const InputDecoration(labelText: 'Instructor'),
              ),
              TextFormField(
                controller: _units,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Units'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final color in _palette)
                    GestureDetector(
                      onTap: () => setState(() => _color = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hexToColor(color),
                          shape: BoxShape.circle,
                          border: _color == color
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
