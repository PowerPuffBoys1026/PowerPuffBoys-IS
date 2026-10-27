import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/schedule_slot.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

/// Weekly timetable grid. Best experienced on a wide screen (web/desktop),
/// horizontally scrollable on mobile.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  static const _weekOrder = [1, 2, 3, 4, 5, 6, 0]; // Monday first

  Future<void> _openForm(BuildContext context) async {
    final app = context.read<AppState>();
    if (app.subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a subject first.')),
      );
      return;
    }
    final result = await showDialog<_SlotFormResult>(
      context: context,
      builder: (_) => _SlotFormDialog(subjects: app.subjects),
    );
    if (result == null || !context.mounted) return;
    try {
      await app.addSlot(
        subjectId: result.subjectId,
        dayOfWeek: result.dayOfWeek,
        startTime: result.startTime,
        endTime: result.endTime,
        room: result.room,
        modality: result.modality,
      );
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _remove(BuildContext context, ScheduleSlot slot) async {
    try {
      await context.read<AppState>().removeSlot(slot.id);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = context.watch<AppState>().slots;

    return Scaffold(
      body: slots.isEmpty
          ? const Center(child: Text('No classes scheduled yet. Tap + to add one.'))
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: constraints.maxHeight - 24,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final day in _weekOrder)
                        _DayColumn(
                          day: day,
                          slots: slots.where((s) => s.dayOfWeek == day).toList(),
                          onDelete: (slot) => _remove(context, slot),
                        ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Class'),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.slots, required this.onDelete});

  final int day;
  final List<ScheduleSlot> slots;
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
            child: Text(dayNames[day], style: Theme.of(context).textTheme.titleSmall),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final slot in slots)
                  Card(
                    color: hexToColor(slot.color).withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(slot.subjectCode,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              InkWell(
                                onTap: () => onDelete(slot),
                                child: const Icon(Icons.close, size: 16),
                              ),
                            ],
                          ),
                          Text(slot.subjectTitle, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text('${formatClock(slot.startTime)} – ${formatClock(slot.endTime)}',
                              style: Theme.of(context).textTheme.bodySmall),
                          if (slot.room != null)
                            Text(slot.room!, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotFormResult {
  const _SlotFormResult({
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    this.modality,
  });
  final int subjectId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? room;
  final String? modality;
}

class _SlotFormDialog extends StatefulWidget {
  const _SlotFormDialog({required this.subjects});
  final List<Subject> subjects;

  @override
  State<_SlotFormDialog> createState() => _SlotFormDialogState();
}

class _SlotFormDialogState extends State<_SlotFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _subjectId;
  int _day = 1;
  final _start = TextEditingController(text: '08:00');
  final _end = TextEditingController(text: '09:30');
  final _room = TextEditingController();
  String _modality = 'face-to-face';

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjects.first.id;
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _room.dispose();
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
        modality: _modality,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add class'),
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
              DropdownButtonFormField<String>(
                initialValue: _modality,
                decoration: const InputDecoration(labelText: 'Modality'),
                items: const [
                  DropdownMenuItem(value: 'face-to-face', child: Text('Face-to-face')),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
