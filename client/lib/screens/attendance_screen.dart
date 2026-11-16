import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/attendance.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/v2_kit.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _mark(
    BuildContext context,
    AttendanceSummary s,
    String status, {
    String? date,
  }) async {
    try {
      await context.read<AppState>().markAttendance(
        subjectId: s.subjectId,
        date: date ?? _today(),
        status: status,
      );
      if (!context.mounted) return;
      _toast(context, '${s.code} marked $status.');
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _customDate(BuildContext context, AttendanceSummary s) async {
    final result = await showDialog<_MarkResult>(
      context: context,
      builder: (_) => _MarkDialog(subjectLabel: s.code),
    );
    if (result == null || !context.mounted) return;
    await _mark(context, s, result.status, date: result.date);
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final summary = app.summary;
    final colors = context.colors;

    if (summary.isEmpty) {
      return ListView(
        padding: v2PagePadding(context),
        children: const [
          V2Empty(
            icon: Icons.fact_check_outlined,
            title: 'No attendance yet',
            message: 'Add a subject and mark your first class to unlock the cut safety calculator.',
          ),
        ],
      );
    }

    final atRisk = summary.where((s) => s.warning).length;
    final totalSafe = summary.fold<int>(0, (sum, s) => sum + s.safeMissesLeft);
    final counted = summary.fold<int>(0, (sum, s) => sum + s.counted);
    final present = summary.fold<int>(0, (sum, s) => sum + s.present + s.late);
    final overall = counted == 0 ? 0.0 : (present / counted) * 100;

    return RefreshIndicator(
      onRefresh: app.refreshAll,
      child: ListView(
        padding: v2PagePadding(context),
        children: [
          v2Centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HealthBanner(
                  overall: overall,
                  atRisk: atRisk,
                  totalSafe: totalSafe,
                  counted: counted,
                  warning: atRisk > 0,
                ),
                const SizedBox(height: 16),
                const SectionHeading(
                  title: 'Course attendance',
                  subtitle: 'Quick-mark today, or open the calendar for another date.',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final two = constraints.maxWidth >= 980;
                    final cards = [
                      for (final s in summary)
                        _CourseAttendanceCard(
                          summary: s,
                          onPresent: () => _mark(context, s, 'present'),
                          onLate: () => _mark(context, s, 'late'),
                          onAbsent: () => _mark(context, s, 'absent'),
                          onDate: () => _customDate(context, s),
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
                const SizedBox(height: 18),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: colors.textDim),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'A “cut” is a safe absence under the 20% allowance for a course. '
                          'Late marks count as attended but are tracked separately.',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
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

class _HealthBanner extends StatelessWidget {
  const _HealthBanner({
    required this.overall,
    required this.atRisk,
    required this.totalSafe,
    required this.counted,
    required this.warning,
  });

  final double overall;
  final int atRisk;
  final int totalSafe;
  final int counted;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name =
        context.watch<AuthState>().user?.fullName.split(' ').first ?? 'Student';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: warning
              ? const [Color(0xFFF59E0B), Color(0xFFB45309)]
              : const [Color(0xFF10B981), Color(0xFF047857)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: (warning ? colors.amber : colors.emerald).withValues(
              alpha: 0.25,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATTENDANCE HEALTH',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  warning
                      ? 'Protect your standing, $name.'
                      : 'You are in a safe place, $name.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  atRisk == 0
                      ? '$totalSafe safe cuts across ${counted > 0 ? 'your courses' : 'enrolled courses'} — keep showing up.'
                      : '$atRisk ${atRisk == 1 ? 'course is' : 'courses are'} at the absence limit. Attend the next sessions.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniStat(
                      label: 'Overall',
                      value: '${overall.toStringAsFixed(0)}%',
                    ),
                    const SizedBox(width: 20),
                    _MiniStat(label: 'Safe cuts', value: '$totalSafe'),
                    const SizedBox(width: 20),
                    _MiniStat(label: 'Sessions', value: '$counted'),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${overall.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CourseAttendanceCard extends StatelessWidget {
  const _CourseAttendanceCard({
    required this.summary,
    required this.onPresent,
    required this.onLate,
    required this.onAbsent,
    required this.onDate,
  });

  final AttendanceSummary summary;
  final VoidCallback onPresent;
  final VoidCallback onLate;
  final VoidCallback onAbsent;
  final VoidCallback onDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rate = summary.attendanceRate ?? 0;
    final tone = summary.warning ? colors.rose : colors.emerald;
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: hexToColor(summary.color).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  summary.code.isEmpty ? '?' : summary.code[0],
                  style: TextStyle(
                    color: hexToColor(summary.color),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.code} • ${summary.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${summary.counted} counted • ${summary.maxAllowedAbsences} allowed',
                      style: TextStyle(color: colors.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              V2Badge(
                summary.warning
                    ? 'At risk'
                    : '${summary.safeMissesLeft} ${summary.safeMissesLeft == 1 ? 'cut' : 'cuts'} left',
                color: tone,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: V2ProgressBar(value: rate / 100, color: tone, height: 6),
              ),
              const SizedBox(width: 10),
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: tone,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _Count(
                label: 'Present',
                value: summary.present,
                color: colors.emerald,
              ),
              _Count(label: 'Late', value: summary.late, color: colors.amber),
              _Count(
                label: 'Absent',
                value: summary.absent,
                color: colors.rose,
              ),
              _Count(
                label: 'Cancelled',
                value: summary.cancelled,
                color: colors.textDim,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Present',
                  icon: Icons.check,
                  dense: true,
                  tone: colors.emerald,
                  onPressed: onPresent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: PillButton(
                  label: 'Late',
                  icon: Icons.schedule,
                  dense: true,
                  tone: colors.amber,
                  onPressed: onLate,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: PillButton(
                  label: 'Absent',
                  icon: Icons.close,
                  dense: true,
                  tone: colors.rose,
                  onPressed: onAbsent,
                ),
              ),
              const SizedBox(width: 6),
              IconAction(
                icon: Icons.calendar_month_outlined,
                tooltip: 'Mark another date',
                compact: true,
                onPressed: onDate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: TextStyle(
            color: context.colors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
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
    final colors = context.colors;
    return AlertDialog(
      title: Text('Mark ${widget.subjectLabel}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Date'),
            subtitle: Text(_dateString),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in const [
                'present',
                'absent',
                'late',
                'cancelled',
              ])
                PillButton(
                  label: status[0].toUpperCase() + status.substring(1),
                  selected: _status == status,
                  tone: colors.primary,
                  onPressed: () => setState(() => _status = status),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _MarkResult(date: _dateString, status: _status),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
