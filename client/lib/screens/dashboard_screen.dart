import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/attendance.dart';
import '../models/dashboard.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../state/study_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/v2_kit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// Shell index: 2 = attendance, 3 = works, 4 = focus, 6 = notes.
  final ValueChanged<int> onNavigate;

  static const _quotes = [
    'Small daily efforts compound into extraordinary results.',
    'Discipline is choosing between what you want now and what you want most.',
    'A little progress each day adds up to big results.',
    'Study smart, rest well, and show up again tomorrow.',
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final study = context.watch<StudyState>();
    final dashboard = app.dashboard;

    if (dashboard == null) {
      if (app.loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: V2Empty(
            icon: Icons.cloud_off,
            title: app.error ?? 'No data yet',
            message: 'Pull to refresh or check the server address in Settings.',
          ),
        ),
      );
    }

    final colors = context.colors;
    final now = DateTime.now();
    final streak = study.stats?.streakDays ?? 0;
    final quote = _quotes[now.day % _quotes.length];
    final greeting = switch (now.hour) {
      < 12 => 'Good Morning',
      < 18 => 'Good Afternoon',
      _ => 'Good Evening',
    };
    final user = context.watch<AuthState>().user;
    final name = user?.fullName.split(' ').first ?? 'Student';
    final nextClass = _nextClass(dashboard.classes, now);

    return RefreshIndicator(
      onRefresh: app.refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: v2PagePadding(context),
        child: v2Centered(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeroBanner(
                tag: '${dashboard.dayName} • ${_prettyDate(dashboard.date)}',
                title: '$greeting, $name!',
                subtitle: '"$quote"',
                trailing: Align(
                  alignment: Alignment.centerLeft,
                  child: _StreakBadge(
                    streak: streak,
                    onTap: () => onNavigate(4),
                  ),
                ),
              ),
              _QuickActions(
                onFocus: () => onNavigate(4),
                onAttendance: () => onNavigate(2),
                onWorks: () => onNavigate(3),
                onNotes: () => onNavigate(6),
              ),
              const SizedBox(height: 14),
              _NextClassCard(
                next: nextClass,
                onDetails: nextClass == null
                    ? null
                    : () =>
                          _showClassDetails(context, nextClass, dashboard.date),
                onPresent: nextClass == null
                    ? null
                    : () => _quickMark(
                        context,
                        nextClass,
                        dashboard.date,
                        'present',
                      ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.radar, size: 19, color: colors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Absence & Cut Safety Radar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        PillButton(
                          label: 'Mark all today',
                          icon: Icons.done_all,
                          dense: true,
                          tone: colors.emerald,
                          onPressed: dashboard.classes.isEmpty
                              ? null
                              : () => _markAllPresent(context, dashboard),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (app.summary.isEmpty)
                      Text(
                        'Enroll courses to see attendance safety metrics.',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      )
                    else
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: app.summary.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final s = app.summary[i];
                            return _RadarChip(
                              summary: s,
                              onTap: () => onNavigate(2),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final split = constraints.maxWidth >= 900;
                  final classes = _TodayClasses(
                    classes: dashboard.classes,
                    onMark: (c, status) =>
                        _quickMark(context, c, dashboard.date, status),
                    onDetails: (c) =>
                        _showClassDetails(context, c, dashboard.date),
                  );
                  final deadlines = _Deadlines(works: dashboard.dueSoon);
                  if (!split) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        classes,
                        const SizedBox(height: 22),
                        deadlines,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: classes),
                      const SizedBox(width: 18),
                      Expanded(child: deadlines),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static DashboardClass? _nextClass(
    List<DashboardClass> classes,
    DateTime now,
  ) {
    if (classes.isEmpty) return null;
    final sorted = [...classes]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final nowTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    for (final c in sorted) {
      if (c.startTime.compareTo(nowTime) >= 0) return c;
    }
    return sorted.first;
  }

  static String _prettyDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.toUpperCase();
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  static Future<void> _quickMark(
    BuildContext context,
    DashboardClass c,
    String date,
    String status,
  ) async {
    try {
      await context.read<AppState>().markAttendance(
        subjectId: c.subjectId,
        slotId: c.slotId,
        date: date,
        status: status,
      );
      if (!context.mounted) return;
      _toast(
        context,
        '${c.code} marked ${status == 'late' ? 'late' : 'present'}.',
      );
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  static Future<void> _markAllPresent(
    BuildContext context,
    DashboardData dashboard,
  ) async {
    final app = context.read<AppState>();
    final marked = await app.markClassesPresent(
      date: dashboard.date,
      classes: [
        for (final c in dashboard.classes)
          (subjectId: c.subjectId, slotId: c.slotId),
      ],
    );
    if (!context.mounted) return;
    _toast(
      context,
      '$marked ${marked == 1 ? 'class' : 'classes'} marked present today.',
    );
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showClassDetails(
    BuildContext context,
    DashboardClass c,
    String date,
  ) {
    final colors = context.colors;
    return showV2Sheet<void>(
      context,
      (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          V2SheetHeader(
            title: '${c.code} • ${c.title}',
            subtitle: '${formatClock(c.startTime)} – ${formatClock(c.endTime)}',
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
                _DetailRow(label: 'Date', value: date),
                _DetailRow(
                  label: 'Time',
                  value:
                      '${formatClock(c.startTime)} – ${formatClock(c.endTime)}',
                ),
                _DetailRow(
                  label: 'Location',
                  value: c.room ?? c.modality ?? 'Campus',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Mark late',
                        icon: Icons.schedule,
                        tone: colors.amber,
                        expand: true,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _quickMark(context, c, date, 'late');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PillButton(
                        label: 'Mark present',
                        icon: Icons.check,
                        tone: colors.emerald,
                        expand: true,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _quickMark(context, c, date, 'present');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak, required this.onTap});

  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x4D0F1112),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_outlined,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                '$streak-day focus streak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onFocus,
    required this.onAttendance,
    required this.onWorks,
    required this.onNotes,
  });

  final VoidCallback onFocus;
  final VoidCallback onAttendance;
  final VoidCallback onWorks;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = [
      (Icons.timer_outlined, 'Start Focus Timer', onFocus, colors.primary),
      (Icons.percent, 'Cut Safety Calculator', onAttendance, colors.emerald),
      (Icons.add_task, 'New Assignment', onWorks, colors.amber),
      (Icons.note_add_outlined, 'New Study Note', onNotes, colors.violet),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900 ? 4 : 2;
        final width = (constraints.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Material(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    onTap: item.$3,
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(item.$1, size: 17, color: item.$4),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.$2,
                              style: TextStyle(
                                color: colors.textMain,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({
    required this.next,
    required this.onDetails,
    required this.onPresent,
  });

  final DashboardClass? next;
  final VoidCallback? onDetails;
  final VoidCallback? onPresent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = next;
    if (c == null) {
      return GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: colors.amber, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All clear for today',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No more classes scheduled. Rest or jump into the Focus Zone.',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return GlassCard(
      accent: colors.primary,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final info = Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        V2Badge(
                          'UPCOMING CLASS',
                          color: Colors.white,
                          background: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.code,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatClock(c.startTime)} – ${formatClock(c.endTime)} • '
                      '${c.room ?? c.modality ?? 'Campus'}',
                      style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PillButton(
                label: 'Details',
                icon: Icons.open_in_new,
                onPressed: onDetails,
              ),
              const SizedBox(width: 8),
              PillButton(
                label: 'Mark present',
                icon: Icons.check,
                tone: colors.emerald,
                selected: true,
                onPressed: onPresent,
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onDetails, child: info),
                ),
              ),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _RadarChip extends StatelessWidget {
  const _RadarChip({required this.summary, required this.onTap});

  final AttendanceSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = summary.warning ? colors.rose : colors.emerald;
    final safe = summary.safeMissesLeft;
    final label = summary.warning
        ? 'At the limit'
        : '$safe ${safe == 1 ? 'cut' : 'cuts'} left';
    return Material(
      color: tone.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tone.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: hexToColor(summary.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                summary.code,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: tone,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayClasses extends StatelessWidget {
  const _TodayClasses({
    required this.classes,
    required this.onMark,
    required this.onDetails,
  });

  final List<DashboardClass> classes;
  final void Function(DashboardClass, String) onMark;
  final void Function(DashboardClass) onDetails;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(title: "Today's Classes"),
        const SizedBox(height: 10),
        if (classes.isEmpty)
          const V2Empty(
            icon: Icons.free_cancellation_outlined,
            title: 'No classes today',
          )
        else
          for (final c in classes)
            GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
              onTap: () => onDetails(c),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hexToColor(c.color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.code} • ${c.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatClock(c.startTime)} – ${formatClock(c.endTime)} • '
                          '${c.room ?? 'Classroom'}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PillButton(
                    label: 'Present',
                    dense: true,
                    tone: colors.emerald,
                    onPressed: () => onMark(c, 'present'),
                  ),
                  const SizedBox(width: 6),
                  PillButton(
                    label: 'Late',
                    dense: true,
                    tone: colors.amber,
                    onPressed: () => onMark(c, 'late'),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Deadlines extends StatelessWidget {
  const _Deadlines({required this.works});

  final List<DueSoonWork> works;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(title: 'Urgent Deadlines'),
        const SizedBox(height: 10),
        if (works.isEmpty)
          const V2Empty(
            icon: Icons.event_available_outlined,
            title: 'Nothing urgent this week',
          )
        else
          for (final w in works)
            GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
              child: Row(
                children: [
                  Icon(_typeIcon(w.type), size: 19, color: hexToColor(w.color)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${w.subjectCode ?? 'General'} • ${w.type.toUpperCase()}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  V2Badge(
                    w.overdue ? 'Overdue' : dueLabel(w.dueAt),
                    color: w.overdue ? colors.rose : colors.primary,
                    dense: true,
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static IconData _typeIcon(String type) => switch (type) {
    'quiz' => Icons.quiz_outlined,
    'exam' => Icons.school_outlined,
    'project' => Icons.science_outlined,
    _ => Icons.assignment_outlined,
  };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colors.textMain, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
