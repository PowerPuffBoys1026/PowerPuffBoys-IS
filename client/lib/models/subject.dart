class Subject {
  const Subject({
    required this.id,
    required this.code,
    required this.title,
    this.instructor,
    this.instructorEmail,
    this.officeHours,
    this.units = 0,
    this.color = '#4F46E5',
  });

  final int id;
  final String code;
  final String title;
  final String? instructor;
  final String? instructorEmail;
  final String? officeHours;
  final int units;
  final String color;

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'title': title,
    'instructor': instructor,
    'instructorEmail': instructorEmail,
    'officeHours': officeHours,
    'units': units,
    'color': color,
  };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    id: json['id'] as int,
    code: json['code'] as String,
    title: json['title'] as String,
    instructor: json['instructor'] as String?,
    instructorEmail: json['instructorEmail'] as String?,
    officeHours: json['officeHours'] as String?,
    units: (json['units'] as num?)?.toInt() ?? 0,
    color: json['color'] as String? ?? '#4F46E5',
  );
}
