import 'attendance.dart';

class DashboardClass {
  const DashboardClass({
    required this.slotId,
    required this.subjectId,
    required this.code,
    required this.title,
    required this.color,
    required this.startTime,
    required this.endTime,
    this.room,
    this.modality,
  });

  final int slotId;
  final int subjectId;
  final String code;
  final String title;
  final String color;
  final String startTime;
  final String endTime;
  final String? room;
  final String? modality;

  factory DashboardClass.fromJson(Map<String, dynamic> json) => DashboardClass(
        slotId: json['slotId'] as int,
        subjectId: json['subjectId'] as int,
        code: json['code'] as String,
        title: json['title'] as String,
        color: json['color'] as String? ?? '#4F46E5',
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        room: json['room'] as String?,
        modality: json['modality'] as String?,
      );
}

class DueSoonWork {
  const DueSoonWork({
    required this.id,
    required this.title,
    this.type = 'assignment',
    this.dueAt,
    this.priority = 'medium',
    this.status = 'todo',
    this.subjectCode,
    this.color,
    this.overdue = false,
  });

  final int id;
  final String title;
  final String type;
  final DateTime? dueAt;
  final String priority;
  final String status;
  final String? subjectCode;
  final String? color;
  final bool overdue;

  factory DueSoonWork.fromJson(Map<String, dynamic> json) => DueSoonWork(
        id: json['id'] as int,
        title: json['title'] as String,
        type: json['type'] as String? ?? 'assignment',
        dueAt: json['dueAt'] != null ? DateTime.tryParse(json['dueAt'] as String)?.toLocal() : null,
        priority: json['priority'] as String? ?? 'medium',
        status: json['status'] as String? ?? 'todo',
        subjectCode: json['subjectCode'] as String?,
        color: json['color'] as String?,
        overdue: json['overdue'] as bool? ?? false,
      );
}

class DashboardData {
  const DashboardData({
    required this.date,
    required this.dayName,
    required this.classes,
    required this.dueSoon,
    required this.attendanceWarnings,
  });

  final String date;
  final String dayName;
  final List<DashboardClass> classes;
  final List<DueSoonWork> dueSoon;
  final List<AttendanceSummary> attendanceWarnings;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return DashboardData(
      date: data['date'] as String,
      dayName: data['dayName'] as String,
      classes: (data['classes'] as List)
          .map((e) => DashboardClass.fromJson(e as Map<String, dynamic>))
          .toList(),
      dueSoon: (data['dueSoon'] as List)
          .map((e) => DueSoonWork.fromJson(e as Map<String, dynamic>))
          .toList(),
      attendanceWarnings: (data['attendanceWarnings'] as List)
          .map((e) => AttendanceSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
