import 'dart:convert';

import 'package:classmate/api/api.dart';
import 'package:classmate/api/api_client.dart';
import 'package:classmate/models/attendance.dart';
import 'package:classmate/models/dashboard.dart';
import 'package:classmate/models/grade.dart';
import 'package:classmate/models/note.dart';
import 'package:classmate/models/school_work.dart';
import 'package:classmate/models/study.dart';
import 'package:classmate/models/subject.dart';
import 'package:classmate/state/app_state.dart';
import 'package:classmate/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
            },
          ],
          'dueSoon': [],
          'attendanceWarnings': [],
        },
      });
      expect(dashboard.dayName, 'Monday');
      expect(dashboard.classes.single.code, 'CS101');
    });

    test('cached student snapshot models preserve their fields', () {
      final subject = Subject(
        id: 3,
        code: 'BIO201',
        title: 'Ecology',
        instructor: 'Dr. Lee',
        instructorEmail: 'lee@example.edu',
        officeHours: 'Tue 2:00 PM',
        units: 3,
        color: '#245B43',
      );
      final work = SchoolWork(
        id: 7,
        title: 'Field notes',
        subjectId: subject.id,
        dueAt: DateTime(2026, 10, 24, 15),
        priority: 'high',
        status: 'todo',
      );
      final attendance = AttendanceSummary(
        subjectId: subject.id,
        code: subject.code,
        title: subject.title,
        color: subject.color,
        present: 8,
        absent: 1,
        late: 1,
        cancelled: 0,
        counted: 10,
        attendanceRate: 0.9,
        absenceRate: 0.1,
        warning: true,
      );
      final dashboard = DashboardData(
        date: '2026-10-23',
        dayName: 'Friday',
        classes: const [
          DashboardClass(
            slotId: 9,
            subjectId: 3,
            code: 'BIO201',
            title: 'Ecology',
            color: '#245B43',
            startTime: '10:00',
            endTime: '11:30',
            room: 'B12',
          ),
        ],
        dueSoon: [
          DueSoonWork(
            id: 7,
            title: 'Field notes',
            dueAt: work.dueAt,
            priority: 'high',
            subjectCode: 'BIO201',
          ),
        ],
        attendanceWarnings: [attendance],
      );

      expect(
        Subject.fromJson(subject.toJson()).instructorEmail,
        subject.instructorEmail,
      );
      expect(SchoolWork.fromJson(work.toJson()).dueAt, work.dueAt);
      final restored = DashboardData.fromJson(dashboard.toJson());
      expect(restored.classes.single.room, 'B12');
      expect(restored.dueSoon.single.dueAt, work.dueAt);
      expect(restored.attendanceWarnings.single.warning, isTrue);
    });

    test('study, note, and grade models serialize and deserialize correctly', () {
      final now = DateTime(2026, 10, 23, 14, 0);
      final session = StudySession(
        id: 1,
        subjectId: 3,
        subjectCode: 'BIO201',
        durationMinutes: 25,
        mode: 'focus',
        notes: 'Reviewed mitosis',
        completedAt: now,
      );
      final restoredSession = StudySession.fromJson(session.toJson());
      expect(restoredSession.id, 1);
      expect(restoredSession.durationMinutes, 25);
      expect(restoredSession.subjectCode, 'BIO201');

      final note = SubjectNote(
        id: 10,
        subjectId: 3,
        title: 'Mitosis Steps',
        content: 'Prophase, Metaphase, Anaphase, Telophase',
        tags: 'exam,cells',
        isPinned: true,
        createdAt: now,
        updatedAt: now,
      );
      final restoredNote = SubjectNote.fromJson(note.toJson());
      expect(restoredNote.title, 'Mitosis Steps');
      expect(restoredNote.isPinned, isTrue);

      final grade = SubjectGrade(
        id: 5,
        subjectId: 3,
        componentName: 'Midterm',
        weightPct: 30,
        scorePct: 92,
        targetPct: 90,
      );
      final restoredGrade = SubjectGrade.fromJson(grade.toJson());
      expect(restoredGrade.componentName, 'Midterm');
      expect(restoredGrade.scorePct, 92);
    });
  });

  test('AppState restores snapshots per account', () async {
    SharedPreferences.setMockInitialValues({
      'classmate_snapshot_42': jsonEncode({
        'subjects': [
          {'id': 3, 'code': 'BIO201', 'title': 'Ecology'},
        ],
        'slots': [],
        'summary': [],
        'works': [
          {'id': 7, 'title': 'Field notes'},
        ],
        'dashboard': {
          'data': {
            'date': '2026-10-23',
            'dayName': 'Friday',
            'classes': [],
            'dueSoon': [],
            'attendanceWarnings': [],
          },
        },
      }),
    });
    final state = AppState(Api(ApiClient()));

    await state.switchAccount(42);
    expect(state.subjects.single.code, 'BIO201');
    expect(state.works.single.title, 'Field notes');
    expect(state.dashboard?.dayName, 'Friday');

    await state.switchAccount(43);
    expect(state.subjects, isEmpty);
    expect(state.works, isEmpty);
    expect(state.dashboard, isNull);
  });
}
