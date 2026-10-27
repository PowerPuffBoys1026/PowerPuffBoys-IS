import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/schedule_slot.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _weekOrder = [1, 2, 3, 4, 5, 6, 0]; // Monday first
  String _view = 'week';
  String _weekFilter = 'all';
  int _selectedDay = DateTime.now().weekday % 7;

  Future<void> _openForm({ScheduleSlot? existing}) async {
    final context = this.context;
    final app = context.read<AppState>();
    if (app.subjects.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add a subject first.')));
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
        await app.addSlots(
          subjectId: result.subjectId,
          daysOfWeek: result.daysOfWeek,
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
          dayOfWeek: result.daysOfWeek.first,
          startTime: result.startTime,
          endTime: result.endTime,
          room: result.room,
          building: result.building,
          modality: result.modality,
          weekPattern: result.weekPattern,
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _remove(ScheduleSlot slot) async {
    try {
      await context.read<AppState>().removeSlot(slot.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _exportSchedule(BuildContext context, List<ScheduleSlot> slots) {
    if (slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No classes to export yet.')),
      );
      return;
    }
    final buffer = StringBuffer('📅 ClassMate Weekly Schedule\n\n');
    for (final day in _weekOrder) {
      final daySlots = slots.where((s) => s.dayOfWeek == day).toList();
      if (daySlots.isEmpty) continue;
      buffer.writeln('${dayNames[day].toUpperCase()}:');
      for (final s in daySlots) {
        buffer.writeln(
          '  • ${formatClock(s.startTime)} – ${formatClock(s.endTime)}: ${s.subjectCode} (${s.subjectTitle}) [${s.room ?? s.modality ?? 'Class'}]',
        );
      }
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Timetable copied to clipboard! Ready to share or save. 📋✨',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSlots = context.watch<AppState>().slots;
    final slots = allSlots.where((slot) {
      return _weekFilter == 'all' ||
          slot.weekPattern == 'every' ||
          slot.weekPattern == _weekFilter;
    }).toList()
      ..sort((a, b) {
        final dayOrder = _weekOrder
            .indexOf(a.dayOfWeek)
            .compareTo(_weekOrder.indexOf(b.dayOfWeek));
        return dayOrder == 0
            ? a.startTime.compareTo(b.startTime)
            : dayOrder;
      });

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'week',
                      label: Text('Week'),
                      icon: Icon(Icons.view_week_outlined),
                    ),
                    ButtonSegment(
                      value: 'day',
                      label: Text('Day'),
                      icon: Icon(Icons.view_day_outlined),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (selection) =>
                      setState(() => _view = selection.first),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All weeks')),
                    ButtonSegment(value: 'a', label: Text('Week A')),
                    ButtonSegment(value: 'b', label: Text('Week B')),
                  ],
                  selected: {_weekFilter},
                  onSelectionChanged: (selection) =>
                      setState(() => _weekFilter = selection.first),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _exportSchedule(context, slots),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Export Timetable'),
                ),
              ],
            ),
          ),
          if (_view == 'day')
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  for (final day in _weekOrder)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(dayNames[day].substring(0, 3)),
                        selected: _selectedDay == day,
                        onSelected: (_) => setState(() => _selectedDay = day),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: slots.isEmpty
                ? const Center(
                    child: Text('No classes yet. Add a course to start your timetable.'),
                  )
                : _view == 'day'
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 90),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(dayNames[_selectedDay], style: Theme.of(context).textTheme.titleLarge),
                          ),
                          for (final slot in slots.where((item) => item.dayOfWeek == _selectedDay))
                            _SlotCard(
                              slot: slot,
                              onEdit: () => _openForm(existing: slot),
                              onDelete: () => _remove(slot),
                            ),
                          if (slots.where((item) => item.dayOfWeek == _selectedDay).isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('No classes on this day.'),
                            ),
                        ],
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                          child: SizedBox(
                            height: constraints.maxHeight - 22,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final day in _weekOrder)
                                  _DayColumn(
                                    day: day,
                                    slots: slots.where((slot) => slot.dayOfWeek == day).toList(),
                                    onEdit: (slot) => _openForm(existing: slot),
                                    onDelete: _remove,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'schedule-add-class',
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Class'),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.slots,
    required this.onEdit,
    required this.onDelete,
  });

  final int day;
  final List<ScheduleSlot> slots;
  final void Function(ScheduleSlot) onEdit;
  final void Function(ScheduleSlot) onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              dayNames[day],
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (final slot in slots)
                  _SlotCard(
                    slot: slot,
                    onEdit: () => onEdit(slot),
                    onDelete: () => onDelete(slot),
                  ),
                if (slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No classes', style: TextStyle(fontSize: 11, color: PortalColors.muted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.onEdit, required this.onDelete});

  final ScheduleSlot slot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: hexToColor(slot.color).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(slot.subjectCode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                if (slot.weekPattern != 'every')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: PortalColors.crimsonWash, borderRadius: BorderRadius.circular(3)),
                    child: Text('WEEK ${slot.weekPattern.toUpperCase()}', style: const TextStyle(fontSize: 8, color: PortalColors.crimson, fontWeight: FontWeight.w800)),
                  ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 120),
                  onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            Text(slot.subjectTitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            Text('${formatClock(slot.startTime)} – ${formatClock(slot.endTime)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            if (slot.room != null || slot.building != null)
              Text([slot.room, slot.building].whereType<String>().where((value) => value.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 10, color: PortalColors.muted)),
            if (slot.modality != null)
              Text(slot.modality!, style: const TextStyle(fontSize: 9, color: PortalColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _SlotFormResult {
  const _SlotFormResult({
    required this.subjectId,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    required this.weekPattern,
    this.room,
    this.building,
    this.modality,
  });
  final int subjectId;
  final List<int> daysOfWeek;
  final String startTime;
  final String endTime;
  final String weekPattern;
  final String? room;
  final String? building;
  final String? modality;
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
  final _start = TextEditingController(text: '08:00');
  final _end = TextEditingController(text: '09:30');
  final _room = TextEditingController();
  final _building = TextEditingController();
  Set<int> _days = {1};
  String _modality = 'face-to-face';
  String _weekPattern = 'every';

  static const _weekOrder = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    final slot = widget.existing;
    _subjectId = slot?.subjectId ?? widget.subjects.first.id;
    _days = {slot?.dayOfWeek ?? 1};
    _start.text = slot?.startTime ?? _start.text;
    _end.text = slot?.endTime ?? _end.text;
    _room.text = slot?.room ?? '';
    _building.text = slot?.building ?? '';
    _modality = slot?.modality ?? 'face-to-face';
    _weekPattern = slot?.weekPattern ?? 'every';
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
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one class day.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _SlotFormResult(
        subjectId: _subjectId,
        daysOfWeek: _weekOrder.where(_days.contains).toList(),
        startTime: _start.text.trim(),
        endTime: _end.text.trim(),
        weekPattern: _weekPattern,
        room: _room.text.trim(),
        building: _building.text.trim(),
        modality: _modality,
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
              if (widget.existing != null)
                DropdownButtonFormField<int>(
                  initialValue: _days.first,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: [
                    for (final day in _weekOrder)
                      DropdownMenuItem(value: day, child: Text(dayNames[day])),
                  ],
                  onChanged: (value) => setState(() => _days = {value!}),
                )
              else ...[
                const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 16, bottom: 7), child: Text('Repeat on', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final day in _weekOrder)
                      FilterChip(
                        label: Text(dayNames[day].substring(0, 3)),
                        selected: _days.contains(day),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _days.add(day);
                          } else {
                            _days.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'every', label: Text('Every week')),
                  ButtonSegment(value: 'a', label: Text('Week A')),
                  ButtonSegment(value: 'b', label: Text('Week B')),
                ],
                selected: {_weekPattern},
                onSelectionChanged: (selection) => setState(() => _weekPattern = selection.first),
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
                decoration: const InputDecoration(labelText: 'Building (optional)'),
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
