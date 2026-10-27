import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  Future<void> _mark(BuildContext context, int subjectId, String label) async {
    final result = await showDialog<_MarkResult>(
      context: context,
      builder: (_) => _MarkDialog(subjectLabel: label),
    );
    if (result == null || !context.mounted) return;
    try {
      await context.read<AppState>().markAttendance(
            subjectId: subjectId,
            date: result.date,
            status: result.status,
          );
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<AppState>().summary;

    if (summary.isEmpty) {
      return const Center(child: Text('Add a subject and mark attendance to see it here.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final s in summary)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${s.code} · ${s.title}',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (s.warning)
                        Chip(
                          avatar: Icon(Icons.warning_amber, size: 18, color: Theme.of(context).colorScheme.error),
                          label: const Text('At risk'),
                          backgroundColor: Theme.of(context).colorScheme.errorContainer,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (s.attendanceRate ?? 0) / 100,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text('Attendance ${s.attendanceRate ?? 0}% · '
                      '${s.present} present, ${s.absent} absent, ${s.late} late'),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _mark(context, s.subjectId, s.code),
                      icon: const Icon(Icons.check),
                      label: const Text('Mark'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MarkResult {
  const _MarkResult({required this.date, required this.status});
  final String date;
  final String status;
}

class _MarkDialog extends StatefulWidget {
  const _MarkDialog({required this.subjectLabel});
  final String subjectLabel;

  @override
  State<_MarkDialog> createState() => _MarkDialogState();
}

class _MarkDialogState extends State<_MarkDialog> {
  DateTime _date = DateTime.now();
  String _status = 'present';

  String get _dateString =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mark attendance · ${widget.subjectLabel}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Date'),
            subtitle: Text(_dateString),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final status in const ['present', 'absent', 'late', 'cancelled'])
                ChoiceChip(
                  label: Text(status[0].toUpperCase() + status.substring(1)),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _MarkResult(date: _dateString, status: _status)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
