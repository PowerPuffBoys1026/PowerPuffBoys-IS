import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/study_session.dart';
import '../state/app_state.dart';
import '../state/study_state.dart';
import '../utils/format.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged $minutes min (${_modes[_mode]!.$1})')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _delete(StudySession session) async {
    try {
      await context.read<StudyState>().remove(session.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyState>();
    final subjects = context.watch<AppState>().subjects;
    final stats = study.stats;
    final progress = _totalSeconds == 0 ? 0.0 : (1 - _remaining / _totalSeconds).clamp(0.0, 1.0);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: study.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final entry in _modes.entries)
                          ChoiceChip(
                            label: Text(entry.value.$1),
                            selected: _mode == entry.key,
                            onSelected: (_) => _selectMode(entry.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 180,
                            width: 180,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 10,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatDuration(Duration(seconds: _remaining)),
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$_minutes min',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_mode == 'focus')
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final preset in _focusPresets)
                            ChoiceChip(
                              label: Text('$preset min'),
                              selected: _minutes == preset,
                              onSelected: (_) => _selectMinutes(preset),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _subjectId,
                      decoration: const InputDecoration(labelText: 'Subject (optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('General study')),
                        for (final s in subjects)
                          DropdownMenuItem(value: s.id, child: Text('${s.code} · ${s.title}')),
                      ],
                      onChanged: (v) => setState(() => _subjectId = v),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _logging ? null : _toggle,
                            icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                            label: Text(_running ? 'Pause' : 'Start'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Reset',
                          onPressed: _reset,
                          icon: const Icon(Icons.restart_alt),
                        ),
                        IconButton(
                          tooltip: 'Log elapsed',
                          onPressed: _logging || _elapsedMinutes < 1 ? null : _finish,
                          icon: _logging
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Study stats', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Stat(label: 'Today', value: '${stats?.totalMinutesToday ?? 0} min'),
                    _Stat(label: 'This week', value: '${stats?.totalMinutesThisWeek ?? 0} min'),
                    _Stat(label: 'Sessions', value: '${stats?.totalSessionsAllTime ?? 0}'),
                    _Stat(label: 'Streak', value: '${stats?.streakDays ?? 0} days'),
                  ],
                ),
              ),
            ),
            if ((stats?.bySubject ?? const []).isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      for (final item in stats!.bySubject)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: hexToColor(item.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item.code)),
                              Text('${item.minutes} min',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Recent sessions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (study.sessions.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.timer_outlined),
                  title: Text('No sessions yet'),
                  subtitle: Text('Start the timer to log your first focus block.'),
                ),
              )
            else
              for (final session in study.sessions.take(10))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      session.isFocus ? Icons.center_focus_strong : Icons.free_breakfast_outlined,
                      color: hexToColor(session.subjectColor),
                    ),
                    title: Text(
                      '${session.durationMinutes} min · ${_modes[session.mode]?.$1 ?? session.mode}',
                    ),
                    subtitle: Text(
                      [
                        if (session.subjectCode != null) session.subjectCode!,
                        if (session.completedAt != null)
                          '${session.completedAt!.month}/${session.completedAt!.day} '
                              '${session.completedAt!.hour.toString().padLeft(2, '0')}:'
                              '${session.completedAt!.minute.toString().padLeft(2, '0')}',
                      ].whereType<String>().join(' · '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete session',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _delete(session),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
