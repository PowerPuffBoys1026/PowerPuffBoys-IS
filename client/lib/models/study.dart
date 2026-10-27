class StudySession {
  const StudySession({
    required this.id,
    this.subjectId,
    this.subjectCode,
    this.subjectColor,
    required this.durationMinutes,
    required this.mode,
    this.notes,
    required this.completedAt,
  });

  final int id;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectColor;
  final int durationMinutes;
  final String mode; // 'focus', 'short_break', 'long_break'
  final String? notes;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'subjectCode': subjectCode,
    'subjectColor': subjectColor,
    'durationMinutes': durationMinutes,
    'mode': mode,
    'notes': notes,
    'completedAt': completedAt.toIso8601String(),
  };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
    id: json['id'] as int,
    subjectId: (json['subjectId'] as num?)?.toInt(),
    subjectCode: json['subjectCode'] as String?,
    subjectColor: json['subjectColor'] as String?,
    durationMinutes: (json['durationMinutes'] as num).toInt(),
    mode: json['mode'] as String? ?? 'focus',
    notes: json['notes'] as String?,
    completedAt: DateTime.parse(json['completedAt'] as String),
  );
}

class SubjectStudyTime {
  const SubjectStudyTime({
    required this.subjectId,
    required this.code,
    required this.color,
    required this.minutes,
  });

  final int subjectId;
  final String code;
  final String color;
  final int minutes;

  factory SubjectStudyTime.fromJson(Map<String, dynamic> json) =>
      SubjectStudyTime(
        subjectId: (json['subjectId'] as num).toInt(),
        code: json['code'] as String,
        color: json['color'] as String? ?? '#4F46E5',
        minutes: (json['minutes'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'code': code,
    'color': color,
    'minutes': minutes,
  };
}

class StudyStats {
  const StudyStats({
    required this.totalMinutesToday,
    required this.totalMinutesThisWeek,
    required this.sessionsThisWeek,
    required this.totalSessionsAllTime,
    required this.allTimeMinutes,
    required this.streakDays,
    required this.bySubject,
  });

  final int totalMinutesToday;
  final int totalMinutesThisWeek;
  final int sessionsThisWeek;
  final int totalSessionsAllTime;
  final int allTimeMinutes;
  final int streakDays;
  final List<SubjectStudyTime> bySubject;

  factory StudyStats.fromJson(Map<String, dynamic> json) => StudyStats(
    totalMinutesToday: (json['totalMinutesToday'] as num?)?.toInt() ?? 0,
    totalMinutesThisWeek: (json['totalMinutesThisWeek'] as num?)?.toInt() ?? 0,
    sessionsThisWeek: (json['sessionsThisWeek'] as num?)?.toInt() ?? 0,
    totalSessionsAllTime: (json['totalSessionsAllTime'] as num?)?.toInt() ?? 0,
    allTimeMinutes: (json['allTimeMinutes'] as num?)?.toInt() ?? 0,
    streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
    bySubject: ((json['bySubject'] as List?) ?? [])
        .map((e) => SubjectStudyTime.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'totalMinutesToday': totalMinutesToday,
    'totalMinutesThisWeek': totalMinutesThisWeek,
    'sessionsThisWeek': sessionsThisWeek,
    'totalSessionsAllTime': totalSessionsAllTime,
    'allTimeMinutes': allTimeMinutes,
    'streakDays': streakDays,
    'bySubject': bySubject.map((e) => e.toJson()).toList(),
  };
}
