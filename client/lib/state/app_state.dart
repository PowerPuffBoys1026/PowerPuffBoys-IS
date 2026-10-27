import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/attendance.dart';
import '../models/dashboard.dart';
import '../models/grade.dart';
import '../models/note.dart';
import '../models/schedule_slot.dart';
import '../models/school_work.dart';
import '../models/study.dart';
import '../models/subject.dart';

/// Holds and mutates all app data for the signed-in user, keeping the list
/// screens and the dashboard in sync.
class AppState extends ChangeNotifier {
  AppState(this._api) {
    _loadThemePreference();
  }

  final Api _api;

  ThemeMode themeMode = ThemeMode.system;

  List<Subject> subjects = [];
  List<ScheduleSlot> slots = [];
  List<AttendanceSummary> summary = [];
  List<SchoolWork> works = [];
  DashboardData? dashboard;

  // New Student Feature States
  List<StudySession> studySessions = [];
  StudyStats? studyStats;
  List<SubjectNote> notes = [];
  GradeSummary? gradeSummary;

  bool loading = false;
  String? error;
  int? _accountId;

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString('classmate_theme_mode');
      if (mode == 'dark') {
        themeMode = ThemeMode.dark;
      } else if (mode == 'light') {
        themeMode = ThemeMode.light;
      } else {
        themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    if (themeMode == ThemeMode.dark) {
      themeMode = ThemeMode.light;
    } else {
      themeMode = ThemeMode.dark;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'classmate_theme_mode',
        themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }

  Future<void> switchAccount(int? accountId) async {
    if (_accountId == accountId) return;
    _accountId = accountId;
    subjects = [];
    slots = [];
    summary = [];
    works = [];
    dashboard = null;
    studySessions = [];
    studyStats = null;
    notes = [];
    gradeSummary = null;
    error = null;

    if (accountId != null) {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = prefs.getString('classmate_snapshot_$accountId');
      if (snapshot != null) {
        try {
          final data = jsonDecode(snapshot) as Map<String, dynamic>;
          subjects = (data['subjects'] as List? ?? [])
              .map((value) => Subject.fromJson(value as Map<String, dynamic>))
              .toList();
          slots = (data['slots'] as List? ?? [])
              .map(
                (value) => ScheduleSlot.fromJson(value as Map<String, dynamic>),
              )
              .toList();
          summary = (data['summary'] as List? ?? [])
              .map(
                (value) =>
                    AttendanceSummary.fromJson(value as Map<String, dynamic>),
              )
              .toList();
          works = (data['works'] as List? ?? [])
              .map(
                (value) => SchoolWork.fromJson(value as Map<String, dynamic>),
              )
              .toList();
          final cachedDashboard = data['dashboard'];
          dashboard = cachedDashboard == null
              ? null
              : DashboardData.fromJson(cachedDashboard as Map<String, dynamic>);
        } catch (_) {
          subjects = [];
          slots = [];
          summary = [];
          works = [];
          dashboard = null;
        }
      }
    }
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final requestedAccountId = _accountId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.subjects(),
        _api.schedule(),
        _api.attendanceSummary(),
        _api.works(),
        _api.dashboardToday(),
        _api.studyStats().catchError(
          (_) => const StudyStats(
            totalMinutesToday: 0,
            totalMinutesThisWeek: 0,
            sessionsThisWeek: 0,
            totalSessionsAllTime: 0,
            allTimeMinutes: 0,
            streakDays: 0,
            bySubject: [],
          ),
        ),
        _api.studySessions().catchError((_) => <StudySession>[]),
        _api.notes().catchError((_) => <SubjectNote>[]),
        _api.gradesSummary().catchError(
          (_) => const GradeSummary(
            academicStanding: 'On Track',
            totalUnitsCounted: 0,
            subjects: [],
          ),
        ),
      ]);

      if (_accountId != requestedAccountId) return;
      subjects = results[0] as List<Subject>;
      slots = results[1] as List<ScheduleSlot>;
      summary = results[2] as List<AttendanceSummary>;
      works = results[3] as List<SchoolWork>;
      dashboard = results[4] as DashboardData;
      studyStats = results[5] as StudyStats;
      studySessions = results[6] as List<StudySession>;
      notes = results[7] as List<SubjectNote>;
      gradeSummary = results[8] as GradeSummary;

      if (requestedAccountId != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'classmate_schedule_$requestedAccountId',
            jsonEncode(slots.map((slot) => slot.toJson()).toList()),
          );
          await prefs.setString(
            'classmate_snapshot_$requestedAccountId',
            jsonEncode({
              'subjects': subjects.map((subject) => subject.toJson()).toList(),
              'slots': slots.map((slot) => slot.toJson()).toList(),
              'summary': summary.map((item) => item.toJson()).toList(),
              'works': works.map((work) => work.toJson()).toList(),
              'dashboard': dashboard?.toJson(),
            }),
          );
        } catch (_) {}
      }
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not reach the server. Is the API running?';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _accountId = null;
    subjects = [];
    slots = [];
    summary = [];
    works = [];
    dashboard = null;
    studySessions = [];
    studyStats = null;
    notes = [];
    gradeSummary = null;
    error = null;
  }

  // ---- Quick Actions & Batch Attendance ------------------------------------

  Future<void> quickMarkToday({
    required int subjectId,
    int? slotId,
    required String status,
  }) async {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _api.markAttendance(
      subjectId: subjectId,
      slotId: slotId,
      date: today,
      status: status,
    );
    await refreshAll();
  }

  Future<void> markAllTodayPresent() async {
    final todayClasses = dashboard?.classes ?? [];
    if (todayClasses.isEmpty) return;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await Future.wait(
      todayClasses.map(
        (c) => _api.markAttendance(
          subjectId: c.subjectId,
          slotId: c.slotId,
          date: today,
          status: 'present',
        ),
      ),
    );
    await refreshAll();
  }

  // ---- Study Focus Sessions ------------------------------------------------

  Future<StudySession> recordStudySession({
    int? subjectId,
    required int durationMinutes,
    String mode = 'focus',
    String? notes,
  }) async {
    final session = await _api.createStudySession(
      subjectId: subjectId,
      durationMinutes: durationMinutes,
      mode: mode,
      notes: notes,
    );
    await refreshAll();
    return session;
  }

  Future<void> removeStudySession(int id) async {
    await _api.deleteStudySession(id);
    await refreshAll();
  }

  // ---- Subject Notes -------------------------------------------------------

  Future<void> addNote({
    int? subjectId,
    required String title,
    required String content,
    String? tags,
    bool isPinned = false,
  }) async {
    await _api.createNote(
      subjectId: subjectId,
      title: title,
      content: content,
      tags: tags,
      isPinned: isPinned,
    );
    await refreshAll();
  }

  Future<void> editNote(
    int id, {
    int? subjectId,
    String? title,
    String? content,
    String? tags,
    bool? isPinned,
  }) async {
    await _api.updateNote(
      id,
      subjectId: subjectId,
      title: title,
      content: content,
      tags: tags,
      isPinned: isPinned,
    );
    await refreshAll();
  }

  Future<void> removeNote(int id) async {
    await _api.deleteNote(id);
    await refreshAll();
  }

  // ---- Grade Calculator & Target Goals -------------------------------------

  Future<void> addGrade({
    required int subjectId,
    required String componentName,
    required double weightPct,
    double? scorePct,
    double targetPct = 85,
  }) async {
    await _api.createGrade(
      subjectId: subjectId,
      componentName: componentName,
      weightPct: weightPct,
      scorePct: scorePct,
      targetPct: targetPct,
    );
    await refreshAll();
  }

  Future<void> editGrade(
    int id, {
    String? componentName,
    double? weightPct,
    double? scorePct,
    double? targetPct,
  }) async {
    await _api.updateGrade(
      id,
      componentName: componentName,
      weightPct: weightPct,
      scorePct: scorePct,
      targetPct: targetPct,
    );
    await refreshAll();
  }

  Future<void> removeGrade(int id) async {
    await _api.deleteGrade(id);
    await refreshAll();
  }

  // ---- Subjects ------------------------------------------------------------

  Future<void> addSubject({
    required String code,
    required String title,
    String? instructor,
    String? instructorEmail,
    String? officeHours,
    int units = 0,
    String color = '#6366F1',
  }) async {
    await _api.createSubject(
      code: code,
      title: title,
      instructor: instructor,
      instructorEmail: instructorEmail,
      officeHours: officeHours,
      units: units,
      color: color,
    );
    await refreshAll();
  }

  Future<void> editSubject(
    int id, {
    required String code,
    required String title,
    String? instructor,
    String? instructorEmail,
    String? officeHours,
    int units = 0,
    String color = '#6366F1',
  }) async {
    await _api.updateSubject(
      id,
      code: code,
      title: title,
      instructor: instructor,
      instructorEmail: instructorEmail,
      officeHours: officeHours,
      units: units,
      color: color,
    );
    await refreshAll();
  }

  Future<void> removeSubject(int id) async {
    await _api.deleteSubject(id);
    await refreshAll();
  }

  // ---- Schedule ------------------------------------------------------------

  Future<void> addSlot({
    required int subjectId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    String? building,
    String? modality,
    String weekPattern = 'every',
  }) async {
    await _api.createSlot(
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      room: room,
      building: building,
      modality: modality,
      weekPattern: weekPattern,
    );
    await refreshAll();
  }

  Future<void> addSlots({
    required int subjectId,
    required List<int> daysOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    String? building,
    String? modality,
    String weekPattern = 'every',
  }) async {
    await Future.wait(
      daysOfWeek.map(
        (dayOfWeek) => _api.createSlot(
          subjectId: subjectId,
          dayOfWeek: dayOfWeek,
          startTime: startTime,
          endTime: endTime,
          room: room,
          building: building,
          modality: modality,
          weekPattern: weekPattern,
        ),
      ),
    );
    await refreshAll();
  }

  Future<void> removeSlot(int id) async {
    await _api.deleteSlot(id);
    await refreshAll();
  }

  Future<void> editSlot(
    int id, {
    required int subjectId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    String? building,
    String? modality,
    String weekPattern = 'every',
  }) async {
    await _api.updateSlot(
      id,
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      room: room,
      building: building,
      modality: modality,
      weekPattern: weekPattern,
    );
    await refreshAll();
  }

  // ---- Attendance ----------------------------------------------------------

  Future<void> markAttendance({
    required int subjectId,
    int? slotId,
    required String date,
    required String status,
    String? note,
  }) async {
    await _api.markAttendance(
      subjectId: subjectId,
      slotId: slotId,
      date: date,
      status: status,
      note: note,
    );
    await refreshAll();
  }

  Future<void> removeAttendance(int id) async {
    await _api.deleteAttendance(id);
    await refreshAll();
  }

  // ---- School works --------------------------------------------------------

  Future<void> addWork({
    required String title,
    int? subjectId,
    String type = 'assignment',
    DateTime? dueAt,
    String priority = 'medium',
    String? notes,
  }) async {
    await _api.createWork(
      title: title,
      subjectId: subjectId,
      type: type,
      dueAt: dueAt,
      priority: priority,
      notes: notes,
    );
    await refreshAll();
  }

  Future<void> setWorkStatus(int id, String status) async {
    await _api.updateWorkStatus(id, status);
    await refreshAll();
  }

  Future<void> editWork(
    int id, {
    required String title,
    int? subjectId,
    required String type,
    DateTime? dueAt,
    required String priority,
    required String status,
    String? notes,
  }) async {
    await _api.updateWork(
      id,
      title: title,
      subjectId: subjectId,
      type: type,
      dueAt: dueAt,
      priority: priority,
      status: status,
      notes: notes,
    );
    await refreshAll();
  }

  Future<void> removeWork(int id) async {
    await _api.deleteWork(id);
    await refreshAll();
  }
}
