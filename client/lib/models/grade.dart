import 'json.dart';

/// A weighted grade component belonging to a subject (`GET /grades`).
class GradeComponent {
  const GradeComponent({
    required this.id,
    required this.subjectId,
    required this.componentName,
    required this.weightPct,
    this.subjectCode,
    this.subjectTitle,
    this.scorePct,
    this.targetPct = 85,
    this.createdAt,
  });

  final int id;
  final int subjectId;
  final String? subjectCode;
  final String? subjectTitle;
  final String componentName;
  final double weightPct;
  final double? scorePct;
  final double targetPct;
  final String? createdAt;

  bool get isGraded => scorePct != null;

  factory GradeComponent.fromJson(Map<String, dynamic> json) => GradeComponent(
        id: asInt(json['id']) ?? 0,
        subjectId: asInt(json['subjectId']) ?? 0,
        subjectCode: json['subjectCode'] as String?,
        subjectTitle: json['subjectTitle'] as String?,
        componentName: json['componentName'] as String? ?? 'Component',
        weightPct: asDouble(json['weightPct']) ?? 0,
        scorePct: asDouble(json['scorePct']),
        targetPct: asDouble(json['targetPct']) ?? 85,
        createdAt: json['createdAt'] as String?,
      );
}

/// A component nested inside `GET /grades/summary` (no subject fields).
class GradeSummaryComponent {
  const GradeSummaryComponent({
    required this.id,
    required this.componentName,
    required this.weightPct,
    this.scorePct,
    this.targetPct = 85,
  });

  final int id;
  final String componentName;
  final double weightPct;
  final double? scorePct;
  final double targetPct;

  factory GradeSummaryComponent.fromJson(Map<String, dynamic> json) => GradeSummaryComponent(
        id: asInt(json['id']) ?? 0,
        componentName: json['componentName'] as String? ?? 'Component',
        weightPct: asDouble(json['weightPct']) ?? 0,
        scorePct: asDouble(json['scorePct']),
        targetPct: asDouble(json['targetPct']) ?? 85,
      );
}

/// Per-subject grade rollup from `GET /grades/summary`.
class SubjectGradeSummary {
  const SubjectGradeSummary({
    required this.subjectId,
    required this.code,
    required this.title,
    this.units = 0,
    this.color = '#4F46E5',
    this.componentsCount = 0,
    this.currentPercentage,
    this.letterGrade = 'N/A',
    this.gpa,
    this.targetPercentage = 85,
    this.remainingWeight = 0,
    this.neededOnRemaining,
    this.components = const [],
  });

  final int subjectId;
  final String code;
  final String title;
  final int units;
  final String color;
  final int componentsCount;
  final double? currentPercentage;
  final String letterGrade;
  final double? gpa;
  final double targetPercentage;
  final double remainingWeight;
  final double? neededOnRemaining;
  final List<GradeSummaryComponent> components;

  factory SubjectGradeSummary.fromJson(Map<String, dynamic> json) => SubjectGradeSummary(
        subjectId: asInt(json['subjectId']) ?? 0,
        code: json['code'] as String? ?? '',
        title: json['title'] as String? ?? '',
        units: asInt(json['units']) ?? 0,
        color: json['color'] as String? ?? '#4F46E5',
        componentsCount: asInt(json['componentsCount']) ?? 0,
        currentPercentage: asDouble(json['currentPercentage']),
        letterGrade: json['letterGrade'] as String? ?? 'N/A',
        gpa: asDouble(json['gpa']),
        targetPercentage: asDouble(json['targetPercentage']) ?? 85,
        remainingWeight: asDouble(json['remainingWeight']) ?? 0,
        neededOnRemaining: asDouble(json['neededOnRemaining']),
        components: (json['components'] as List? ?? const [])
            .map((e) => GradeSummaryComponent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Envelope returned by `GET /grades/summary`.
class GradeSummary {
  const GradeSummary({
    this.cumulativeGpa,
    this.academicStanding = 'On Track',
    this.totalUnitsCounted = 0,
    this.subjects = const [],
  });

  final double? cumulativeGpa;
  final String academicStanding;
  final int totalUnitsCounted;
  final List<SubjectGradeSummary> subjects;

  factory GradeSummary.fromJson(Map<String, dynamic> json) => GradeSummary(
        cumulativeGpa: asDouble(json['cumulativeGpa']),
        academicStanding: json['academicStanding'] as String? ?? 'On Track',
        totalUnitsCounted: asInt(json['totalUnitsCounted']) ?? 0,
        subjects: (json['subjects'] as List? ?? const [])
            .map((e) => SubjectGradeSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
