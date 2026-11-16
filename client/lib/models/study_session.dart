import 'json.dart';

/// A logged focus/break session (`GET /study/sessions`).
class StudySession {
  const StudySession({
    required this.id,
    required this.durationMinutes,
    this.subjectId,
    this.subjectCode,
    this.subjectColor,
    this.mode = 'focus',
    this.notes,
    this.completedAt,
  });

  final int id;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectColor;
  final int durationMinutes;
  final String mode;
  final String? notes;
  final DateTime? completedAt;

  bool get isFocus => mode == 'focus';

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
    id: asInt(json['id']) ?? 0,
    subjectId: asInt(json['subjectId']),
    subjectCode: json['subjectCode'] as String?,
    subjectColor: json['subjectColor'] as String?,
    durationMinutes: asInt(json['durationMinutes']) ?? 0,
    mode: json['mode'] as String? ?? 'focus',
    notes: json['notes'] as String?,
    completedAt: asLocalDate(json['completedAt']),
  );
}

/// Minutes studied for one subject inside [StudyStats].
class StudySubjectMinutes {
  const StudySubjectMinutes({
    required this.subjectId,
    required this.code,
    required this.minutes,
    this.color = '#4F46E5',
  });

  final int subjectId;
  final String code;
  final String color;
  final int minutes;

  factory StudySubjectMinutes.fromJson(Map<String, dynamic> json) =>
      StudySubjectMinutes(
        subjectId: asInt(json['subjectId']) ?? 0,
        code: json['code'] as String? ?? '',
        color: json['color'] as String? ?? '#4F46E5',
        minutes: asInt(json['minutes']) ?? 0,
      );
}

/// Aggregate study metrics from `GET /study/stats`.
class StudyStats {
  const StudyStats({
    this.totalMinutesToday = 0,
    this.totalMinutesThisWeek = 0,
    this.sessionsThisWeek = 0,
    this.totalSessionsAllTime = 0,
    this.allTimeMinutes = 0,
    this.streakDays = 0,
    this.bySubject = const [],
  });

  final int totalMinutesToday;
  final int totalMinutesThisWeek;
  final int sessionsThisWeek;
  final int totalSessionsAllTime;
  final int allTimeMinutes;
  final int streakDays;
  final List<StudySubjectMinutes> bySubject;

  factory StudyStats.fromJson(Map<String, dynamic> json) => StudyStats(
    totalMinutesToday: asInt(json['totalMinutesToday']) ?? 0,
    totalMinutesThisWeek: asInt(json['totalMinutesThisWeek']) ?? 0,
    sessionsThisWeek: asInt(json['sessionsThisWeek']) ?? 0,
    totalSessionsAllTime: asInt(json['totalSessionsAllTime']) ?? 0,
    allTimeMinutes: asInt(json['allTimeMinutes']) ?? 0,
    streakDays: asInt(json['streakDays']) ?? 0,
    bySubject: (json['bySubject'] as List? ?? const [])
        .map((e) => StudySubjectMinutes.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
