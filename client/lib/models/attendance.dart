class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.subjectId,
    required this.date,
    required this.status,
    this.slotId,
    this.note,
  });

  final int id;
  final int subjectId;
  final int? slotId;
  final String date;
  final String status;
  final String? note;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'] as int,
        subjectId: json['subjectId'] as int,
        slotId: (json['slotId'] as num?)?.toInt(),
        date: json['date'] as String,
        status: json['status'] as String,
        note: json['note'] as String?,
      );
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.subjectId,
    required this.code,
    required this.title,
    required this.color,
    required this.present,
    required this.absent,
    required this.late,
    required this.cancelled,
    required this.counted,
    this.attendanceRate,
    this.absenceRate,
    this.warning = false,
  });

  final int subjectId;
  final String code;
  final String title;
  final String color;
  final int present;
  final int absent;
  final int late;
  final int cancelled;
  final int counted;
  final double? attendanceRate;
  final double? absenceRate;
  final bool warning;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) => AttendanceSummary(
        subjectId: json['subjectId'] as int,
        code: json['code'] as String,
        title: json['title'] as String,
        color: json['color'] as String? ?? '#4F46E5',
        present: (json['present'] as num?)?.toInt() ?? 0,
        absent: (json['absent'] as num?)?.toInt() ?? 0,
        late: (json['late'] as num?)?.toInt() ?? 0,
        cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
        counted: (json['counted'] as num?)?.toInt() ?? 0,
        attendanceRate: (json['attendanceRate'] as num?)?.toDouble(),
        absenceRate: (json['absenceRate'] as num?)?.toDouble(),
        warning: json['warning'] as bool? ?? false,
      );
}
