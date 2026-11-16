import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/study_session.dart';
import '../models/subject.dart';
import '../state/app_state.dart';
import '../state/study_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/v2_kit.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const _modes = <String, (String, int)>{
    'focus': ('Focus', 25),
    'short_break': ('Short break', 5),
    'long_break': ('Long break', 15),
  };
  static const _focusPresets = [15, 25, 45, 60];

  Timer? _ticker;
  String _mode = 'focus';
  int _minutes = 25;
  int _remaining = 25 * 60;
  bool _running = false;
  bool _logging = false;
  int? _subjectId;

  int get _totalSeconds => _minutes * 60;
  int get _elapsedMinutes => ((_totalSeconds - _remaining) / 60).floor();

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _selectMode(String mode) {
    _ticker?.cancel();
    setState(() {
      _mode = mode;
      _minutes = _modes[mode]!.$2;
      _remaining = _totalSeconds;
      _running = false;
    });
  }

  void _selectMinutes(int minutes) {
    _ticker?.cancel();
    setState(() {
      _minutes = minutes;
      _remaining = _totalSeconds;
      _running = false;
    });
  }

  void _toggle() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_remaining <= 0) _remaining = _totalSeconds;
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        timer.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
        _finish();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _remaining = _totalSeconds;
      _running = false;
    });
  }

  Future<void> _finish() async {
    if (_logging) return;
    final minutes = _remaining == 0 ? _minutes : _elapsedMinutes;
    if (minutes < 1) return;
    setState(() => _logging = true);
    try {
      await context.read<StudyState>().create(
        subjectId: _subjectId,
        durationMinutes: minutes,
        mode: _mode,
      );
      if (mounted) {
        _toast('Logged $minutes min (${_modes[_mode]!.$1})');
      }
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _delete(StudySession session) async {
    try {
      await context.read<StudyState>().remove(session.id);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyState>();
    final subjects = context.watch<AppState>().subjects;
    final stats = study.stats;
    final progress = _totalSeconds == 0
        ? 0.0
        : (1 - _remaining / _totalSeconds).clamp(0.0, 1.0);
    final colors = context.colors;

    return RefreshIndicator(
      onRefresh: study.load,
      child: ListView(
        padding: v2PagePadding(context),
        children: [
          v2Centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1100
                        ? 4
                        : constraints.maxWidth >= 720
                        ? 2
                        : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 10) / columns;
                    final tiles = [
                      StatTile(
                        value: '${stats?.totalMinutesToday ?? 0} min',
                        label: 'Focused today',
                        icon: Icons.today_outlined,
                        tone: colors.primary,
                      ),
                      StatTile(
                        value: '${stats?.totalMinutesThisWeek ?? 0} min',
                        label: 'This week',
                        icon: Icons.date_range_outlined,
                        tone: colors.emerald,
                      ),
                      StatTile(
                        value: '${stats?.streakDays ?? 0}',
                        label: 'Day streak',
                        icon: Icons.local_fire_department_outlined,
                        tone: colors.amber,
                      ),
                      StatTile(
                        value: '${stats?.totalSessionsAllTime ?? 0}',
                        label: 'All-time sessions',
                        icon: Icons.timelapse_outlined,
                        tone: colors.textMuted,
                      ),
                    ];
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final tile in tiles)
                          SizedBox(width: width, child: tile),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final timer = _TimerCard(
                      mode: _mode,
                      modes: _modes,
                      minutes: _minutes,
                      remaining: _remaining,
                      progress: progress,
                      running: _running,
                      logging: _logging,
                      elapsedMinutes: _elapsedMinutes,
                      presets: _focusPresets,
                      subjects: subjects,
                      subjectId: _subjectId,
                      onMode: _selectMode,
                      onPreset: _selectMinutes,
                      onSubject: (value) => setState(() => _subjectId = value),
                      onToggle: _logging ? null : _toggle,
                      onReset: _reset,
                      onLog: _logging || _elapsedMinutes < 1 ? null : _finish,
                    );
                    final side = _HistoryPanel(
                      study: study,
                      modes: _modes,
                      onDelete: _delete,
                    );
                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [timer, const SizedBox(height: 12), side],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: timer),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: side),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.mode,
    required this.modes,
    required this.minutes,
    required this.remaining,
    required this.progress,
    required this.running,
    required this.logging,
    required this.elapsedMinutes,
    required this.presets,
    required this.subjects,
    required this.subjectId,
    required this.onMode,
    required this.onPreset,
    required this.onSubject,
    required this.onToggle,
    required this.onReset,
    required this.onLog,
  });

  final String mode;
  final Map<String, (String, int)> modes;
  final int minutes;
  final int remaining;
  final double progress;
  final bool running;
  final bool logging;
  final int elapsedMinutes;
  final List<int> presets;
  final List<Subject> subjects;
  final int? subjectId;
  final ValueChanged<String> onMode;
  final ValueChanged<int> onPreset;
  final ValueChanged<int?> onSubject;
  final VoidCallback? onToggle;
  final VoidCallback onReset;
  final VoidCallback? onLog;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = modes[mode]?.$1 ?? mode;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final entry in modes.entries)
                PillButton(
                  label: entry.value.$1,
                  icon: switch (entry.key) {
                    'focus' => Icons.center_focus_strong,
                    'short_break' => Icons.coffee_outlined,
                    _ => Icons.self_improvement_outlined,
                  },
                  selected: mode == entry.key,
                  tone: colors.primary,
                  dense: true,
                  onPressed: () => onMode(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 206,
            width: 206,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 206,
                  width: 206,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: colors.border.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation(colors.primary),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatDuration(Duration(seconds: remaining)),
                      style: TextStyle(
                        color: colors.textMain,
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (mode == 'focus')
            Wrap(
              spacing: 8,
              children: [
                for (final preset in presets)
                  PillButton(
                    label: '$preset min',
                    selected: minutes == preset,
                    dense: true,
                    onPressed: () => onPreset(preset),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: subjects.any((s) => s.id == subjectId)
                ? subjectId
                : null,
            decoration: const InputDecoration(
              labelText: 'Study for (optional)',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('General study')),
              for (final s in subjects)
                DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.code} · ${s.title}'),
                ),
            ],
            onChanged: onSubject,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onToggle,
                  icon: Icon(running ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    running
                        ? 'Pause'
                        : (remaining == 0 ? 'Restart' : 'Start focus'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconAction(
                icon: Icons.restart_alt,
                tooltip: 'Reset',
                onPressed: onReset,
              ),
              const SizedBox(width: 8),
              IconAction(
                icon: logging ? Icons.hourglass_top : Icons.save_outlined,
                tooltip: 'Log elapsed',
                onPressed: onLog,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.study,
    required this.modes,
    required this.onDelete,
  });

  final StudyState study;
  final Map<String, (String, int)> modes;
  final ValueChanged<StudySession> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stats = study.stats;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            title: 'Focus log',
            subtitle: 'Recent blocks and subject balance.',
          ),
          if ((stats?.bySubject ?? const []).isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in stats!.bySubject)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: hexToColor(item.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        item.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textMain,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: V2ProgressBar(
                        value:
                            (item.minutes /
                                    (stats.totalMinutesThisWeek == 0
                                        ? 1
                                        : stats.totalMinutesThisWeek))
                                .clamp(0.0, 1.0),
                        color: hexToColor(item.color),
                        height: 5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.minutes} min',
                      style: TextStyle(color: colors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20),
          ],
          if (study.sessions.isEmpty)
            Text(
              'No sessions yet. Start the timer to log your first focus block.',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                height: 1.5,
              ),
            )
          else
            for (final session in study.sessions.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: hexToColor(session.subjectColor)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        session.isFocus
                            ? Icons.center_focus_strong
                            : Icons.free_breakfast_outlined,
                        size: 15,
                        color: hexToColor(session.subjectColor),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${session.durationMinutes} min · ${modes[session.mode]?.$1 ?? session.mode}',
                            style: TextStyle(
                              color: colors.textMain,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              if (session.subjectCode != null)
                                session.subjectCode!,
                              if (session.completedAt != null)
                                '${session.completedAt!.month}/${session.completedAt!.day} '
                                    '${session.completedAt!.hour.toString().padLeft(2, '0')}:'
                                    '${session.completedAt!.minute.toString().padLeft(2, '0')}',
                            ].whereType<String>().join(' · '),
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconAction(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete session',
                      compact: true,
                      onPressed: () => onDelete(session),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
