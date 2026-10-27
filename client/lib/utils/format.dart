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

const List<String> dayShortNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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

/// Human-friendly relative due label, e.g. "in 3 days" / "overdue".
String dueLabel(DateTime? due, {DateTime? now}) {
  if (due == null) return 'No due date';
  final today = DateTime((now ?? DateTime.now()).year, (now ?? DateTime.now()).month, (now ?? DateTime.now()).day);
  final target = DateTime(due.year, due.month, due.day);
  final diff = target.difference(today).inDays;
  if (diff < 0) return diff == -1 ? 'Overdue by 1 day' : 'Overdue by ${-diff} days';
  if (diff == 0) return 'Due today';
  if (diff == 1) return 'Due tomorrow';
  return 'Due in $diff days';
}
