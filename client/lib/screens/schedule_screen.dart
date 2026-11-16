import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/schedule_slot.dart';
import '../models/school_work.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/v2_kit.dart';

/// Weekly timetable with the v2 week/day views and "Your week at a glance".
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _weekOrder = [1, 2, 3, 4, 5, 6, 0];
  String _view = 'week';
  DateTime _day = DateTime.now();

  Future<void> _openForm(BuildContext context, {ScheduleSlot? existing}) async {
    final app = context.read<AppState>();
    if (app.subjects.isEmpty) {
      _toast(context, 'Add a subject first.');
      return;
    }
    final result = await showDialog<_SlotFormResult>(
      context: context,
      builder: (_) =>
          _SlotFormDialog(subjects: app.subjects, existing: existing),
    );
    if (result == null || !context.mounted) return;
    try {
      if (existing == null) {
        await app.addSlot(
          subjectId: result.subjectId,
          dayOfWeek: result.dayOfWeek,
          startTime: result.startTime,
          endTime: result.endTime,
          room: result.room,
          building: result.building,
          modality: result.modality,
          weekPattern: result.weekPattern,
        );
      } else {
        await app.editSlot(
          existing.id,
          subjectId: result.subjectId,
          dayOfWeek: result.dayOfWeek,
          startTime: result.startTime,
          endTime: result.endTime,
          room: result.room,
          building: result.building,
          modality: result.modality,
          weekPattern: result.weekPattern,
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _remove(BuildContext context, ScheduleSlot slot) async {
    try {
      await context.read<AppState>().removeSlot(slot.id);
      if (context.mounted) {
        _toast(context, '${slot.subjectCode} removed from timetable.');
      }
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export(BuildContext context, List<ScheduleSlot> slots) async {
    final buffer = StringBuffer('CLASSMATE TIMETABLE\n\n');
    for (final day in _weekOrder) {
      final daySlots = slots.where((s) => s.dayOfWeek == day).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      if (daySlots.isEmpty) continue;
      buffer.writeln(dayNames[day].toUpperCase());
      for (final s in daySlots) {
        buffer.writeln(
          '  ${formatClock(s.startTime)} - ${formatClock(s.endTime)}  ${s.subjectCode}  '
          '${s.room ?? s.modality ?? ''}',
        );
      }
      buffer.writeln();
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) _toast(context, 'Timetable copied to clipboard.');
  }

  Future<void> _showClassSheet(
    BuildContext context,
    ScheduleSlot slot,
    DateTime date,
  ) {
    final colors = context.colors;
    return showV2Sheet<void>(
      context,
      (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          V2SheetHeader(
            title: '${slot.subjectCode} • ${slot.subjectTitle}',
            subtitle:
                '${formatClock(slot.startTime)} – ${formatClock(slot.endTime)}',
            trailing: IconAction(
              icon: Icons.close,
              compact: true,
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MetaRow(label: 'Day', value: dayNames[slot.dayOfWeek]),
                _MetaRow(
                  label: 'Location',
                  value: [slot.room, slot.building]
                      .whereType<String>()
                      .where((e) => e.isNotEmpty)
                      .join(', ')
                      .ifEmpty('Not set'),
                ),
                _MetaRow(
                  label: 'Modality',
                  value: slot.modality ?? 'Not specified',
                ),
                _MetaRow(
                  label: 'Week',
                  value: slot.weekPattern == 'every'
                      ? 'Every week'
                      : 'Week ${slot.weekPattern.toUpperCase()} only',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        expand: true,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _openForm(context, existing: slot);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PillButton(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        tone: colors.rose,
                        expand: true,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _remove(context, slot);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final dateString =
                        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    try {
                      await context.read<AppState>().markAttendance(
                        subjectId: slot.subjectId,
                        slotId: slot.id,
                        date: dateString,
                        status: 'present',
                      );
                      if (context.mounted) {
                        _toast(context, '${slot.subjectCode} marked present.');
                      }
                    } on ApiException catch (e) {
                      if (context.mounted) _toast(context, e.message);
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Mark present'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final slots = app.slots;
    final works = app.works;

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
                  _WeeklyPlan(slots: slots, works: works),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PillButton(
                        label: 'Week view',
                        icon: Icons.grid_view_outlined,
                        selected: _view == 'week',
                        onPressed: () => setState(() => _view = 'week'),
                      ),
                      PillButton(
                        label: 'Day view',
                        icon: Icons.view_day_outlined,
                        selected: _view == 'day',
                        onPressed: () => setState(() => _view = 'day'),
                      ),
                      PillButton(
                        label: 'Export',
                        icon: Icons.copy_all_outlined,
                        onPressed: () => _export(context, slots),
                      ),
                      PillButton(
                        label: 'Add class',
                        icon: Icons.add,
                        tone: context.colors.primary,
                        onPressed: () => _openForm(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_view == 'week')
                    _WeekGrid(
                      slots: slots,
                      onTap: (slot) =>
                          _showClassSheet(context, slot, DateTime.now()),
                    )
                  else
                    _DayView(
                      date: _day,
                      slots: slots,
                      onPrev: () => setState(
                        () => _day = _day.subtract(const Duration(days: 1)),
                      ),
                      onNext: () => setState(
                        () => _day = _day.add(const Duration(days: 1)),
                      ),
                      onToday: () => setState(() => _day = DateTime.now()),
                      onTap: (slot) => _showClassSheet(context, slot, _day),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        tooltip: 'Add class',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WeeklyPlan extends StatelessWidget {
  const _WeeklyPlan({required this.slots, required this.works});

  final List<ScheduleSlot> slots;
  final List<SchoolWork> works;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).add(Duration(days: i));
      final key = _dateKey(date);
      final daySlots =
          slots.where((s) => s.dayOfWeek == date.weekday % 7).toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
      final dayWorks =
          works
              .where((w) => w.dueAt != null && _dateKey(w.dueAt!) == key)
              .toList()
            ..sort((a, b) => (a.dueAt ?? date).compareTo(b.dueAt ?? date));
      return (date, daySlots, dayWorks);
    });

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            title: 'Your Week at a Glance',
            subtitle: 'Classes and assignment deadlines for the next 7 days.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 480
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in days)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: colors.isDark
                              ? Colors.white.withValues(alpha: 0.025)
                              : colors.bgSecondary.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${dayShortNames[item.$1.weekday % 7]} ${item.$1.day}',
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (item.$2.isEmpty && item.$3.isEmpty)
                              Text(
                                'No events',
                                style: TextStyle(
                                  color: colors.textDim,
                                  fontSize: 10.5,
                                ),
                              )
                            else ...[
                              for (final s in item.$2)
                                _PlanRow(
                                  time: formatClock(s.startTime),
                                  text:
                                      '${s.subjectCode} · ${s.room ?? s.modality ?? 'Class'}',
                                ),
                              for (final w in item.$3)
                                _PlanRow(
                                  time: w.dueAt == null
                                      ? '—'
                                      : _clock(w.dueAt!),
                                  text: w.title,
                                  tone: colors.amber,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _clock(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.time, required this.text, this.tone});

  final String time;
  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              time,
              style: TextStyle(
                color: colors.textDim,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone ?? colors.textMuted,
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.slots, required this.onTap});

  final List<ScheduleSlot> slots;
  final ValueChanged<ScheduleSlot> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 760
            ? 3
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final day in [1, 2, 3, 4, 5, 6, 0])
              SizedBox(
                width: width,
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayNames[day],
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (slots.where((s) => s.dayOfWeek == day).isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No classes',
                            style: TextStyle(
                              color: colors.textDim,
                              fontSize: 10.5,
                            ),
                          ),
                        )
                      else
                        for (final slot in slots.where(
                          (s) => s.dayOfWeek == day,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Material(
                              color: hexToColor(slot.color)
                                  .withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () => onTap(slot),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: hexToColor(slot.color)
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.subjectCode,
                                        style: TextStyle(
                                          color: hexToColor(slot.color),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        slot.subjectTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textMain,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${formatClock(slot.startTime)} – ${formatClock(slot.endTime)}',
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                      if ((slot.room ?? slot.modality ?? '')
                                          .isNotEmpty)
                                        Text(
                                          slot.room ?? slot.modality ?? '',
                                          style: TextStyle(
                                            color: colors.textDim,
                                            fontSize: 9,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.date,
    required this.slots,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onTap,
  });

  final DateTime date;
  final List<ScheduleSlot> slots;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<ScheduleSlot> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dayIndex = date.weekday % 7;
    final daySlots = slots.where((s) => s.dayOfWeek == dayIndex).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconAction(
                icon: Icons.chevron_left,
                compact: true,
                onPressed: onPrev,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayNames[dayIndex],
                      style: TextStyle(
                        color: colors.textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${months[date.month - 1]} ${date.day}, ${date.year}',
                      style: TextStyle(color: colors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconAction(
                icon: Icons.chevron_right,
                compact: true,
                onPressed: onNext,
              ),
              const SizedBox(width: 8),
              PillButton(label: 'Today', dense: true, onPressed: onToday),
            ],
          ),
          const SizedBox(height: 14),
          if (daySlots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No classes scheduled for this day.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            )
          else
            for (final slot in daySlots)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => onTap(slot),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hexToColor(slot.color).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hexToColor(slot.color).withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: hexToColor(slot.color),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${slot.subjectCode} • ${slot.subjectTitle}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${formatClock(slot.startTime)} – ${formatClock(slot.endTime)} • '
                                '${slot.room ?? slot.modality ?? 'Location not set'}',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: colors.textDim,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colors.textMain, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

extension _IfEmpty on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

class _SlotFormResult {
  const _SlotFormResult({
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    this.building,
    this.modality,
    this.weekPattern = 'every',
  });
  final int subjectId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? room;
  final String? building;
  final String? modality;
  final String weekPattern;
}

class _SlotFormDialog extends StatefulWidget {
  const _SlotFormDialog({required this.subjects, this.existing});
  final List<Subject> subjects;
  final ScheduleSlot? existing;

  @override
  State<_SlotFormDialog> createState() => _SlotFormDialogState();
}

class _SlotFormDialogState extends State<_SlotFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _subjectId;
  late int _day;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _room;
  late final TextEditingController _building;
  late String _modality;
  late String _weekPattern;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _subjectId = e?.subjectId ?? widget.subjects.first.id;
    _day = e?.dayOfWeek ?? 1;
    _start = TextEditingController(text: e?.startTime ?? '08:00');
    _end = TextEditingController(text: e?.endTime ?? '09:30');
    _room = TextEditingController(text: e?.room ?? '');
    _building = TextEditingController(text: e?.building ?? '');
    _modality = e?.modality ?? 'face-to-face';
    _weekPattern = e?.weekPattern ?? 'every';
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _room.dispose();
    _building.dispose();
    super.dispose();
  }

  String? _validateTime(String? v) {
    if (v == null || !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v.trim())) {
      return 'Use HH:MM (24h)';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SlotFormResult(
        subjectId: _subjectId,
        dayOfWeek: _day,
        startTime: _start.text.trim(),
        endTime: _end.text.trim(),
        room: _room.text.trim(),
        building: _building.text.trim(),
        modality: _modality,
        weekPattern: _weekPattern,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add class' : 'Edit class'),
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
                onChanged: (v) => setState(() => _subjectId = v!),
              ),
              DropdownButtonFormField<int>(
                initialValue: _day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: [
                  for (var i = 0; i < 7; i++)
                    DropdownMenuItem(value: i, child: Text(dayNames[i])),
                ],
                onChanged: (v) => setState(() => _day = v!),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _start,
                      decoration: const InputDecoration(labelText: 'Start'),
                      validator: _validateTime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _end,
                      decoration: const InputDecoration(labelText: 'End'),
                      validator: _validateTime,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _room,
                decoration: const InputDecoration(labelText: 'Room (optional)'),
              ),
              TextFormField(
                controller: _building,
                decoration: const InputDecoration(
                  labelText: 'Building (optional)',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _modality,
                decoration: const InputDecoration(labelText: 'Modality'),
                items: const [
                  DropdownMenuItem(
                    value: 'face-to-face',
                    child: Text('Face-to-face'),
                  ),
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                ],
                onChanged: (v) => setState(() => _modality = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _weekPattern,
                decoration: const InputDecoration(labelText: 'Week pattern'),
                items: const [
                  DropdownMenuItem(value: 'every', child: Text('Every week')),
                  DropdownMenuItem(value: 'a', child: Text('Week A only')),
                  DropdownMenuItem(value: 'b', child: Text('Week B only')),
                ],
                onChanged: (v) => setState(() => _weekPattern = v!),
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
