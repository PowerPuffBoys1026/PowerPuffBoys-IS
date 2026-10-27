class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.studentNo,
    this.course,
  });

  final int id;
  final String email;
  final String fullName;
  final String? studentNo;
  final String? course;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        studentNo: json['studentNo'] as String?,
        course: json['course'] as String?,
      );
}
