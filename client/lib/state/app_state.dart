import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/attendance.dart';
import '../models/dashboard.dart';
import '../models/schedule_slot.dart';
import '../models/school_work.dart';
import '../models/subject.dart';

/// Holds and mutates all app data for the signed-in user, keeping the list
/// screens and the dashboard in sync.
class AppState extends ChangeNotifier {
  AppState(this._api);

  final Api _api;

  List<Subject> subjects = [];
  List<ScheduleSlot> slots = [];
  List<AttendanceSummary> summary = [];
  List<SchoolWork> works = [];
  DashboardData? dashboard;

  bool loading = false;
  String? error;

  Future<void> refreshAll() async {
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
      ]);
      subjects = results[0] as List<Subject>;
      slots = results[1] as List<ScheduleSlot>;
      summary = results[2] as List<AttendanceSummary>;
      works = results[3] as List<SchoolWork>;
      dashboard = results[4] as DashboardData;
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
    subjects = [];
    slots = [];
    summary = [];
    works = [];
    dashboard = null;
    error = null;
  }

  // ---- Subjects ------------------------------------------------------------

  Future<void> addSubject({
    required String code,
    required String title,
    String? instructor,
    int units = 0,
    String color = '#4F46E5',
  }) async {
    await _api.createSubject(
      code: code,
      title: title,
      instructor: instructor,
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
    int units = 0,
    String color = '#4F46E5',
  }) async {
    await _api.updateSubject(id, code: code, title: title, instructor: instructor, units: units, color: color);
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
    String? modality,
  }) async {
    await _api.createSlot(
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      room: room,
      modality: modality,
    );
    await refreshAll();
  }

  Future<void> removeSlot(int id) async {
    await _api.deleteSlot(id);
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

  Future<void> removeWork(int id) async {
    await _api.deleteWork(id);
    await refreshAll();
  }
}
