import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/subject.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  // Timer modes
  static const int _focusSeconds = 25 * 60;
  static const int _shortBreakSeconds = 5 * 60;
  static const int _longBreakSeconds = 15 * 60;

  String _mode = 'focus'; // 'focus', 'short_break', 'long_break'
  int _totalSeconds = _focusSeconds;
  int _remainingSeconds = _focusSeconds;
  bool _isRunning = false;
  Timer? _timer;

  int? _selectedSubjectId;
  String _ambientSound = 'rain'; // 'rain', 'cafe', 'forest', 'lofi', 'none'
  bool _ambientActive = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _switchMode(String mode) {
    if (_isRunning) _pauseTimer();
    setState(() {
      _mode = mode;
      switch (mode) {
        case 'short_break':
          _totalSeconds = _shortBreakSeconds;
          break;
        case 'long_break':
          _totalSeconds = _longBreakSeconds;
          break;
        case 'focus':
        default:
          _totalSeconds = _focusSeconds;
          break;
      }
      _remainingSeconds = _totalSeconds;
    });
  }

  void _startTimer() {
    if (_timer != null) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _timer = null;
        setState(() => _isRunning = false);
        _onSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() => _remainingSeconds = _totalSeconds);
  }

  Future<void> _onSessionComplete() async {
    final app = context.read<AppState>();
    final minutes = (_totalSeconds / 60).round();

    if (_mode == 'focus') {
      try {
        await app.recordStudySession(
          subjectId: _selectedSubjectId,
          durationMinutes: minutes,
          mode: 'focus',
          notes: 'Completed $_mode session',
        );
      } catch (_) {}
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.amber, size: 28),
            const SizedBox(width: 10),
            Text(_mode == 'focus' ? 'Session Complete! 🎉' : 'Break Finished! ☕'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _mode == 'focus'
                  ? 'Awesome focus! You just logged $minutes minutes of deep work.'
                  : 'Ready to dive back into learning? Reset when you are set.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PortalColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: PortalColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '+$minutes XP Added to your Scholar Rank',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PortalColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _switchMode(_mode == 'focus' ? 'short_break' : 'focus');
            },
            child: Text(
              _mode == 'focus' ? 'Take 5m Break' : 'Start Focus Session',
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimer(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final stats = app.studyStats;
    final sessions = app.studySessions;
    final subjects = app.subjects;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final progress = _totalSeconds > 0
        ? (1.0 - (_remainingSeconds / _totalSeconds)).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Stats Strip
                  _StudyHeaderStats(
                    streakDays: stats?.streakDays ?? 0,
                    todayMinutes: stats?.totalMinutesToday ?? 0,
                    weekMinutes: stats?.totalMinutesThisWeek ?? 0,
                    totalSessions: stats?.totalSessionsAllTime ?? 0,
                  ),
                  const SizedBox(height: 24),

                  // Timer Main Card
                  Card(
                    elevation: isDark ? 0 : 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 24,
                      ),
                      child: Column(
                        children: [
                          // Mode Selector Pills
                          _ModePillBar(
                            activeMode: _mode,
                            onSelect: _switchMode,
                          ),
                          const SizedBox(height: 36),

                          // Circular Timer Ring
                          ScaleTransition(
                            scale: _isRunning
                                ? _pulseAnimation
                                : const AlwaysStoppedAnimation(1.0),
                            child: SizedBox(
                              width: 260,
                              height: 260,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Background track
                                  CustomPaint(
                                    size: const Size(260, 260),
                                    painter: _RadialProgressPainter(
                                      progress: progress,
                                      trackColor: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFE2E8F0),
                                      progressColor: _mode == 'focus'
                                          ? PortalColors.primary
                                          : PortalColors.emerald,
                                    ),
                                  ),
                                  // Center Display
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTimer(_remainingSeconds),
                                        style: TextStyle(
                                          fontSize: 54,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                          color: isDark
                                              ? PortalColors.inkDark
                                              : PortalColors.inkLight,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (_mode == 'focus'
                                                  ? PortalColors.primary
                                                  : PortalColors.emerald)
                                              .withAlpha(28),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _mode == 'focus'
                                              ? 'DEEP FOCUS'
                                              : (_mode == 'short_break'
                                                  ? 'SHORT BREAK'
                                                  : 'LONG BREAK'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: _mode == 'focus'
                                                ? PortalColors.primary
                                                : PortalColors.emerald,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Controls: Play, Pause, Reset
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Reset Timer',
                                iconSize: 22,
                                onPressed: _resetTimer,
                                icon: const Icon(Icons.refresh),
                              ),
                              const SizedBox(width: 16),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed:
                                    _isRunning ? _pauseTimer : _startTimer,
                                icon: Icon(
                                  _isRunning ? Icons.pause : Icons.play_arrow,
                                  size: 26,
                                ),
                                label: Text(
                                  _isRunning ? 'Pause' : 'Start Focus',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Subject Selector Dropdown
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: DropdownButtonFormField<int?>(
                              initialValue: _selectedSubjectId,
                              decoration: InputDecoration(
                                labelText: 'Tag with Course',
                                prefixIcon: const Icon(
                                  Icons.school_outlined,
                                  size: 20,
                                ),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('General Study (Untagged)'),
                                ),
                                for (final s in subjects)
                                  DropdownMenuItem<int?>(
                                    value: s.id,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: hexToColor(s.color),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${s.code} · ${s.title}'),
                                      ],
                                    ),
                                  ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedSubjectId = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ambient Audio & Soundscape Generator
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.headphones_outlined,
                                color: PortalColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Ambient Study Soundscapes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _ambientActive,
                                activeThumbColor: PortalColors.primary,
                                onChanged: (val) =>
                                    setState(() => _ambientActive = val),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _ambientActive
                                ? 'Now Playing: ${_soundName(_ambientSound)} ambience'
                                : 'Choose a calming soundscape to block distractions and trigger focus.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? PortalColors.mutedDark
                                  : PortalColors.mutedLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _SoundOption(
                                  icon: Icons.water_drop_outlined,
                                  label: 'Rainfall',
                                  isSelected: _ambientSound == 'rain',
                                  onTap: () => setState(() {
                                    _ambientSound = 'rain';
                                    _ambientActive = true;
                                  }),
                                ),
                                const SizedBox(width: 10),
                                _SoundOption(
                                  icon: Icons.coffee_outlined,
                                  label: 'Coffee Shop',
                                  isSelected: _ambientSound == 'cafe',
                                  onTap: () => setState(() {
                                    _ambientSound = 'cafe';
                                    _ambientActive = true;
                                  }),
                                ),
                                const SizedBox(width: 10),
                                _SoundOption(
                                  icon: Icons.forest_outlined,
                                  label: 'Deep Woods',
                                  isSelected: _ambientSound == 'forest',
                                  onTap: () => setState(() {
                                    _ambientSound = 'forest';
                                    _ambientActive = true;
                                  }),
                                ),
                                const SizedBox(width: 10),
                                _SoundOption(
                                  icon: Icons.album_outlined,
                                  label: 'Lo-Fi Chill',
                                  isSelected: _ambientSound == 'lofi',
                                  onTap: () => setState(() {
                                    _ambientSound = 'lofi';
                                    _ambientActive = true;
                                  }),
                                ),
                              ],
                            ),
                          ),
                          if (_ambientActive) ...[
                            const SizedBox(height: 16),
                            _SoundVisualizer(isDark: isDark),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Focus Sessions List
                  if (sessions.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Completed Sessions',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${sessions.length} sessions logged',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? PortalColors.mutedDark
                                : PortalColors.mutedLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: math.min(5, sessions.length),
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final s = sessions[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: s.subjectColor != null
                                  ? hexToColor(s.subjectColor!)
                                  : PortalColors.primary,
                              radius: 18,
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              s.subjectCode != null
                                  ? '${s.subjectCode} Focus'
                                  : 'Deep Work Session',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              s.notes ??
                                  'Completed ${s.durationMinutes} minutes of focused study',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              '${s.durationMinutes}m',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: PortalColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _soundName(String key) {
    switch (key) {
      case 'rain':
        return 'Gentle Rain';
      case 'cafe':
        return 'Campus Cafe';
      case 'forest':
        return 'Nature Forest';
      case 'lofi':
        return 'Chill Lo-Fi Beats';
      default:
        return 'Ambience';
    }
  }
}

class _RadialProgressPainter extends CustomPainter {
  const _RadialProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 14;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _StudyHeaderStats extends StatelessWidget {
  const _StudyHeaderStats({
    required this.streakDays,
    required this.todayMinutes,
    required this.weekMinutes,
    required this.totalSessions,
  });

  final int streakDays;
  final int todayMinutes;
  final int weekMinutes;
  final int totalSessions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 580;
        final items = [
          _StatTile(
            icon: Icons.local_fire_department,
            color: Colors.deepOrange,
            title: '$streakDays Days',
            subtitle: 'Study Streak 🔥',
          ),
          _StatTile(
            icon: Icons.timer_outlined,
            color: PortalColors.primary,
            title: '${todayMinutes}m',
            subtitle: 'Studied Today',
          ),
          _StatTile(
            icon: Icons.insights_outlined,
            color: PortalColors.emerald,
            title: '${weekMinutes}m',
            subtitle: 'Past 7 Days',
          ),
          _StatTile(
            icon: Icons.workspace_premium_outlined,
            color: Colors.amber,
            title: '$totalSessions',
            subtitle: 'Total Sessions',
          ),
        ];

        if (!wide) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: items,
          );
        }

        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: items[i]),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PortalColors.muted,
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

class _ModePillBar extends StatelessWidget {
  const _ModePillBar({required this.activeMode, required this.onSelect});

  final String activeMode;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF131A2A)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeItem(
            label: 'Focus (25m)',
            isSelected: activeMode == 'focus',
            onTap: () => onSelect('focus'),
          ),
          _ModeItem(
            label: 'Short Break (5m)',
            isSelected: activeMode == 'short_break',
            onTap: () => onSelect('short_break'),
          ),
          _ModeItem(
            label: 'Long Break (15m)',
            isSelected: activeMode == 'long_break',
            onTap: () => onSelect('long_break'),
          ),
        ],
      ),
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF28344E) : Colors.white)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected && !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? PortalColors.primary
                  : (isDark ? PortalColors.mutedDark : PortalColors.mutedLight),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundOption extends StatelessWidget {
  const _SoundOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? PortalColors.primary.withAlpha(25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? PortalColors.primary : Colors.grey.withAlpha(60),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? PortalColors.primary : PortalColors.muted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? PortalColors.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundVisualizer extends StatefulWidget {
  const _SoundVisualizer({required this.isDark});

  final bool isDark;

  @override
  State<_SoundVisualizer> createState() => _SoundVisualizerState();
}

class _SoundVisualizerState extends State<_SoundVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF0F172A)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (i) {
              final offset = (i * 0.15) % 1.0;
              final height = 6 + 22 * math.sin((_anim.value + offset) * math.pi);
              return Container(
                width: 3,
                height: height.clamp(4.0, 26.0),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: PortalColors.primary.withValues(alpha: 0.4 + (i % 3) * 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
