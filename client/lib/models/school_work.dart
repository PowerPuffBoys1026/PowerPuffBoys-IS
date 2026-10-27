class SchoolWork {
  const SchoolWork({
    required this.id,
    required this.title,
    this.subjectId,
    this.subjectCode,
    this.subjectTitle,
    this.color,
    this.type = 'assignment',
    this.dueAt,
    this.priority = 'medium',
    this.status = 'todo',
    this.notes,
  });

  final int id;
  final String title;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectTitle;
  final String? color;
  final String type;
  final DateTime? dueAt;
  final String priority;
  final String status;
  final String? notes;

  factory SchoolWork.fromJson(Map<String, dynamic> json) => SchoolWork(
        id: json['id'] as int,
        title: json['title'] as String,
        subjectId: (json['subjectId'] as num?)?.toInt(),
        subjectCode: json['subjectCode'] as String?,
        subjectTitle: json['subjectTitle'] as String?,
        color: json['color'] as String?,
        type: json['type'] as String? ?? 'assignment',
        dueAt: json['dueAt'] != null ? DateTime.tryParse(json['dueAt'] as String)?.toLocal() : null,
        priority: json['priority'] as String? ?? 'medium',
        status: json['status'] as String? ?? 'todo',
        notes: json['notes'] as String?,
      );
}
