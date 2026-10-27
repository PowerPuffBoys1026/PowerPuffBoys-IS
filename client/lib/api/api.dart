import '../models/attendance.dart';
import '../models/dashboard.dart';
import '../models/grade.dart';
import '../models/note.dart';
import '../models/schedule_slot.dart';
import '../models/school_work.dart';
import '../models/study.dart';
import '../models/subject.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});
  final String token;
  final User user;
}

/// Typed, domain-level access to the ClassMate REST API.
class Api {
  Api(this._client);

  final ApiClient _client;

  set token(String? value) => _client.token = value;

  // ---- Auth ----------------------------------------------------------------

  Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
    String? studentNo,
    String? course,
  }) async {
    final res = await _client.post('/auth/register', body: {
      'email': email,
      'password': password,
      'fullName': fullName,
      if (studentNo != null && studentNo.isNotEmpty) 'studentNo': studentNo,
      if (course != null && course.isNotEmpty) 'course': course,
    });
    return AuthResult(
      token: res['token'] as String,
      user: User.fromJson(res['user'] as Map<String, dynamic>),
    );
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final res = await _client.post('/auth/login', body: {'email': email, 'password': password});
    return AuthResult(
      token: res['token'] as String,
      user: User.fromJson(res['user'] as Map<String, dynamic>),
    );
  }

  Future<User> me() async {
    final res = await _client.get('/auth/me');
    return User.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<User> updateProfile({
    required String fullName,
    String? studentNo,
    String? course,
  }) async {
    final res = await _client.put('/auth/me', body: {
      'fullName': fullName,
      'studentNo': studentNo,
      'course': course,
    });
    return User.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ---- Subjects ------------------------------------------------------------

  Future<List<Subject>> subjects() async {
    final res = await _client.get('/subjects');
    return (res['data'] as List).map((e) => Subject.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Subject> createSubject({
    required String code,
    required String title,
    String? instructor,
    String? instructorEmail,
    String? officeHours,
    int units = 0,
    String color = '#7B1E2B',
  }) async {
    final res = await _client.post('/subjects', body: {
      'code': code,
      'title': title,
      if (instructor != null && instructor.isNotEmpty) 'instructor': instructor,
      if (instructorEmail != null && instructorEmail.isNotEmpty) 'instructorEmail': instructorEmail,
      if (officeHours != null && officeHours.isNotEmpty) 'officeHours': officeHours,
      'units': units,
      'color': color,
    });
    return Subject.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Subject> updateSubject(
    int id, {
    required String code,
    required String title,
    String? instructor,
    String? instructorEmail,
    String? officeHours,
    int units = 0,
    String color = '#7B1E2B',
  }) async {
    final res = await _client.put('/subjects/$id', body: {
      'code': code,
      'title': title,
      'instructor': instructor,
      'instructorEmail': instructorEmail,
      'officeHours': officeHours,
      'units': units,
      'color': color,
    });
    return Subject.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteSubject(int id) => _client.delete('/subjects/$id');

  // ---- Schedule ------------------------------------------------------------

  Future<List<ScheduleSlot>> schedule({int? day}) async {
    final res = await _client.get('/schedule', query: {'day': day});
    return (res['data'] as List).map((e) => ScheduleSlot.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ScheduleSlot> createSlot({
    required int subjectId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    String? building,
    String? modality,
    String weekPattern = 'every',
  }) async {
    final res = await _client.post('/schedule', body: {
      'subjectId': subjectId,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      if (room != null && room.isNotEmpty) 'room': room,
      if (building != null && building.isNotEmpty) 'building': building,
      if (modality != null && modality.isNotEmpty) 'modality': modality,
      'weekPattern': weekPattern,
    });
    return ScheduleSlot.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteSlot(int id) => _client.delete('/schedule/$id');

  Future<ScheduleSlot> updateSlot(
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
    final res = await _client.put('/schedule/$id', body: {
      'subjectId': subjectId,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'building': building,
      'modality': modality,
      'weekPattern': weekPattern,
    });
    return ScheduleSlot.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ---- Attendance ----------------------------------------------------------

  Future<List<AttendanceSummary>> attendanceSummary() async {
    final res = await _client.get('/attendance/summary');
    return (res['data'] as List).map((e) => AttendanceSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AttendanceRecord>> attendanceRecords({int? subjectId}) async {
    final res = await _client.get('/attendance', query: {'subjectId': subjectId});
    return (res['data'] as List).map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AttendanceRecord> markAttendance({
    required int subjectId,
    int? slotId,
    required String date,
    required String status,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'subjectId': subjectId,
      'date': date,
      'status': status,
    };
    if (slotId != null) body['slotId'] = slotId;
    if (note != null && note.isNotEmpty) body['note'] = note;
    final res = await _client.post('/attendance', body: body);
    return AttendanceRecord.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteAttendance(int id) => _client.delete('/attendance/$id');

  // ---- School works --------------------------------------------------------

  Future<List<SchoolWork>> works({String? status, int? subjectId}) async {
    final res = await _client.get('/works', query: {'status': status, 'subjectId': subjectId});
    return (res['data'] as List).map((e) => SchoolWork.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SchoolWork> createWork({
    required String title,
    int? subjectId,
    String type = 'assignment',
    DateTime? dueAt,
    String priority = 'medium',
    String status = 'todo',
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'type': type,
      'priority': priority,
      'status': status,
    };
    if (subjectId != null) body['subjectId'] = subjectId;
    if (dueAt != null) body['dueAt'] = dueAt.toUtc().toIso8601String();
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    final res = await _client.post('/works', body: body);
    return SchoolWork.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<SchoolWork> updateWorkStatus(int id, String status) async {
    final res = await _client.patch('/works/$id/status', body: {'status': status});
    return SchoolWork.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<SchoolWork> updateWork(
    int id, {
    required String title,
    int? subjectId,
    required String type,
    DateTime? dueAt,
    required String priority,
    required String status,
    String? notes,
  }) async {
    final res = await _client.put('/works/$id', body: {
      'title': title,
      'subjectId': subjectId,
      'type': type,
      'dueAt': dueAt?.toUtc().toIso8601String(),
      'priority': priority,
      'status': status,
      'notes': notes,
    });
    return SchoolWork.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteWork(int id) => _client.delete('/works/$id');

  // ---- Dashboard -----------------------------------------------------------

  Future<DashboardData> dashboardToday() async {
    final res = await _client.get('/dashboard/today');
    return DashboardData.fromJson(res as Map<String, dynamic>);
  }

  // ---- Study Focus Sessions ------------------------------------------------

  Future<List<StudySession>> studySessions() async {
    final res = await _client.get('/study/sessions');
    return (res['data'] as List)
        .map((e) => StudySession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StudySession> createStudySession({
    int? subjectId,
    required int durationMinutes,
    String mode = 'focus',
    String? notes,
  }) async {
    final res = await _client.post('/study/sessions', body: {
      'subjectId': ?subjectId,
      'durationMinutes': durationMinutes,
      'mode': mode,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return StudySession.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<StudyStats> studyStats() async {
    final res = await _client.get('/study/stats');
    return StudyStats.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteStudySession(int id) =>
      _client.delete('/study/sessions/$id');

  // ---- Subject Notes -------------------------------------------------------

  Future<List<SubjectNote>> notes({int? subjectId}) async {
    final res = await _client.get(
      '/notes',
      query: {'subjectId': ?subjectId},
    );
    return (res['data'] as List)
        .map((e) => SubjectNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubjectNote> createNote({
    int? subjectId,
    required String title,
    required String content,
    String? tags,
    bool isPinned = false,
  }) async {
    final res = await _client.post('/notes', body: {
      'subjectId': ?subjectId,
      'title': title,
      'content': content,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
      'isPinned': isPinned,
    });
    return SubjectNote.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<SubjectNote> updateNote(
    int id, {
    int? subjectId,
    String? title,
    String? content,
    String? tags,
    bool? isPinned,
  }) async {
    final res = await _client.put('/notes/$id', body: {
      'subjectId': ?subjectId,
      'title': ?title,
      'content': ?content,
      'tags': ?tags,
      'isPinned': ?isPinned,
    });
    return SubjectNote.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteNote(int id) => _client.delete('/notes/$id');

  // ---- Grade Calculator & Target Goals -------------------------------------

  Future<List<SubjectGrade>> grades() async {
    final res = await _client.get('/grades');
    return (res['data'] as List)
        .map((e) => SubjectGrade.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubjectGrade> createGrade({
    required int subjectId,
    required String componentName,
    required double weightPct,
    double? scorePct,
    double targetPct = 85,
  }) async {
    final res = await _client.post('/grades', body: {
      'subjectId': subjectId,
      'componentName': componentName,
      'weightPct': weightPct,
      'scorePct': ?scorePct,
      'targetPct': targetPct,
    });
    return SubjectGrade.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<SubjectGrade> updateGrade(
    int id, {
    String? componentName,
    double? weightPct,
    double? scorePct,
    double? targetPct,
  }) async {
    final res = await _client.put('/grades/$id', body: {
      'componentName': ?componentName,
      'weightPct': ?weightPct,
      'scorePct': ?scorePct,
      'targetPct': ?targetPct,
    });
    return SubjectGrade.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteGrade(int id) => _client.delete('/grades/$id');

  Future<GradeSummary> gradesSummary() async {
    final res = await _client.get('/grades/summary');
    return GradeSummary.fromJson(res['data'] as Map<String, dynamic>);
  }
}
