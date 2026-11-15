import '../models/attachment.dart';
import '../models/attendance.dart';
import '../models/dashboard.dart';
import '../models/grade.dart';
import '../models/note.dart';
import '../models/recycle_bin_item.dart';
import '../models/schedule_slot.dart';
import '../models/school_work.dart';
import '../models/study_session.dart';
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

  /// Effective API base URL (runtime override or build-time default).
  String get baseUrl => _client.baseUrl;

  ApiClient get raw => _client;

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
    String? yearLevel,
  }) async {
    final res = await _client.put('/auth/me', body: {
      'fullName': fullName,
      'studentNo': studentNo,
      'course': course,
      'yearLevel': yearLevel,
    });
    return User.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.put('/auth/me/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
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
    String color = '#4F46E5',
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
    String color = '#4F46E5',
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

  Future<ScheduleSlot> updateSlot(
    int id, {
    int? subjectId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? room,
    String? building,
    String? modality,
    String? weekPattern,
  }) async {
    final body = <String, dynamic>{};
    if (subjectId != null) body['subjectId'] = subjectId;
    if (dayOfWeek != null) body['dayOfWeek'] = dayOfWeek;
    if (startTime != null) body['startTime'] = startTime;
    if (endTime != null) body['endTime'] = endTime;
    if (room != null) body['room'] = room;
    if (building != null) body['building'] = building;
    if (modality != null) body['modality'] = modality;
    if (weekPattern != null) body['weekPattern'] = weekPattern;
    final res = await _client.put('/schedule/$id', body: body);
    return ScheduleSlot.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteSlot(int id) => _client.delete('/schedule/$id');

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

  Future<SchoolWork> updateWork(
    int id, {
    String? title,
    int? subjectId,
    bool clearSubject = false,
    String? type,
    DateTime? dueAt,
    bool clearDueAt = false,
    String? priority,
    String? status,
    String? notes,
    bool clearNotes = false,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (clearSubject) {
      body['subjectId'] = null;
    } else if (subjectId != null) {
      body['subjectId'] = subjectId;
    }
    if (type != null) body['type'] = type;
    if (clearDueAt) {
      body['dueAt'] = null;
    } else if (dueAt != null) {
      body['dueAt'] = dueAt.toUtc().toIso8601String();
    }
    if (priority != null) body['priority'] = priority;
    if (status != null) body['status'] = status;
    if (clearNotes) {
      body['notes'] = null;
    } else if (notes != null) {
      body['notes'] = notes;
    }
    final res = await _client.put('/works/$id', body: body);
    return SchoolWork.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<SchoolWork> updateWorkStatus(int id, String status) async {
    final res = await _client.patch('/works/$id/status', body: {'status': status});
    return SchoolWork.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteWork(int id) => _client.delete('/works/$id');

  // ---- Notes ---------------------------------------------------------------

  Future<List<Note>> notes({String? search, String? tag, bool? pinned, int? subjectId}) async {
    final query = <String, String>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (tag != null && tag.isNotEmpty) query['tag'] = tag;
    if (pinned != null) query['pinned'] = pinned.toString();
    if (subjectId != null) query['subjectId'] = subjectId.toString();
    final res = await _client.get('/notes', query: query.isEmpty ? null : query);
    return (res['data'] as List).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Note> createNote({
    String? title,
    String? content,
    bool isPinned = false,
    String? color,
    String? tags,
    int? subjectId,
  }) async {
    final body = <String, dynamic>{
      if (title != null && title.isNotEmpty) 'title': title,
      'content': ?content,
      if (isPinned) 'isPinned': isPinned,
      'color': ?color,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
      'subjectId': ?subjectId,
    };
    final res = await _client.post('/notes', body: body);
    return Note.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Note> updateNote(
    int id, {
    String? title,
    String? content,
    bool? isPinned,
    String? color,
    String? tags,
    int? subjectId,
    bool clearSubject = false,
  }) async {
    final body = <String, dynamic>{
      'title': ?title,
      'content': ?content,
      'isPinned': ?isPinned,
      'color': ?color,
      'tags': ?tags,
      if (clearSubject) 'subjectId': null,
      if (!clearSubject && subjectId != null) 'subjectId': subjectId,
    };
    final res = await _client.put('/notes/$id', body: body);
    return Note.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Note> togglePinNote(int id) async {
    final res = await _client.patch('/notes/$id/pin');
    return Note.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteNote(int id) => _client.delete('/notes/$id');

  // ---- Grades --------------------------------------------------------------

  Future<List<GradeComponent>> grades({int? subjectId}) async {
    final res = await _client.get('/grades', query: {'subjectId': subjectId});
    return (res['data'] as List).map((e) => GradeComponent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GradeComponent> createGrade({
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
      'scorePct': scorePct,
      'targetPct': targetPct,
    });
    return GradeComponent.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<GradeComponent> updateGrade(
    int id, {
    String? componentName,
    double? weightPct,
    double? scorePct,
    bool clearScore = false,
    double? targetPct,
  }) async {
    final body = <String, dynamic>{};
    if (componentName != null) body['componentName'] = componentName;
    if (weightPct != null) body['weightPct'] = weightPct;
    if (clearScore) {
      body['scorePct'] = null;
    } else if (scorePct != null) {
      body['scorePct'] = scorePct;
    }
    if (targetPct != null) body['targetPct'] = targetPct;
    final res = await _client.put('/grades/$id', body: body);
    return GradeComponent.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteGrade(int id) => _client.delete('/grades/$id');

  Future<GradeSummary> gradeSummary() async {
    final res = await _client.get('/grades/summary');
    return GradeSummary.fromJson(res is Map<String, dynamic> && res['data'] is Map<String, dynamic> ? res['data'] : res);
  }

  // ---- Study sessions ------------------------------------------------------

  Future<List<StudySession>> studySessions({int? subjectId}) async {
    final res = await _client.get('/study/sessions', query: {'subjectId': subjectId});
    return (res['data'] as List).map((e) => StudySession.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<void> deleteStudySession(int id) => _client.delete('/study/sessions/$id');

  Future<StudyStats> studyStats() async {
    final res = await _client.get('/study/stats');
    return StudyStats.fromJson(res is Map<String, dynamic> && res['data'] is Map<String, dynamic> ? res['data'] : res);
  }

  // ---- Attachments ---------------------------------------------------------

  Future<List<Attachment>> attachments(String resourceType, int resourceId) async {
    final res = await _client.get('/attachments/$resourceType/$resourceId');
    return (res['data'] as List).map((e) => Attachment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Attachment> uploadAttachment({
    required String resourceType,
    required int resourceId,
    required String filePath,
    required String fileName,
  }) async {
    final res = await _client.postMultipart(
      '/attachments/$resourceType/$resourceId',
      filePath: filePath,
      fileName: fileName,
    );
    return Attachment.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Attachment> uploadAttachmentBytes({
    required String resourceType,
    required int resourceId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final res = await _client.postMultipartBytes(
      '/attachments/$resourceType/$resourceId',
      bytes: bytes,
      fileName: fileName,
    );
    return Attachment.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<List<int>> downloadAttachment(int id) => _client.getBytes('/attachments/$id/download');

  Future<void> deleteAttachment(int id) => _client.delete('/attachments/$id');

  // ---- Recycle bin ---------------------------------------------------------

  Future<List<RecycleBinItem>> recycleBin() async {
    final res = await _client.get('/recycle_bin');
    return (res['data'] as List).map((e) => RecycleBinItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RestoreResult> restoreRecycleItem(int id) async {
    final res = await _client.post('/recycle_bin/$id/restore');
    return RestoreResult.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteRecycleItem(int id) => _client.delete('/recycle_bin/$id');

  // ---- Dashboard -----------------------------------------------------------

  Future<DashboardData> dashboardToday() async {
    final res = await _client.get('/dashboard/today');
    return DashboardData.fromJson(res as Map<String, dynamic>);
  }
}
