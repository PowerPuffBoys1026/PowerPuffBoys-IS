class SubjectGrade {
  const SubjectGrade({
    required this.id,
    required this.subjectId,
    this.subjectCode,
    this.subjectTitle,
    required this.componentName,
    required this.weightPct,
    this.scorePct,
    this.targetPct = 85,
  });

  final int id;
  final int subjectId;
  final String? subjectCode;
  final String? subjectTitle;
  final String componentName;
  final double weightPct;
  final double? scorePct;
  final double targetPct;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'subjectCode': subjectCode,
    'subjectTitle': subjectTitle,
    'componentName': componentName,
    'weightPct': weightPct,
    'scorePct': scorePct,
    'targetPct': targetPct,
  };

  factory SubjectGrade.fromJson(Map<String, dynamic> json) => SubjectGrade(
    id: json['id'] as int,
    subjectId: (json['subjectId'] as num).toInt(),
    subjectCode: json['subjectCode'] as String?,
    subjectTitle: json['subjectTitle'] as String?,
    componentName: json['componentName'] as String,
    weightPct: (json['weightPct'] as num).toDouble(),
    scorePct: (json['scorePct'] as num?)?.toDouble(),
    targetPct: (json['targetPct'] as num?)?.toDouble() ?? 85,
  );
}

class SubjectGradeSummary {
  const SubjectGradeSummary({
    required this.subjectId,
    required this.code,
    required this.title,
    required this.units,
    required this.color,
    required this.componentsCount,
    this.currentPercentage,
    required this.letterGrade,
    this.gpa,
    required this.targetPercentage,
    required this.remainingWeight,
    this.neededOnRemaining,
    required this.components,
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
  final List<SubjectGrade> components;

  factory SubjectGradeSummary.fromJson(Map<String, dynamic> json) =>
      SubjectGradeSummary(
        subjectId: (json['subjectId'] as num).toInt(),
        code: json['code'] as String,
        title: json['title'] as String,
        units: (json['units'] as num?)?.toInt() ?? 3,
        color: json['color'] as String? ?? '#4F46E5',
        componentsCount: (json['componentsCount'] as num?)?.toInt() ?? 0,
        currentPercentage: (json['currentPercentage'] as num?)?.toDouble(),
        letterGrade: json['letterGrade'] as String? ?? 'N/A',
        gpa: (json['gpa'] as num?)?.toDouble(),
        targetPercentage:
            (json['targetPercentage'] as num?)?.toDouble() ?? 85.0,
        remainingWeight: (json['remainingWeight'] as num?)?.toDouble() ?? 0.0,
        neededOnRemaining: (json['neededOnRemaining'] as num?)?.toDouble(),
        components: ((json['components'] as List?) ?? [])
            .map(
              (e) => SubjectGrade.fromJson({
                ...e as Map<String, dynamic>,
                'subjectId': json['subjectId'],
              }),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'code': code,
    'title': title,
    'units': units,
    'color': color,
    'componentsCount': componentsCount,
    'currentPercentage': currentPercentage,
    'letterGrade': letterGrade,
    'gpa': gpa,
    'targetPercentage': targetPercentage,
    'remainingWeight': remainingWeight,
    'neededOnRemaining': neededOnRemaining,
    'components': components.map((c) => c.toJson()).toList(),
  };
}

class GradeSummary {
  const GradeSummary({
    this.cumulativeGpa,
    required this.academicStanding,
    required this.totalUnitsCounted,
    required this.subjects,
  });

  final double? cumulativeGpa;
  final String academicStanding;
  final int totalUnitsCounted;
  final List<SubjectGradeSummary> subjects;

  factory GradeSummary.fromJson(Map<String, dynamic> json) => GradeSummary(
    cumulativeGpa: (json['cumulativeGpa'] as num?)?.toDouble(),
    academicStanding: json['academicStanding'] as String? ?? 'In Progress',
    totalUnitsCounted: (json['totalUnitsCounted'] as num?)?.toInt() ?? 0,
    subjects: ((json['subjects'] as List?) ?? [])
        .map((e) => SubjectGradeSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'cumulativeGpa': cumulativeGpa,
    'academicStanding': academicStanding,
    'totalUnitsCounted': totalUnitsCounted,
    'subjects': subjects.map((s) => s.toJson()).toList(),
  };
}
