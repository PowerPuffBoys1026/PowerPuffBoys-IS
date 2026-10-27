import 'package:classmate/models/dashboard.dart';
import 'package:classmate/models/school_work.dart';
import 'package:classmate/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('format helpers', () {
    test('formatClock converts 24h to 12h', () {
      expect(formatClock('08:00'), '8:00 AM');
      expect(formatClock('13:05'), '1:05 PM');
      expect(formatClock('00:30'), '12:30 AM');
      expect(formatClock('12:00'), '12:00 PM');
    });

    test('dueLabel reports relative days', () {
      final now = DateTime(2026, 10, 12);
      expect(dueLabel(null), 'No due date');
      expect(dueLabel(DateTime(2026, 10, 12), now: now), 'Due today');
      expect(dueLabel(DateTime(2026, 10, 13), now: now), 'Due tomorrow');
      expect(dueLabel(DateTime(2026, 10, 15), now: now), 'Due in 3 days');
      expect(dueLabel(DateTime(2026, 10, 10), now: now), 'Overdue by 2 days');
    });

    test('hexToColor parses and falls back', () {
      expect(hexToColor('#4F46E5').toARGB32(), 0xFF4F46E5);
      expect(hexToColor('nope').toARGB32(), 0xFF4F46E5);
    });
  });

  group('models', () {
    test('SchoolWork parses dueAt to local time', () {
      final work = SchoolWork.fromJson({
        'id': 1,
        'title': 'Lab 1',
        'type': 'assignment',
        'dueAt': '2026-10-15T15:00:00.000Z',
        'priority': 'high',
        'status': 'todo',
      });
      expect(work.id, 1);
      expect(work.dueAt?.isUtc, false);
      expect(work.priority, 'high');
    });

    test('DashboardData unwraps the data envelope', () {
      final dashboard = DashboardData.fromJson({
        'data': {
          'date': '2026-10-12',
          'dayName': 'Monday',
          'classes': [
            {
              'slotId': 1,
              'subjectId': 2,
              'code': 'CS101',
              'title': 'Intro',
              'color': '#4F46E5',
              'startTime': '08:00',
              'endTime': '09:30',
            }
          ],
          'dueSoon': [],
          'attendanceWarnings': [],
        }
      });
      expect(dashboard.dayName, 'Monday');
      expect(dashboard.classes.single.code, 'CS101');
    });
  });
}
