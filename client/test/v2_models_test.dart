import 'package:classmate/models/attachment.dart';
import 'package:classmate/models/grade.dart';
import 'package:classmate/models/note.dart';
import 'package:classmate/models/recycle_bin_item.dart';
import 'package:classmate/models/schedule_slot.dart';
import 'package:classmate/models/study_session.dart';
import 'package:classmate/models/subject.dart';
import 'package:classmate/models/user.dart';
import 'package:classmate/state/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('grade models', () {
    test('GradeComponent tolerates numeric strings', () {
      final grade = GradeComponent.fromJson({
        'id': 7,
        'subjectId': 2,
        'subjectCode': 'CS101',
        'subjectTitle': 'Intro',
        'componentName': 'Midterm',
        'weightPct': '30.0',
        'scorePct': '88.5',
        'targetPct': '90',
        'createdAt': '2026-10-01T08:00:00.000Z',
      });

      expect(grade.id, 7);
      expect(grade.subjectId, 2);
      expect(grade.weightPct, 30.0);
      expect(grade.scorePct, 88.5);
      expect(grade.targetPct, 90.0);
      expect(grade.isGraded, isTrue);
    });

    test('GradeComponent leaves ungraded scores null', () {
      final grade = GradeComponent.fromJson({
        'id': 1,
        'subjectId': 1,
        'componentName': 'Final',
        'weightPct': 40,
        'scorePct': null,
      });
      expect(grade.scorePct, isNull);
      expect(grade.isGraded, isFalse);
    });

    test('GradeSummary parses nested subjects and components', () {
      final summary = GradeSummary.fromJson({
        'cumulativeGpa': '3.42',
        'academicStanding': "Dean's List Pace",
        'totalUnitsCounted': '9',
        'subjects': [
          {
            'subjectId': 1,
            'code': 'CS101',
            'title': 'Intro',
            'units': 3,
            'color': '#123456',
            'componentsCount': 1,
            'currentPercentage': 88.5,
            'letterGrade': 'B+',
            'gpa': '3.3',
            'targetPercentage': 90,
            'remainingWeight': 70,
            'neededOnRemaining': 90.7,
            'components': [
              {'id': 5, 'componentName': 'Midterm', 'weightPct': 30, 'scorePct': 88.5, 'targetPct': 90},
            ],
          },
        ],
      });

      expect(summary.cumulativeGpa, 3.42);
      expect(summary.totalUnitsCounted, 9);
      expect(summary.subjects, hasLength(1));
      final subject = summary.subjects.first;
      expect(subject.code, 'CS101');
      expect(subject.gpa, 3.3);
      expect(subject.components.single.componentName, 'Midterm');
      expect(subject.components.single.scorePct, 88.5);
    });
  });

  group('study models', () {
    test('StudySession parses timestamps and mode', () {
      final session = StudySession.fromJson({
        'id': 3,
        'subjectId': 1,
        'subjectCode': 'CS101',
        'durationMinutes': '25',
        'mode': 'focus',
        'notes': 'library',
        'completedAt': '2026-11-01T12:30:00.000Z',
      });

      expect(session.id, 3);
      expect(session.durationMinutes, 25);
      expect(session.subjectCode, 'CS101');
      expect(session.isFocus, isTrue);
      expect(session.completedAt, isNotNull);
    });

    test('StudyStats parses aggregate totals', () {
      final stats = StudyStats.fromJson({
        'totalMinutesToday': 50,
        'totalMinutesThisWeek': '180',
        'sessionsThisWeek': 6,
        'totalSessionsAllTime': 40,
        'allTimeMinutes': 1000,
        'streakDays': 4,
        'bySubject': [
          {'subjectId': 1, 'code': 'CS101', 'color': '#fff', 'minutes': '75'},
        ],
      });

      expect(stats.totalMinutesThisWeek, 180);
      expect(stats.streakDays, 4);
      expect(stats.bySubject.single.minutes, 75);
    });
  });

  group('attachment model', () {
    test('detects images and extensions', () {
      final attachment = Attachment.fromJson({
        'id': 9,
        'resourceType': 'works',
        'resourceId': 4,
        'originalName': 'Rubric.PDF',
        'mimeType': 'application/pdf',
        'sizeBytes': '2048',
        'createdAt': '2026-11-02T01:00:00.000Z',
      });

      expect(attachment.sizeBytes, 2048);
      expect(attachment.extension, 'pdf');
      expect(attachment.isImage, isFalse);
      expect(attachment.isPdf, isTrue);
    });
  });

  group('recycle bin model', () {
    test('parses items and restore results', () {
      final item = RecycleBinItem.fromJson({
        'id': 12,
        'type': 'note',
        'label': 'Chapter 1',
        'deletedAt': '2026-11-05T00:00:00.000Z',
        'expiresAt': '2026-12-05T00:00:00.000Z',
      });
      expect(item.type, 'note');
      expect(item.label, 'Chapter 1');
      expect(item.expiresAt, isNotNull);

      final restored = RestoreResult.fromJson({'id': 12, 'type': 'note', 'label': 'Chapter 1'});
      expect(restored.id, 12);
      expect(restored.label, 'Chapter 1');
    });
  });

  group('extended fields', () {
    test('Subject exposes instructor email and office hours', () {
      final subject = Subject.fromJson({
        'id': 1,
        'code': 'CS101',
        'title': 'Intro',
        'instructor': 'Prof X',
        'instructorEmail': 'x@school.edu',
        'officeHours': 'MW 10-11',
        'units': 3,
        'color': '#4F46E5',
      });
      expect(subject.instructorEmail, 'x@school.edu');
      expect(subject.officeHours, 'MW 10-11');
    });

    test('ScheduleSlot defaults weekPattern', () {
      final slot = ScheduleSlot.fromJson({
        'id': 1,
        'subjectId': 1,
        'subjectCode': 'CS101',
        'subjectTitle': 'Intro',
        'color': '#4F46E5',
        'dayOfWeek': 1,
        'startTime': '08:00',
        'endTime': '09:30',
      });
      expect(slot.building, isNull);
      expect(slot.weekPattern, 'every');
    });

    test('Note keeps optional subject link', () {
      final note = Note.fromJson({
        'id': 1,
        'subjectId': 2,
        'subjectCode': 'CS101',
        'subjectTitle': 'Intro',
        'subjectColor': '#4F46E5',
        'title': 'Hi',
        'content': 'Body',
        'isPinned': false,
        'color': null,
        'tags': null,
        'createdAt': '2026-10-01',
        'updatedAt': '2026-10-02',
      });
      expect(note.subjectId, 2);
      expect(note.subjectCode, 'CS101');
    });

    test('User exposes yearLevel and createdAt', () {
      final user = User.fromJson({
        'id': 1,
        'email': 'a@b.c',
        'fullName': 'A B',
        'yearLevel': '3',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      expect(user.yearLevel, '3');
      expect(user.createdAt, isNotNull);
    });
  });

  group('SettingsState.normalizeServerUrl', () {
    test('keeps existing /api path', () {
      expect(
        SettingsState.normalizeServerUrl('http://192.168.1.24:3000/api'),
        'http://192.168.1.24:3000/api',
      );
    });

    test('adds scheme and default path', () {
      expect(
        SettingsState.normalizeServerUrl('192.168.1.24:3000'),
        'http://192.168.1.24:3000/api',
      );
    });

    test('trims spaces and trailing slashes', () {
      expect(
        SettingsState.normalizeServerUrl('  https://example.com/api/  '),
        'https://example.com/api',
      );
    });

    test('accepts a root URL and appends /api', () {
      expect(
        SettingsState.normalizeServerUrl('http://10.0.0.5:8080/'),
        'http://10.0.0.5:8080/api',
      );
    });

    test('rejects empty and non-http schemes', () {
      expect(() => SettingsState.normalizeServerUrl('   '), throwsFormatException);
      expect(() => SettingsState.normalizeServerUrl('ftp://example.com'), throwsFormatException);
      expect(() => SettingsState.normalizeServerUrl('http://'), throwsFormatException);
    });
  });
}
