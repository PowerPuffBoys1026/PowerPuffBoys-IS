import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/school_work.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class WorksScreen extends StatefulWidget {
  const WorksScreen({super.key});

  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  String _filter = 'all';
  String _typeFilter = 'all';
  String _search = '';

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
        await app.editWork(
          existing.id,
          title: result.title,
          subjectId: result.subjectId,
          type: result.type,
          dueAt: result.dueAt,
          priority: result.priority,
          status: existing.status,
          notes: result.notes,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _toggleDone(SchoolWork work) async {
    final nextStatus = work.status == 'done' ? 'todo' : 'done';
    try {
      await context.read<AppState>().setWorkStatus(work.id, nextStatus);
      if (mounted && nextStatus == 'done') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completed "${work.title}"! 🎉 Great work!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _changeStatus(SchoolWork work, String status) async {
    try {
      await context.read<AppState>().setWorkStatus(work.id, status);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(SchoolWork work) async {
    try {
      await context.read<AppState>().removeWork(work.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppState>().works;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final works = all.where((w) {
      if (_filter != 'all' && w.status != _filter) return false;
      if (_typeFilter != 'all' && w.type != _typeFilter) return false;
      if (_search.isNotEmpty &&
          !w.title.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    final todoCount = all.where((w) => w.status == 'todo').length;
    final doingCount = all.where((w) => w.status == 'doing').length;
    final doneCount = all.where((w) => w.status == 'done').length;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search & Quick Counters Strip
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search, size: 20),
                            hintText: 'Search tasks, quizzes, exams...',
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _search = val),
                        ),
                      ),
                      const SizedBox(width: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('New Task'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter Pills (Status)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChipPill(
                          label: 'All (${all.length})',
                          isSelected: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipPill(
                          label: 'To Do ($todoCount)',
                          isSelected: _filter == 'todo',
                          onTap: () => setState(() => _filter = 'todo'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipPill(
                          label: 'In Progress ($doingCount)',
                          isSelected: _filter == 'doing',
                          onTap: () => setState(() => _filter = 'doing'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipPill(
                          label: 'Done ($doneCount)',
                          isSelected: _filter == 'done',
                          onTap: () => setState(() => _filter = 'done'),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 1,
                          height: 22,
                          color: isDark
                              ? PortalColors.lineDark
                              : PortalColors.lineLight,
                        ),
                        const SizedBox(width: 16),
                        // Type Pills
                        for (final type in [
                          'all',
                          'assignment',
                          'quiz',
                          'exam',
                          'project'
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(type == 'all'
                                  ? 'All Types'
                                  : type[0].toUpperCase() + type.substring(1)),
                              selected: _typeFilter == type,
                              onSelected: (_) =>
                                  setState(() => _typeFilter = type),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Tasks List
                  if (works.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.task_alt_outlined,
                                size: 52,
                                color: PortalColors.muted,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No matching school works found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap "New Task" to track upcoming assignments, quizzes, and exams.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PortalColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    for (final w in works) ...[
                      _WorkCardItem(
                        work: w,
                        isDark: isDark,
                        onToggleDone: () => _toggleDone(w),
                        onEdit: () => _openForm(existing: w),
                        onDelete: () => _delete(w),
                        onStatusChange: (status) => _changeStatus(w, status),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? PortalColors.primary
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? PortalColors.mutedDark : PortalColors.mutedLight),
          ),
        ),
      ),
    );
  }
}

class _WorkCardItem extends StatelessWidget {
  const _WorkCardItem({
    required this.work,
    required this.isDark,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  final SchoolWork work;
  final bool isDark;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChange;

  @override
  Widget build(BuildContext context) {
    final isDone = work.status == 'done';
    final subjectColor = hexToColor(work.color);

    return Card(
      elevation: isDone ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Checkbox satisfaction button
            IconButton(
              iconSize: 24,
              onPressed: onToggleDone,
              icon: Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone ? PortalColors.emerald : PortalColors.muted,
              ),
            ),
            const SizedBox(width: 8),

            // Main Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (work.subjectCode != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: subjectColor.withAlpha(24),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            work.subjectCode!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: subjectColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _PriorityBadge(priority: work.priority),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    work.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? PortalColors.muted : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _typeIcon(work.type),
                        size: 14,
                        color: PortalColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        work.type[0].toUpperCase() + work.type.substring(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: PortalColors.muted,
                        ),
                      ),
                      if (work.dueAt != null) ...[
                        const Text('  ·  ',
                            style: TextStyle(color: PortalColors.muted)),
                        Text(
                          dueLabel(work.dueAt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _dueColor(work.dueAt),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (work.notes != null && work.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      work.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? PortalColors.mutedDark
                            : PortalColors.mutedLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions popup menu
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  onEdit();
                } else if (val == 'delete') onDelete();
                else onStatusChange(val);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: isDone ? 'todo' : 'done',
                  child: Text(isDone ? 'Mark as To do' : 'Mark as Done'),
                ),
                if (!isDone && work.status != 'doing')
                  const PopupMenuItem(
                    value: 'doing',
                    child: Text('Mark as In Progress'),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _typeIcon(String type) => switch (type) {
        'quiz' => Icons.quiz_outlined,
        'exam' => Icons.school_outlined,
        'project' => Icons.science_outlined,
        _ => Icons.assignment_outlined,
      };

  static Color _dueColor(DateTime? dueAt) {
    if (dueAt == null) return PortalColors.muted;
    final diff = dueAt.difference(DateTime.now()).inHours;
    if (diff < 0) return const Color(0xFFEF4444); // overdue
    if (diff <= 24) return Colors.deepOrange; // due today/soon
    if (diff <= 72) return Colors.amber[800]!; // due in 3 days
    return PortalColors.primary;
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      'high' => ('Urgent 🔥', const Color(0xFFEF4444)),
      'low' => ('Low', PortalColors.cyan),
      _ => ('Medium', Colors.amber[800]!),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
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
  int? _subjectId;
  String _type = 'assignment';
  String _priority = 'medium';
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    final work = widget.existing;
    _title = TextEditingController(text: work?.title ?? '');
    _notes = TextEditingController(text: work?.notes ?? '');
    _subjectId = work?.subjectId;
    _type = work?.type ?? 'assignment';
    _priority = work?.priority ?? 'medium';
    _dueAt = work?.dueAt;
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
    if (date == null || !mounted) return;
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
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.existing == null ? 'Add School Work' : 'Edit School Work',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title / Task Name',
                  hintText: 'e.g. Lab Exercise 2, Chapter 4 Quiz',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _subjectId,
                decoration: const InputDecoration(labelText: 'Course'),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'assignment',
                          child: Text('Assignment'),
                        ),
                        DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                        DropdownMenuItem(value: 'exam', child: Text('Exam')),
                        DropdownMenuItem(
                          value: 'project',
                          child: Text('Project'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('Urgent 🔥')),
                      ],
                      onChanged: (v) => setState(() => _priority = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event, color: PortalColors.primary),
                title: const Text('Due Date & Time'),
                subtitle: Text(
                  _dueAt == null ? 'No due date set' : dueLabel(_dueAt),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: _dueAt == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _dueAt = null),
                      ),
                onTap: _pickDue,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes & Instructions',
                  hintText: 'e.g. Upload PDF to portal by 11:59pm',
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
        FilledButton(onPressed: _save, child: const Text('Save Work')),
      ],
    );
  }
}
