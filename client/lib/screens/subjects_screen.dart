import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/v2_kit.dart';

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
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Subject subject) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${subject.code}?'),
        content: const Text(
          'This also removes its schedule and attendance records.',
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
    if (ok != true || !context.mounted) return;
    try {
      await context.read<AppState>().removeSubject(subject.id);
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final subjects = context.watch<AppState>().subjects;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Subjects'),
        actions: [
          IconButton(
            tooltip: 'Add subject',
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: context.read<AppState>().refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            v2Centered(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeading(
                    title: 'Course catalogue',
                    subtitle:
                        '${subjects.length} enrolled · ${subjects.fold<int>(0, (sum, s) => sum + s.units)} units',
                    trailing: PillButton(
                      label: 'Add subject',
                      icon: Icons.add,
                      tone: colors.primary,
                      dense: true,
                      onPressed: () => _openForm(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (subjects.isEmpty)
                    V2Empty(
                      icon: Icons.menu_book_outlined,
                      title: 'No subjects yet',
                      message: 'Add your courses to unlock timetables, attendance, and GPA tracking.',
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final two = constraints.maxWidth >= 760;
                        final width = two
                            ? (constraints.maxWidth - 10) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final subject in subjects)
                              SizedBox(
                                width: width,
                                child: _SubjectCard(
                                  subject: subject,
                                  onEdit: () =>
                                      _openForm(context, existing: subject),
                                  onDelete: () =>
                                      _confirmDelete(context, subject),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        tooltip: 'Add subject',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.onEdit,
    required this.onDelete,
  });

  final Subject subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = hexToColor(subject.color);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  subject.code.isEmpty ? '?' : subject.code[0],
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.code,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subject.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              V2Badge('${subject.units} units', color: color, dense: true),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, size: 18, color: colors.textDim),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 9),
          _Meta(
            icon: Icons.person_outline,
            text: subject.instructor ?? 'No instructor',
          ),
          _Meta(
            icon: Icons.mail_outline,
            text: subject.instructorEmail ?? 'No email',
          ),
          _Meta(
            icon: Icons.schedule,
            text: subject.officeHours ?? 'No office hours',
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: colors.textDim),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 10.5),
            ),
          ),
        ],
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
    this.units = 0,
    this.color = '#4F46E5',
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
    '#A51C30',
    '#C08A2E',
    '#53C99A',
    '#4C9FD6',
    '#8B6BB8',
    '#D45A68',
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
        units: int.tryParse(_units.text.trim()) ?? 0,
        color: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                decoration: const InputDecoration(
                  labelText: 'Code (e.g. CS101)',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _instructor,
                decoration: const InputDecoration(labelText: 'Instructor'),
              ),
              TextFormField(
                controller: _instructorEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Instructor email',
                ),
              ),
              TextFormField(
                controller: _officeHours,
                decoration: const InputDecoration(labelText: 'Office hours'),
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
                              ? Border.all(color: colors.textMain, width: 3)
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
