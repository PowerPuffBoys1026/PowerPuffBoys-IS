import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/attendance.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'grades_dialog.dart';
import 'notes_dialog.dart';

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
          instructorEmail: result.instructorEmail,
          officeHours: result.officeHours,
          units: result.units,
          color: result.color,
        );
      } else {
        await app.editSubject(
          existing.id,
          code: result.code,
          title: result.title,
          instructor: result.instructor,
          instructorEmail: result.instructorEmail,
          officeHours: result.officeHours,
          units: result.units,
          color: result.color,
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Subject subject) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${subject.code}?'),
        content: const Text(
          'This also removes its timetable schedule and attendance records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<AppState>().removeSubject(subject.id);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final subjects = app.subjects;
    final summary = app.summary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: subjects.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: PortalColors.primary.withAlpha(24),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      size: 48,
                      color: PortalColors.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'No enrolled courses yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap "+ Course" below to add your subjects, instructors, and units.',
                    style: TextStyle(fontSize: 13, color: PortalColors.muted),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Enrolled Courses',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.tonalIcon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => const GradesDialog(),
                              ),
                              icon: const Icon(Icons.calculate_outlined,
                                  size: 18),
                              label: const Text('GPA Calculator'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (final s in subjects) ...[
                          _SubjectCard(
                            subject: s,
                            attendance: summary.firstWhere(
                              (item) => item.subjectId == s.id,
                              orElse: () => AttendanceSummary(
                                subjectId: s.id,
                                code: s.code,
                                title: s.title,
                                color: s.color,
                                present: 0,
                                absent: 0,
                                late: 0,
                                cancelled: 0,
                                counted: 0,
                              ),
                            ),
                            isDark: isDark,
                            onEdit: () => _openForm(context, existing: s),
                            onDelete: () => _confirmDelete(context, s),
                            onNotes: () => showDialog(
                              context: context,
                              builder: (_) =>
                                  NotesDialog(initialSubjectId: s.id),
                            ),
                            onGrades: () => showDialog(
                              context: context,
                              builder: (_) => const GradesDialog(),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'subjects-add-subject',
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Course'),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.attendance,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onNotes,
    required this.onGrades,
  });

  final Subject subject;
  final AttendanceSummary attendance;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onNotes;
  final VoidCallback onGrades;

  @override
  Widget build(BuildContext context) {
    final s = subject;
    final color = hexToColor(s.color);

    return Card(
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  radius: 20,
                  child: Text(
                    s.code.isNotEmpty ? s.code[0] : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s.code,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withAlpha(24),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${s.units} Units',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Instructor & Office hours info
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                if (s.instructor != null && s.instructor!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: PortalColors.muted),
                      const SizedBox(width: 5),
                      Text(
                        s.instructor!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PortalColors.muted,
                        ),
                      ),
                    ],
                  ),
                if (s.instructorEmail != null && s.instructorEmail!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mail_outline,
                          size: 16, color: PortalColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        s.instructorEmail!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PortalColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                if (s.officeHours != null && s.officeHours!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule,
                          size: 16, color: PortalColors.muted),
                      const SizedBox(width: 5),
                      Text(
                        'Office: ${s.officeHours!}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PortalColors.muted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick Tool Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onNotes,
                  icon: const Icon(Icons.note_alt_outlined, size: 16),
                  label: const Text('Flashnotes'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onGrades,
                  icon: const Icon(Icons.calculate_outlined, size: 16),
                  label: const Text('Target Solver'),
                ),
                const Spacer(),
                if (attendance.attendanceRate != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: attendance.warning
                          ? const Color(0xFFEF4444).withAlpha(20)
                          : PortalColors.emerald.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${attendance.attendanceRate}% Attendance',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: attendance.warning
                            ? const Color(0xFFEF4444)
                            : PortalColors.emerald,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectFormResult {
  const _SubjectFormResult({
    required this.code,
    required this.title,
    this.instructor,
    this.instructorEmail,
    this.officeHours,
    this.units = 3,
    this.color = '#6366F1',
  });
  final String code;
  final String title;
  final String? instructor;
  final String? instructorEmail;
  final String? officeHours;
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
  late final TextEditingController _instructorEmail;
  late final TextEditingController _officeHours;
  late final TextEditingController _units;
  late String _color;

  static const _palette = [
    '#6366F1', // Electric Indigo
    '#0EA5E9', // Sky Cyan
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#F43F5E', // Rose
    '#8B5CF6', // Neon Violet
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?.code ?? '');
    _title = TextEditingController(text: e?.title ?? '');
    _instructor = TextEditingController(text: e?.instructor ?? '');
    _instructorEmail = TextEditingController(text: e?.instructorEmail ?? '');
    _officeHours = TextEditingController(text: e?.officeHours ?? '');
    _units = TextEditingController(text: (e?.units ?? 3).toString());
    _color = e?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _instructor.dispose();
    _instructorEmail.dispose();
    _officeHours.dispose();
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
        instructorEmail: _instructorEmail.text.trim(),
        officeHours: _officeHours.text.trim(),
        units: int.tryParse(_units.text.trim()) ?? 3,
        color: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.existing == null ? 'Add Course' : 'Edit Course'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Course Code (e.g. CS101, MATH201)',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Course Title',
                  hintText: 'e.g. Discrete Mathematics',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _units,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Units / Credits',
                        hintText: '3',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _instructor,
                      decoration: const InputDecoration(
                        labelText: 'Instructor Name',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructorEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Instructor Email (optional)',
                  hintText: 'prof@university.edu',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _officeHours,
                decoration: const InputDecoration(
                  labelText: 'Office Hours (optional)',
                  hintText: 'Mon & Wed 2-4 PM',
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Course Color Badge',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (final c in _palette)
                    InkWell(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hexToColor(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: _color == c
                              ? [
                                  BoxShadow(
                                    color: hexToColor(c).withAlpha(120),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: _color == c
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
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
        FilledButton(onPressed: _save, child: const Text('Save Course')),
      ],
    );
  }
}
