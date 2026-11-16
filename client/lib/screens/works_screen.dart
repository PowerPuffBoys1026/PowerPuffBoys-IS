import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/school_work.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/attachments_panel.dart';
import '../widgets/v2_kit.dart';

class WorksScreen extends StatefulWidget {
  const WorksScreen({super.key});

  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm({SchoolWork? existing}) async {
    final app = context.read<AppState>();
    final result = await showDialog<_WorkFormResult>(
      context: context,
      builder: (_) =>
          _WorkFormDialog(subjects: app.subjects, existing: existing),
    );
    if (result == null || !mounted) return;
    try {
      if (existing == null) {
        await app.addWork(
          title: result.title,
          subjectId: result.subjectId,
          type: result.type,
          dueAt: result.dueAt,
          priority: result.priority,
          notes: result.notes,
        );
      } else {
        final notes = result.notes?.trim() ?? '';
        await app.editWork(
          existing.id,
          title: result.title,
          subjectId: result.subjectId,
          clearSubject: result.subjectId == null,
          type: result.type,
          dueAt: result.dueAt,
          clearDueAt: result.dueAt == null,
          priority: result.priority,
          notes: notes,
          clearNotes: notes.isEmpty,
        );
      }
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _openAttachments(SchoolWork work) {
    return AttachmentsPanel.show(
      context,
      resourceType: 'works',
      resourceId: work.id,
    );
  }

  Future<void> _changeStatus(SchoolWork work, String status) async {
    try {
      await context.read<AppState>().setWorkStatus(work.id, status);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _delete(SchoolWork work) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete “${work.title}”?'),
        content: const Text(
          'This task and its attachments move to the recycle bin.',
        ),
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
    if (ok != true || !mounted) return;
    try {
      await context.read<AppState>().removeWork(work.id);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<SchoolWork> _visible(List<SchoolWork> all) {
    final query = _search.text.trim().toLowerCase();
    return all.where((w) {
      if (_filter != 'all' && w.status != _filter) return false;
      if (query.isEmpty) return true;
      return w.title.toLowerCase().contains(query) ||
          (w.subjectCode ?? '').toLowerCase().contains(query) ||
          (w.notes ?? '').toLowerCase().contains(query);
    }).toList()..sort(_compare);
  }

  static int _compare(SchoolWork a, SchoolWork b) {
    if (a.status == 'done' && b.status != 'done') return 1;
    if (b.status == 'done' && a.status != 'done') return -1;
    final ad = a.dueAt;
    final bd = b.dueAt;
    if (ad == null && bd != null) return 1;
    if (bd == null && ad != null) return -1;
    if (ad != null && bd != null) return ad.compareTo(bd);
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.works;
    final works = _visible(all);
    final counts = {
      'all': all.length,
      'todo': all.where((w) => w.status == 'todo').length,
      'doing': all.where((w) => w.status == 'doing').length,
      'done': all.where((w) => w.status == 'done').length,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: app.refreshAll,
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
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search tasks, subjects, notes…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                ),
                          isDense: true,
                        ),
                      );
                      final add = PillButton(
                        label: 'New task',
                        icon: Icons.add,
                        tone: context.colors.primary,
                        onPressed: () => _openForm(),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const {
                        'all': 'All',
                        'todo': 'To do',
                        'doing': 'Doing',
                        'done': 'Done',
                      }.entries)
                        PillButton(
                          label: '${entry.value} · ${counts[entry.key] ?? 0}',
                          icon: switch (entry.key) {
                            'todo' => Icons.radio_button_unchecked,
                            'doing' => Icons.timelapse,
                            'done' => Icons.check_circle_outline,
                            _ => Icons.layers_outlined,
                          },
                          selected: _filter == entry.key,
                          dense: true,
                          onPressed: () => setState(() => _filter = entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (works.isEmpty)
                    V2Empty(
                      icon: Icons.task_alt,
                      title: _search.text.isEmpty
                          ? 'No tasks here'
                          : 'No matches',
                      message: _search.text.isEmpty
                          ? 'Add an assignment, quiz, exam, or project to start planning.'
                          : 'Try another keyword or status filter.',
                    )
                  else
                    for (final work in works)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _WorkCard(
                          work: work,
                          onToggle: () => _changeStatus(
                            work,
                            work.status == 'done' ? 'todo' : 'done',
                          ),
                          onEdit: () => _openForm(existing: work),
                          onAttachments: () => _openAttachments(work),
                          onDelete: () => _delete(work),
                          onStatus: (status) => _changeStatus(work, status),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'New task',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({
    required this.work,
    required this.onToggle,
    required this.onEdit,
    required this.onAttachments,
    required this.onDelete,
    required this.onStatus,
  });

  final SchoolWork work;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onAttachments;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatus;

  static IconData _typeIcon(String type) => switch (type) {
    'quiz' => Icons.quiz_outlined,
    'exam' => Icons.school_outlined,
    'project' => Icons.science_outlined,
    _ => Icons.assignment_outlined,
  };

  bool get _overdue =>
      work.status != 'done' &&
      work.dueAt != null &&
      work.dueAt!.isBefore(DateTime.now());

  bool get _dueToday {
    final d = work.dueAt;
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = hexToColor(work.color);
    final done = work.status == 'done';
    final priorityColor = switch (work.priority) {
      'high' => colors.rose,
      'low' => colors.emerald,
      _ => colors.amber,
    };
    final dueColor = _overdue
        ? colors.rose
        : _dueToday
        ? colors.amber
        : colors.textMuted;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      accent: done ? colors.textDim : color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: done ? colors.emerald : colors.textDim,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon(work.type), size: 14, color: color),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        work.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: done ? colors.textMuted : colors.textMain,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((work.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    work.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 10.5),
                  ),
                ],
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (work.subjectCode != null)
                      Text(
                        work.subjectCode!,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      '·',
                      style: TextStyle(color: colors.textDim, fontSize: 10),
                    ),
                    Text(
                      work.type,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '·',
                      style: TextStyle(color: colors.textDim, fontSize: 10),
                    ),
                    Text(
                      dueLabel(work.dueAt),
                      style: TextStyle(
                        color: dueColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    V2Badge(work.priority, color: priorityColor, dense: true),
                    if (work.status == 'doing')
                      V2Badge('doing', color: colors.amber, dense: true),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Task actions',
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert, size: 19, color: colors.textDim),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'attachments':
                  onAttachments();
                case 'delete':
                  onDelete();
                default:
                  onStatus(value);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'attachments', child: Text('Attachments')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'todo', child: Text('Mark as To do')),
              PopupMenuItem(value: 'doing', child: Text('Mark as Doing')),
              PopupMenuItem(value: 'done', child: Text('Mark as Done')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
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
  const _WorkFormDialog({required this.subjects, this.existing});
  final List<Subject> subjects;
  final SchoolWork? existing;

  @override
  State<_WorkFormDialog> createState() => _WorkFormDialogState();
}

class _WorkFormDialogState extends State<_WorkFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late int? _subjectId;
  late String _type;
  late String _priority;
  late DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _subjectId = e?.subjectId;
    _type = e?.type ?? 'assignment';
    _priority = e?.priority ?? 'medium';
    _dueAt = e?.dueAt;
  }

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
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (!mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
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
      title: Text(
        widget.existing == null ? 'Add school work' : 'Edit school work',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              DropdownButtonFormField<int?>(
                initialValue: _subjectId,
                decoration: const InputDecoration(
                  labelText: 'Subject (optional)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('General')),
                  for (final s in widget.subjects)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.code} · ${s.title}'),
                    ),
                ],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'assignment',
                    child: Text('Assignment'),
                  ),
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
                subtitle: Text(
                  _dueAt == null ? 'No due date' : dueLabel(_dueAt),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
