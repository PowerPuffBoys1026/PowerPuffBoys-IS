import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/attendance.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  Future<void> _markQuick(
    BuildContext context,
    int subjectId,
    String status,
  ) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      await context.read<AppState>().markAttendance(
            subjectId: subjectId,
            date: dateStr,
            status: status,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged attendance for today as ${status.toUpperCase()}! ✅',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _markCustom(
    BuildContext context,
    int subjectId,
    String label,
  ) async {
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
            note: result.note,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance recorded successfully!')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<AppState>().summary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (summary.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                  Icons.verified_user_outlined,
                  size: 48,
                  color: PortalColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No attendance records yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add courses and log class meetings to watch your attendance rates and cut safety margins.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PortalColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final atRiskCount = summary.where((s) => s.warning).length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cut Safety Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: atRiskCount > 0
                        ? AppGradients.warning
                        : AppGradients.success,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        atRiskCount > 0
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              atRiskCount > 0
                                  ? '$atRiskCount Course(s) Near Cutoff Limit'
                                  : 'All Courses In Safe Zone',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              atRiskCount > 0
                                  ? 'Take care: you are approaching or at the 20% absence cutoff.'
                                  : 'Your attendance is healthy across all enrolled subjects. Keep it up! 🛡️',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Per-Course Cards
                for (final s in summary) ...[
                  _AttendanceCard(
                    summary: s,
                    isDark: isDark,
                    onQuickMark: (status) =>
                        _markQuick(context, s.subjectId, status),
                    onCustomMark: () =>
                        _markCustom(context, s.subjectId, s.code),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.summary,
    required this.isDark,
    required this.onQuickMark,
    required this.onCustomMark,
  });

  final AttendanceSummary summary;
  final bool isDark;
  final ValueChanged<String> onQuickMark;
  final VoidCallback onCustomMark;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final rate = s.attendanceRate ?? 100.0;
    final color = hexToColor(s.color);

    return Card(
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Course Code, Title and Safe Margin Tag
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.code} · ${s.title}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.counted} class sessions recorded',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PortalColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: s.warning
                        ? const Color(0xFFEF4444).withAlpha(24)
                        : (s.safeMissesLeft <= 1
                            ? Colors.amber.withAlpha(24)
                            : PortalColors.emerald.withAlpha(24)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        s.warning ? Icons.dangerous : Icons.shield_outlined,
                        size: 15,
                        color: s.warning
                            ? const Color(0xFFEF4444)
                            : (s.safeMissesLeft <= 1
                                ? Colors.amber
                                : PortalColors.emerald),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.warning
                            ? '🚨 0 skips left (Warning)'
                            : '🛡️ ${s.safeMissesLeft} safe skip${s.safeMissesLeft == 1 ? '' : 's'} left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: s.warning
                              ? const Color(0xFFEF4444)
                              : (s.safeMissesLeft <= 1
                                  ? Colors.amber[800]
                                  : PortalColors.emerald),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      minHeight: 10,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      color: s.warning
                          ? const Color(0xFFEF4444)
                          : (rate < 85 ? Colors.amber : PortalColors.emerald),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: s.warning
                        ? const Color(0xFFEF4444)
                        : (rate < 85 ? Colors.amber : PortalColors.emerald),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metrics Strip & One-Tap Log Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusBadge(
                  label: '${s.present} Present',
                  color: PortalColors.emerald,
                ),
                _StatusBadge(
                  label: '${s.absent} Absent',
                  color: const Color(0xFFEF4444),
                ),
                _StatusBadge(
                  label: '${s.late} Late',
                  color: Colors.amber,
                ),
                if (s.cancelled > 0)
                  _StatusBadge(
                    label: '${s.cancelled} Cancelled',
                    color: PortalColors.muted,
                  ),
                const SizedBox(width: 12),
                // Action Buttons
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: PortalColors.emerald.withAlpha(25),
                    foregroundColor: PortalColors.emerald,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => onQuickMark('present'),
                  child: const Text('Present'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withAlpha(25),
                    foregroundColor: const Color(0xFFEF4444),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => onQuickMark('absent'),
                  child: const Text('Absent'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.withAlpha(25),
                    foregroundColor: Colors.amber[800],
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => onQuickMark('late'),
                  child: const Text('Late'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onCustomMark,
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: const Text('Custom...'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MarkResult {
  const _MarkResult({required this.date, required this.status, this.note});
  final String date;
  final String status;
  final String? note;
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
  final _noteCtrl = TextEditingController();

  String get _dateString =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Log Attendance · ${widget.subjectLabel}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today,
                  color: PortalColors.primary),
              title: const Text('Session Date'),
              subtitle: Text(_dateString,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 10),
            const Text('Status',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final status in const [
                  'present',
                  'absent',
                  'late',
                  'cancelled'
                ])
                  ChoiceChip(
                    label: Text(status[0].toUpperCase() + status.substring(1)),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Optional Note / Reason',
                hintText: 'e.g. Lab exercise 3, Medical reason, etc.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _MarkResult(
              date: _dateString,
              status: _status,
              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            ),
          ),
          child: const Text('Save Record'),
        ),
      ],
    );
  }
}
