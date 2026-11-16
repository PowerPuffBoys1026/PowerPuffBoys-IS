import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/grade.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../state/grades_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/v2_kit.dart';
import 'subjects_screen.dart';

class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  Future<void> _openForm(
    BuildContext context, {
    GradeComponent? existing,
  }) async {
    final subjects = context.read<AppState>().subjects;
    if (subjects.isEmpty) {
      _toast(context, 'Add a subject first.');
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
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _delete(BuildContext context, GradeComponent grade) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${grade.componentName}?'),
        content: const Text('The component moves to the recycle bin.'),
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
      await context.read<GradesState>().remove(grade.id);
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _setTarget(
    BuildContext context,
    SubjectGradeSummary subject,
    double target,
  ) async {
    final grades = context.read<GradesState>();
    try {
      for (final component in subject.components) {
        await grades.update(component.id, targetPct: target);
      }
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
    final state = context.watch<GradesState>();
    final subjects = context.watch<AppState>().subjects;
    final summary = state.summary;

    if (state.loading && summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasGrades = summary != null && summary.subjects.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: state.load,
        child: ListView(
          padding: v2PagePadding(context),
          children: [
            v2Centered(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.error != null) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, size: 18),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: state.load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _GpaHero(summary: summary),
                  const SizedBox(height: 16),
                  SectionHeading(
                    title: 'Courses & grades',
                    subtitle: 'Weighted components, target solver, and letter standing.',
                    trailing: subjects.isEmpty
                        ? PillButton(
                            label: 'Add subject',
                            icon: Icons.add,
                            tone: context.colors.primary,
                            dense: true,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SubjectsScreen(),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  if (subjects.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PillButton(
                          label: 'Manage subjects',
                          icon: Icons.menu_book_outlined,
                          dense: true,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SubjectsScreen(),
                            ),
                          ),
                        ),
                        PillButton(
                          label: 'Add component',
                          icon: Icons.add,
                          tone: context.colors.primary,
                          dense: true,
                          onPressed: () => _openForm(context),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (!hasGrades)
                    V2Empty(
                      icon: Icons.grading_outlined,
                      title: 'No grade components yet',
                      message: subjects.isEmpty
                          ? 'Add subjects, then track weighted components here.'
                          : 'Tap “Add component” to start tracking your grades.',
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final two = constraints.maxWidth >= 980;
                        final cards = [
                          for (final subject in summary.subjects)
                            _SubjectGradeCard(
                              subject: subject,
                              onEdit: (grade) =>
                                  _openForm(context, existing: grade),
                              onDelete: (grade) => _delete(context, grade),
                              onTarget: (target) =>
                                  _setTarget(context, subject, target),
                            ),
                        ];
                        if (!two) {
                          return Column(
                            children: [
                              for (final card in cards) ...[
                                card,
                                const SizedBox(height: 10),
                              ],
                            ],
                          );
                        }
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final card in cards)
                              SizedBox(
                                width: (constraints.maxWidth - 12) / 2,
                                child: card,
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
      floatingActionButton: subjects.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openForm(context),
              tooltip: 'Add component',
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _GpaHero extends StatelessWidget {
  const _GpaHero({required this.summary});

  final GradeSummary? summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gpa = summary?.cumulativeGpa;
    final tone = (gpa ?? 0) >= 3.5
        ? colors.emerald
        : (gpa ?? 0) >= 2.5
        ? colors.amber
        : colors.rose;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.isDark
              ? const [Color(0xFF1B2A2C), Color(0xFF251318)]
              : const [Color(0xFFF7F1E8), Color(0xFFEFE1DE)],
        ),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final score = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CUMULATIVE GPA',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    gpa == null ? '—' : gpa.toStringAsFixed(2),
                    style: TextStyle(
                      color: colors.textMain,
                      fontFamily: 'serif',
                      fontSize: compact ? 46 : 58,
                      height: 0.95,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      '/ 4.00',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                summary?.academicStanding ?? 'No graded components yet',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          );
          final stats = Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _HeroStat(
                label: 'Units counted',
                value: '${summary?.totalUnitsCounted ?? 0}',
              ),
              _HeroStat(
                label: 'Subjects',
                value: '${summary?.subjects.length ?? 0}',
              ),
              _HeroStat(
                label: 'Standing',
                value: summary?.academicStanding ?? '—',
                tone: tone,
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [score, const SizedBox(height: 14), stats],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: score),
              stats,
            ],
          );
        },
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: tone ?? colors.textMain,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: TextStyle(color: colors.textDim, fontSize: 9.5)),
      ],
    );
  }
}

class _SubjectGradeCard extends StatefulWidget {
  const _SubjectGradeCard({
    required this.subject,
    required this.onEdit,
    required this.onDelete,
    required this.onTarget,
  });

  final SubjectGradeSummary subject;
  final void Function(GradeComponent) onEdit;
  final void Function(GradeComponent) onDelete;
  final ValueChanged<double> onTarget;

  @override
  State<_SubjectGradeCard> createState() => _SubjectGradeCardState();
}

class _SubjectGradeCardState extends State<_SubjectGradeCard> {
  late double _target;

  @override
  void initState() {
    super.initState();
    _target = widget.subject.targetPercentage.clamp(60, 100).toDouble();
  }

  @override
  void didUpdateWidget(covariant _SubjectGradeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subject.targetPercentage != widget.subject.targetPercentage) {
      _target = widget.subject.targetPercentage.clamp(60, 100).toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final state = context.read<GradesState>();
    final colors = context.colors;
    final pct = subject.currentPercentage;
    final color = hexToColor(subject.color);
    final tone = pct == null
        ? colors.textMuted
        : pct >= 85
        ? colors.emerald
        : pct >= 75
        ? colors.amber
        : colors.rose;

    GradeComponent? findGrade(int id) {
      for (final grade in state.grades) {
        if (grade.id == id) return grade;
      }
      return null;
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      '${subject.code} • ${subject.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${subject.componentsCount} components · ${subject.units} units',
                      style: TextStyle(color: colors.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    pct == null ? '—' : '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: tone,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  V2Badge(
                    subject.gpa == null
                        ? subject.letterGrade
                        : '${subject.letterGrade} · ${subject.gpa!.toStringAsFixed(2)}',
                    color: tone,
                    dense: true,
                  ),
                ],
              ),
            ],
          ),
          if (pct != null) ...[
            const SizedBox(height: 11),
            V2ProgressBar(
              value: (pct / 100).clamp(0, 1),
              color: tone,
              height: 6,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            subject.remainingWeight <= 0
                ? 'All weight graded. Final letter depends on the components above.'
                : subject.neededOnRemaining == null
                ? '${subject.remainingWeight.toStringAsFixed(0)}% of the grade is still ungraded.'
                : 'Need ${subject.neededOnRemaining!.toStringAsFixed(1)}% on the remaining '
                      '${subject.remainingWeight.toStringAsFixed(0)}% to hit ${_target.toStringAsFixed(0)}%.',
            style: TextStyle(
              color:
                  subject.neededOnRemaining != null &&
                      subject.neededOnRemaining! > 100
                  ? colors.rose
                  : colors.textMuted,
              fontSize: 10.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Target grade',
                style: TextStyle(
                  color: colors.textDim,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              Text(
                '${_target.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: color,
              thumbColor: color,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: _target,
              min: 60,
              max: 100,
              divisions: 40,
              label: '${_target.toStringAsFixed(0)}%',
              onChanged: (value) => setState(() => _target = value),
              onChangeEnd: widget.onTarget,
            ),
          ),
          const Divider(height: 16),
          if (subject.components.isEmpty)
            Text(
              'No components yet.',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            )
          else
            for (final component in subject.components)
              _ComponentRow(
                component: component,
                grade: findGrade(component.id),
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              ),
        ],
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
    final colors = context.colors;
    final g = grade;
    final score = component.scorePct;
    return InkWell(
      onTap: g == null ? null : () => onEdit(g),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: score == null ? colors.textDim : colors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                component.componentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMain,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${component.weightPct.toStringAsFixed(0)}%',
              style: TextStyle(color: colors.textDim, fontSize: 10),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 52,
              child: Text(
                score == null ? 'ungraded' : '${score.toStringAsFixed(1)}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: score == null ? colors.textDim : colors.textMain,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (g != null)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, size: 17, color: colors.textDim),
                onSelected: (value) {
                  if (value == 'edit') onEdit(g);
                  if (value == 'delete') onDelete(g);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            else
              const SizedBox(width: 30),
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
    _weight = TextEditingController(
      text: e == null ? '20' : e.weightPct.toString(),
    );
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
    if (value == null || value.trim().isEmpty) {
      return required ? 'Required' : null;
    }
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
        scorePct: _score.text.trim().isEmpty
            ? null
            : double.parse(_score.text.trim()),
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
                    DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.code} · ${s.title}'),
                    ),
                ],
                onChanged: editing
                    ? null
                    : (v) => setState(() => _subjectId = v!),
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Component name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Weight %'),
                validator: (v) => _validatePercent(v),
              ),
              TextFormField(
                controller: _score,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Score % (optional)',
                ),
                validator: (v) => _validatePercent(v, required: false),
              ),
              TextFormField(
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Target %'),
                validator: (v) => _validatePercent(v),
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
