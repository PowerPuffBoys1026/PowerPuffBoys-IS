class ScheduleSlot {
  const ScheduleSlot({
    required this.id,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectTitle,
    required this.color,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    this.modality,
  });

  final int id;
  final int subjectId;
  final String subjectCode;
  final String subjectTitle;
  final String color;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? room;
  final String? modality;

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) => ScheduleSlot(
        id: json['id'] as int,
        subjectId: json['subjectId'] as int,
        subjectCode: json['subjectCode'] as String? ?? '',
        subjectTitle: json['subjectTitle'] as String? ?? '',
        color: json['color'] as String? ?? '#4F46E5',
        dayOfWeek: json['dayOfWeek'] as int,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        room: json['room'] as String?,
        modality: json['modality'] as String?,
      );
}
