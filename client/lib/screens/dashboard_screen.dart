import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/format.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dashboard = app.dashboard;

    if (dashboard == null) {
      if (app.loading) return const Center(child: CircularProgressIndicator());
      return _Message(
        icon: Icons.cloud_off,
        text: app.error ?? 'No data yet. Pull to refresh.',
        onRetry: app.refreshAll,
      );
    }

    return RefreshIndicator(
      onRefresh: app.refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${dashboard.dayName}, ${dashboard.date}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _Section(
            title: "Today's classes",
            empty: 'No classes scheduled today.',
            children: [
              for (final c in dashboard.classes)
                Card(
                  child: ListTile(
                    leading: _Dot(color: hexToColor(c.color)),
                    title: Text('${c.code} · ${c.title}'),
                    subtitle: Text(
                        '${formatClock(c.startTime)} – ${formatClock(c.endTime)}${c.room != null ? ' · ${c.room}' : ''}'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Due soon',
            empty: 'Nothing due in the next 7 days.',
            children: [
              for (final w in dashboard.dueSoon)
                Card(
                  child: ListTile(
                    leading: Icon(_typeIcon(w.type), color: hexToColor(w.color)),
                    title: Text(w.title),
                    subtitle: Text('${w.subjectCode ?? 'General'} · ${dueLabel(w.dueAt)}'),
                    trailing: w.overdue
                        ? Chip(
                            label: const Text('Overdue'),
                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Attendance warnings',
            empty: 'All subjects are above the cutoff. Nice.',
            children: [
              for (final s in dashboard.attendanceWarnings)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
                    title: Text('${s.code} · ${s.title}'),
                    subtitle: Text(
                        'Absence rate ${s.absenceRate ?? 0}% · ${s.absent} absent, ${s.late} late'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _typeIcon(String type) => switch (type) {
        'quiz' => Icons.quiz_outlined,
        'exam' => Icons.school_outlined,
        'project' => Icons.science_outlined,
        _ => Icons.assignment_outlined,
      };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, required this.empty});

  final String title;
  final List<Widget> children;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Card(
            child: ListTile(title: Text(empty, style: Theme.of(context).textTheme.bodySmall)),
          )
        else
          ...children,
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: () => onRetry!(), child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
