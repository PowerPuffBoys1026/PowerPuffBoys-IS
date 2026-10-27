import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/school_work.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class WorksScreen extends StatefulWidget {
  const WorksScreen({super.key});

  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  String _filter = 'all';

  Future<void> _openForm() async {
    final app = context.read<AppState>();
    final result = await showDialog<_WorkFormResult>(
      context: context,
      builder: (_) => _WorkFormDialog(subjects: app.subjects),
    );
    if (result == null || !mounted) return;
    try {
      await app.addWork(
        title: result.title,
        subjectId: result.subjectId,
        type: result.type,
        dueAt: result.dueAt,
        priority: result.priority,
        notes: result.notes,
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changeStatus(SchoolWork work, String status) async {
    try {
      await context.read<AppState>().setWorkStatus(work.id, status);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(SchoolWork work) async {
    try {
      await context.read<AppState>().removeWork(work.id);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppState>().works;
    final works = _filter == 'all' ? all : all.where((w) => w.status == _filter).toList();

    return Scaffold(
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final entry in const {
                  'all': 'All',
                  'todo': 'To do',
                  'doing': 'Doing',
                  'done': 'Done',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: works.isEmpty
                ? const Center(child: Text('Nothing here. Tap + to add school work.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final w in works)
                        Card(
                          child: ListTile(
                            leading: Icon(_typeIcon(w.type), color: hexToColor(w.color)),
                            title: Text(
                              w.title,
                              style: TextStyle(
                                decoration:
                                    w.status == 'done' ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              '${w.subjectCode ?? 'General'} · ${w.type} · ${dueLabel(w.dueAt)}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _delete(w);
                                } else {
                                  _changeStatus(w, value);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'todo', child: Text('Mark as To do')),
                                const PopupMenuItem(value: 'doing', child: Text('Mark as Doing')),
                                const PopupMenuItem(value: 'done', child: Text('Mark as Done')),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Work'),
      ),
    );
  }

  static IconData _typeIcon(String type) => switch (type) {
        'quiz' => Icons.quiz_outlined,
        'exam' => Icons.school_outlined,
        'project' => Icons.science_outlined,
        _ => Icons.assignment_outlined,
      };
}

class _WorkFormResult {
  const _WorkFormResult({
    required this.title,
    this.subjectId,
    this.type = 'assignment',
    this.dueAt,
    this.priority = 'medium',
    this.notes,
  });
  final String title;
  final int? subjectId;
  final String type;
  final DateTime? dueAt;
  final String priority;
  final String? notes;
}

class _WorkFormDialog extends StatefulWidget {
  const _WorkFormDialog({required this.subjects});
  final List<Subject> subjects;

  @override
  State<_WorkFormDialog> createState() => _WorkFormDialogState();
}

class _WorkFormDialogState extends State<_WorkFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  int? _subjectId;
  String _type = 'assignment';
  String _priority = 'medium';
  DateTime? _dueAt;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 23, minute: 59));
    if (!mounted) return;
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time?.hour ?? 23, time?.minute ?? 59);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _WorkFormResult(
        title: _title.text.trim(),
        subjectId: _subjectId,
        type: _type,
        dueAt: _dueAt,
        priority: _priority,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add school work'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              DropdownButtonFormField<int?>(
                initialValue: _subjectId,
                decoration: const InputDecoration(labelText: 'Subject (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('General')),
                  for (final s in widget.subjects)
                    DropdownMenuItem(value: s.id, child: Text('${s.code} · ${s.title}')),
                ],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'assignment', child: Text('Assignment')),
                  DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                  DropdownMenuItem(value: 'exam', child: Text('Exam')),
                  DropdownMenuItem(value: 'project', child: Text('Project')),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (v) => setState(() => _priority = v!),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Due date'),
                subtitle: Text(_dueAt == null ? 'No due date' : dueLabel(_dueAt)),
                trailing: _dueAt == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _dueAt = null),
                      ),
                onTap: _pickDue,
              ),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
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
