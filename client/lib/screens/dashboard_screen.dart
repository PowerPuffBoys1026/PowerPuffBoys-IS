import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../models/dashboard.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'grades_dialog.dart';
import 'notes_dialog.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onNavigate});

  final ValueChanged<int>? onNavigate;

  static const _quotes = [
    'Small daily efforts compound into extraordinary results.',
    'Focus on the step in front of you, not the whole staircase.',
    'Discipline is choosing what you want most over what you want now.',
    'Your future self will thank you for the focus you put in today.',
    'Consistency beats talent when talent is inconsistent.',
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dashboard = app.dashboard;
    final user = context.watch<AuthState>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (dashboard == null) {
      if (app.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return _Message(
        icon: Icons.cloud_off,
        text: app.error ?? 'No data yet. Pull to refresh.',
        onRetry: app.refreshAll,
      );
    }

    final classes = [...dashboard.classes]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final now = DateTime.now();
    final nowTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    DashboardClass? nextClass;
    for (final classItem in classes) {
      if (classItem.startTime.compareTo(nowTime) >= 0) {
        nextClass = classItem;
        break;
      }
    }

    final dueWork =
        dashboard.dueSoon.where((work) => work.status != 'done').toList()
          ..sort((a, b) => _compareDueDates(a.dueAt, b.dueAt));
    final openWorkCount =
        app.works.where((work) => work.status != 'done').length;

    final quote = _quotes[now.day % _quotes.length];
    final streak = app.studyStats?.streakDays ?? 0;

    return RefreshIndicator(
      onRefresh: app.refreshAll,
      color: PortalColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dynamic Greeting & Daily Quote
                  _StudentHeroHeading(
                    name: user?.fullName.split(' ').first ?? 'Student',
                    day: dashboard.dayName,
                    date: dashboard.date,
                    quote: quote,
                    streakDays: streak,
                    classCount: classes.length,
                    openWorkCount: openWorkCount,
                  ),
                  const SizedBox(height: 18),

                  // Quick Action Tool Strip
                  _QuickActionPillRow(
                    onFocus: () => onNavigate?.call(4),
                    onAttendance: () => onNavigate?.call(2),
                    onNotes: () => showDialog(
                      context: context,
                      builder: (_) => const NotesDialog(),
                    ),
                    onGrades: () => showDialog(
                      context: context,
                      builder: (_) => const GradesDialog(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Next Class Hero Card
                  _NextClassHero(
                    classItem: nextClass,
                    onOpen: () => onNavigate?.call(1),
                    onMarkPresent: nextClass == null
                        ? null
                        : () async {
                            final classItem = nextClass!;
                            try {
                              await app.quickMarkToday(
                                subjectId: classItem.subjectId,
                                slotId: classItem.slotId,
                                status: 'present',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Marked ${classItem.code} as Present! 🎉'),
                                  ),
                                );
                              }
                            } catch (_) {}
                          },
                  ),
                  const SizedBox(height: 18),

                  // Safe Skips & Cut Calculator Radar
                  _AttendanceCutRadar(
                    summaries: app.summary,
                    onOpenAttendance: () => onNavigate?.call(2),
                    onMarkAllToday: classes.isEmpty
                        ? null
                        : () async {
                            await app.markAllTodayPresent();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Marked all classes today as Present! ✅'),
                                ),
                              );
                            }
                          },
                  ),
                  const SizedBox(height: 24),

                  // Responsive Split: Today's Classes & Urgent Deadlines
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final schedule = _TodaySchedule(
                        classes: classes,
                        nextClass: nextClass,
                        onOpen: () => onNavigate?.call(1),
                        onQuickMark: (c, status) async {
                          await app.quickMarkToday(
                            subjectId: c.subjectId,
                            slotId: c.slotId,
                            status: status,
                          );
                        },
                      );

                      final focus = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FocusPanel(
                            work: dueWork.isEmpty ? null : dueWork.first,
                            onOpen: () => onNavigate?.call(3),
                          ),
                          const SizedBox(height: 20),
                          _DueSoonSection(
                            works: dueWork.take(4).toList(),
                            onOpen: () => onNavigate?.call(3),
                          ),
                        ],
                      );

                      if (constraints.maxWidth < 840) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            schedule,
                            const SizedBox(height: 24),
                            focus,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: schedule),
                          const SizedBox(width: 28),
                          Expanded(flex: 5, child: focus),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _compareDueDates(DateTime? first, DateTime? second) {
    if (first == null) return second == null ? 0 : 1;
    if (second == null) return -1;
    return first.compareTo(second);
  }
}

class _StudentHeroHeading extends StatelessWidget {
  const _StudentHeroHeading({
    required this.name,
    required this.day,
    required this.date,
    required this.quote,
    required this.streakDays,
    required this.classCount,
    required this.openWorkCount,
  });

  final String name;
  final String day;
  final String date;
  final String quote;
  final int streakDays;
  final int classCount;
  final int openWorkCount;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.toUpperCase()}  ·  $date',
                style: const TextStyle(
                  color: PortalColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$timeGreeting, $name! 🚀',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '“$quote”',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? PortalColors.mutedDark
                      : PortalColors.mutedLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (streakDays > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppGradients.fire,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '$streakDays Day Streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              '$classCount classes today  ·  $openWorkCount pending',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: PortalColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionPillRow extends StatelessWidget {
  const _QuickActionPillRow({
    required this.onFocus,
    required this.onAttendance,
    required this.onNotes,
    required this.onGrades,
  });

  final VoidCallback onFocus;
  final VoidCallback onAttendance;
  final VoidCallback onNotes;
  final VoidCallback onGrades;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickPill(
            icon: Icons.timer_outlined,
            label: 'Start Focus Timer',
            color: PortalColors.primary,
            onTap: onFocus,
          ),
          const SizedBox(width: 10),
          _QuickPill(
            icon: Icons.shield_outlined,
            label: 'Cut Calculator',
            color: PortalColors.emerald,
            onTap: onAttendance,
          ),
          const SizedBox(width: 10),
          _QuickPill(
            icon: Icons.note_alt_outlined,
            label: 'Quick Flashnote',
            color: PortalColors.amber,
            onTap: onNotes,
          ),
          const SizedBox(width: 10),
          _QuickPill(
            icon: Icons.calculate_outlined,
            label: 'GPA Solver',
            color: PortalColors.cyan,
            onTap: onGrades,
          ),
        ],
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF182236) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? PortalColors.lineDark
                  : PortalColors.lineLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
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

class _NextClassHero extends StatelessWidget {
  const _NextClassHero({
    required this.classItem,
    required this.onOpen,
    this.onMarkPresent,
  });

  final DashboardClass? classItem;
  final VoidCallback onOpen;
  final VoidCallback? onMarkPresent;

  @override
  Widget build(BuildContext context) {
    final item = classItem;

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: PortalColors.primary.withAlpha(90),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item == null
                        ? Icons.spa_rounded
                        : Icons.play_lesson_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item == null ? 'ALL CLEAR' : 'UPCOMING CLASS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item == null
                            ? 'No more classes scheduled today!'
                            : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item == null
                            ? 'Great job keeping up. Time to relax or hit the Focus Zone.'
                            : '${item.code} · ${item.room ?? item.modality ?? 'Classroom'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item != null) ...[
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatClock(item.startTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: PortalColors.primary,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                        onPressed: onMarkPresent,
                        child: const Text('Mark Present',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceCutRadar extends StatelessWidget {
  const _AttendanceCutRadar({
    required this.summaries,
    required this.onOpenAttendance,
    this.onMarkAllToday,
  });

  final List<AttendanceSummary> summaries;
  final VoidCallback onOpenAttendance;
  final VoidCallback? onMarkAllToday;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 20, color: PortalColors.emerald),
                const SizedBox(width: 8),
                const Text(
                  'Cut & Absence Safety Radar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (onMarkAllToday != null)
                  TextButton.icon(
                    onPressed: onMarkAllToday,
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Mark All Today Present'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (summaries.isEmpty)
              const Text(
                'Enroll courses to activate your smart attendance cutoff safety tracking.',
                style: TextStyle(fontSize: 12, color: PortalColors.muted),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in summaries)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: onOpenAttendance,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: s.warning
                                  ? const Color(0xFFEF4444).withAlpha(20)
                                  : (isDark
                                      ? const Color(0xFF131A2A)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: s.warning
                                    ? const Color(0xFFEF4444).withAlpha(60)
                                    : (isDark
                                        ? PortalColors.lineDark
                                        : PortalColors.lineLight),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: hexToColor(s.color),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  s.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: s.warning
                                        ? const Color(0xFFEF4444)
                                        : PortalColors.emerald,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s.warning
                                        ? '🚨 0 skips left'
                                        : '🛡️ ${s.safeMissesLeft} skips left',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodaySchedule extends StatelessWidget {
  const _TodaySchedule({
    required this.classes,
    required this.nextClass,
    required this.onOpen,
    required this.onQuickMark,
  });

  final List<DashboardClass> classes;
  final DashboardClass? nextClass;
  final VoidCallback onOpen;
  final void Function(DashboardClass, String) onQuickMark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Schedule",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            TextButton(
              onPressed: onOpen,
              child: const Text('View Timetable'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (classes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No classes scheduled for today. Enjoy your day! ✨'),
              ),
            ),
          )
        else
          for (final c in classes) ...[
            _ClassRowCard(
              classItem: c,
              isNext: c == nextClass,
              onQuickMark: onQuickMark,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _ClassRowCard extends StatelessWidget {
  const _ClassRowCard({
    required this.classItem,
    required this.isNext,
    required this.onQuickMark,
  });

  final DashboardClass classItem;
  final bool isNext;
  final void Function(DashboardClass, String) onQuickMark;

  @override
  Widget build(BuildContext context) {
    final c = classItem;
    final color = hexToColor(c.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isNext ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isNext
              ? PortalColors.primary
              : (isDark ? PortalColors.lineDark : PortalColors.lineLight),
          width: isNext ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c.code,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isNext)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: PortalColors.primary.withAlpha(24),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NOW / NEXT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: PortalColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatClock(c.startTime)} – ${formatClock(c.endTime)}  ·  ${c.room ?? c.modality ?? 'Classroom'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: PortalColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Mark Present',
                  icon: const Icon(Icons.check_circle_outline,
                      size: 20, color: PortalColors.emerald),
                  onPressed: () => onQuickMark(c, 'present'),
                ),
                IconButton(
                  tooltip: 'Mark Late',
                  icon: const Icon(Icons.access_time,
                      size: 20, color: PortalColors.amber),
                  onPressed: () => onQuickMark(c, 'late'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusPanel extends StatelessWidget {
  const _FocusPanel({required this.work, required this.onOpen});

  final DueSoonWork? work;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final item = work;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_outline_rounded,
                    color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Top Priority Focus',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onOpen,
                  child: const Text('All Tasks'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item == null)
              const Text(
                'No pending school works. You are totally ahead of schedule! 🎉',
                style: TextStyle(fontSize: 12, color: PortalColors.muted),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.subjectCode ?? 'General'} · ${item.type.toUpperCase()}',
                          style: const TextStyle(
                              fontSize: 11, color: PortalColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.overdue
                          ? const Color(0xFFEF4444).withAlpha(20)
                          : PortalColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.overdue ? 'Overdue' : dueLabel(item.dueAt),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: item.overdue
                            ? const Color(0xFFEF4444)
                            : PortalColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DueSoonSection extends StatelessWidget {
  const _DueSoonSection({required this.works, required this.onOpen});

  final List<DueSoonWork> works;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.alarm, size: 18, color: PortalColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Upcoming Deadlines',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${works.length} items',
                  style:
                      const TextStyle(fontSize: 11, color: PortalColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (works.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No upcoming deadlines in the next 7 days.'),
                ),
              )
            else
              for (final w in works) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: w.color != null
                              ? hexToColor(w.color!)
                              : PortalColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          w.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dueLabel(w.dueAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: w.overdue
                              ? const Color(0xFFEF4444)
                              : PortalColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.onRetry,
  });

  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: PortalColors.muted),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
