import 'package:flutter/material.dart';

/// Parse a `#RRGGBB` hex string into a Color, falling back to indigo.
Color hexToColor(String? hex, {Color fallback = const Color(0xFF4F46E5)}) {
  if (hex == null) return fallback;
  final value = hex.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null || value.length != 6) return fallback;
  return Color(0xFF000000 | parsed);
}

const List<String> dayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const List<String> dayShortNames = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

/// "08:00" -> "8:00 AM"
String formatClock(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = parts[1];
  final period = hour >= 12 ? 'PM' : 'AM';
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h:$minute $period';
}

/// "2026-11-15T..." -> "November 15, 2026".
String formatDate(String iso, {bool withTime = false}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final date = '${months[d.month - 1]} ${d.day}, ${d.year}';
  if (!withTime) return date;
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$date · $hour:$minute ${d.hour >= 12 ? 'PM' : 'AM'}';
}

/// "512 B", "48.2 KB", "3.4 MB"
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

/// "0:07", "1:05:00" for a remaining timer.
String formatDuration(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int v) => v.toString().padLeft(2, '0');
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '$m:${two(s)}';
}

/// Human-friendly relative due label, e.g. "in 3 days" / "overdue".
String dueLabel(DateTime? due, {DateTime? now}) {
  if (due == null) return 'No due date';
  final today = DateTime(
    (now ?? DateTime.now()).year,
    (now ?? DateTime.now()).month,
    (now ?? DateTime.now()).day,
  );
  final target = DateTime(due.year, due.month, due.day);
  final diff = target.difference(today).inDays;
  if (diff < 0) {
    return diff == -1 ? 'Overdue by 1 day' : 'Overdue by ${-diff} days';
  }
  if (diff == 0) return 'Due today';
  if (diff == 1) return 'Due tomorrow';
  return 'Due in $diff days';
}
