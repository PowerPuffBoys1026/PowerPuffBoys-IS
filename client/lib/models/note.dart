class Note {
  final int id;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectTitle;
  final String? subjectColor;
  final String title;
  final String content;
  final bool isPinned;
  final String? color;
  final String? tags;
  final String createdAt;
  final String updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.color,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.subjectId,
    this.subjectCode,
    this.subjectTitle,
    this.subjectColor,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as int,
      subjectId: (json['subjectId'] as num?)?.toInt(),
      subjectCode: json['subjectCode'] as String?,
      subjectTitle: json['subjectTitle'] as String?,
      subjectColor: json['subjectColor'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      content: json['content'] as String? ?? '',
      isPinned: json['isPinned'] == true,
      color: json['color'] as String?,
      tags: json['tags'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}
