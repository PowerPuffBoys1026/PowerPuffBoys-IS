class SubjectNote {
  const SubjectNote({
    required this.id,
    this.subjectId,
    this.subjectCode,
    this.subjectTitle,
    this.subjectColor,
    required this.title,
    required this.content,
    this.tags,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectTitle;
  final String? subjectColor;
  final String title;
  final String content;
  final String? tags;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'subjectCode': subjectCode,
    'subjectTitle': subjectTitle,
    'subjectColor': subjectColor,
    'title': title,
    'content': content,
    'tags': tags,
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SubjectNote.fromJson(Map<String, dynamic> json) => SubjectNote(
    id: json['id'] as int,
    subjectId: (json['subjectId'] as num?)?.toInt(),
    subjectCode: json['subjectCode'] as String?,
    subjectTitle: json['subjectTitle'] as String?,
    subjectColor: json['subjectColor'] as String?,
    title: json['title'] as String,
    content: json['content'] as String,
    tags: json['tags'] as String?,
    isPinned: json['isPinned'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
