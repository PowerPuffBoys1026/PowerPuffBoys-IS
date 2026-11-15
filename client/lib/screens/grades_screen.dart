import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/grade.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../state/grades_state.dart';
import '../utils/format.dart';

class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  Future<void> _openForm(BuildContext context, {GradeComponent? existing}) async {
    final subjects = context.read<AppState>().subjects;
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a subject first.')),
      );
      return;
    }
    final result = await showDialog<_GradeFormResult>(
      context: context,
      builder: (_) => _GradeFormDialog(subjects: subjects, existing: existing),
    );
    if (result == null || !context.mounted) return;
    final grades = context.read<GradesState>();
    try {
      if (existing == null) {
        await grades.create(
          subjectId: result.subjectId,
          componentName: result.componentName,
          weightPct: result.weightPct,
          scorePct: result.scorePct,
          targetPct: result.targetPct,
        );
      } else {
        await grades.update(
          existing.id,
          componentName: result.componentName,
          weightPct: result.weightPct,
          scorePct: result.scorePct,
          clearScore: result.scorePct == null,
          targetPct: result.targetPct,
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(BuildContext context, GradeComponent grade) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${grade.componentName}?'),
        content: const Text('The component moves to the recycle bin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<GradesState>().remove(grade.id);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GradesState>();
    final subjects = context.watch<AppState>().subjects;
    final summary = state.summary;

    if (state.loading && summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: state.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: Text(state.error!),
                  trailing: TextButton(onPressed: state.load, child: const Text('Retry')),
                ),
              ),
            _SummaryCard(summary: summary),
            const SizedBox(height: 16),
            if (summary == null || summary.subjects.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.grading_outlined),
                  title: const Text('No grade components yet'),
                  subtitle: Text(
                    subjects.isEmpty
                        ? 'Add subjects, then track weighted components here.'
                        : 'Tap + to add your first component.',
                  ),
                ),
              )
            else
              for (final subject in summary.subjects) _SubjectGradeCard(
                subject: subject,
                onEdit: (grade) => _openForm(context, existing: grade),
                onDelete: (grade) => _delete(context, grade),
              ),
          ],
        ),
      ),
      floatingActionButton: subjects.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Component'),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final GradeSummary? summary;

  @override
  Widget build(BuildContext context) {
    final gpa = summary?.cumulativeGpa;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cumulative GPA', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              gpa == null ? '—' : gpa.toStringAsFixed(2),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(summary?.academicStanding ?? 'No graded components yet'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${summary?.totalUnitsCounted ?? 0} units counted')),
                Chip(label: Text('${summary?.subjects.length ?? 0} subjects')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectGradeCard extends StatelessWidget {
  const _SubjectGradeCard({
    required this.subject,
    required this.onEdit,
    required this.onDelete,
  });

  final SubjectGradeSummary subject;
  final void Function(GradeComponent) onEdit;
  final void Function(GradeComponent) onDelete;

  static GradeComponent? _findGrade(List<GradeComponent> grades, int id) {
    for (final grade in grades) {
      if (grade.id == id) return grade;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<GradesState>();
    final pct = subject.currentPercentage;
    final components = subject.components;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hexToColor(subject.color),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${subject.code} · ${subject.title}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        components.isEmpty
                            ? 'No components'
                            : '${subject.componentsCount} components · ${subject.units} units',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      pct == null ? '—' : '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      subject.gpa == null
                          ? subject.letterGrade
                          : '${subject.letterGrade} · ${subject.gpa!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (pct / 100).clamp(0, 1),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              subject.remainingWeight <= 0
                  ? 'All weight graded · target ${subject.targetPercentage.toStringAsFixed(0)}%'
                  : subject.neededOnRemaining == null
                      ? '${subject.remainingWeight.toStringAsFixed(0)}% ungraded'
                      : 'Need ${subject.neededOnRemaining!.toStringAsFixed(1)}% on the remaining '
                          '${subject.remainingWeight.toStringAsFixed(0)}% to hit ${subject.targetPercentage.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            for (final component in components)
              _ComponentRow(
                component: component,
                grade: _findGrade(state.grades, component.id),
                onEdit: onEdit,
                onDelete: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    required this.component,
    required this.grade,
    required this.onEdit,
    required this.onDelete,
  });

  final GradeSummaryComponent component;
  final GradeComponent? grade;
  final void Function(GradeComponent) onEdit;
  final void Function(GradeComponent) onDelete;

  @override
  Widget build(BuildContext context) {
    final g = grade;
    return InkWell(
      onTap: g == null ? null : () => onEdit(g),
      onLongPress: g == null ? null : () => onDelete(g),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${component.componentName} · ${component.weightPct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              component.scorePct == null ? 'ungraded' : '${component.scorePct!.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (g != null)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) {
                  if (value == 'edit') onEdit(g);
                  if (value == 'delete') onDelete(g);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GradeFormResult {
  const _GradeFormResult({
    required this.subjectId,
    required this.componentName,
    required this.weightPct,
    required this.targetPct,
    this.scorePct,
  });

  final int subjectId;
  final String componentName;
  final double weightPct;
  final double targetPct;
  final double? scorePct;
}

class _GradeFormDialog extends StatefulWidget {
  const _GradeFormDialog({required this.subjects, this.existing});

  final List<Subject> subjects;
  final GradeComponent? existing;

  @override
  State<_GradeFormDialog> createState() => _GradeFormDialogState();
}

class _GradeFormDialogState extends State<_GradeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _subjectId;
  late final TextEditingController _name;
  late final TextEditingController _weight;
  late final TextEditingController _score;
  late final TextEditingController _target;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _subjectId = e?.subjectId ?? widget.subjects.first.id;
    _name = TextEditingController(text: e?.componentName ?? '');
    _weight = TextEditingController(text: e == null ? '20' : e.weightPct.toString());
    _score = TextEditingController(text: e?.scorePct?.toString() ?? '');
    _target = TextEditingController(text: (e?.targetPct ?? 85).toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _score.dispose();
    _target.dispose();
    super.dispose();
  }

  String? _validatePercent(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) return required ? 'Required' : null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a number';
    if (!required && (parsed < 0 || parsed > 100)) return 'Between 0 and 100';
    if (required && (parsed <= 0 || parsed > 100)) return 'Between 0 and 100';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _GradeFormResult(
        subjectId: _subjectId,
        componentName: _name.text.trim(),
        weightPct: double.parse(_weight.text.trim()),
        scorePct: _score.text.trim().isEmpty ? null : double.parse(_score.text.trim()),
        targetPct: double.parse(_target.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit component' : 'Add component'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _subjectId,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [
                  for (final s in widget.subjects)
                    DropdownMenuItem(value: s.id, child: Text('${s.code} · ${s.title}')),
                ],
                onChanged: editing ? null : (v) => setState(() => _subjectId = v!),
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Component name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight %'),
                validator: (v) => _validatePercent(v),
              ),
              TextFormField(
                controller: _score,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Score % (optional)'),
                validator: (v) => _validatePercent(v, required: false),
              ),
              TextFormField(
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Target %'),
                validator: (v) => _validatePercent(v),
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
