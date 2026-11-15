import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/grade.dart';

/// Grades (weighted components) plus the derived GPA summary.
class GradesState extends ChangeNotifier {
  GradesState(this._api);

  final Api _api;

  List<GradeComponent> grades = [];
  GradeSummary? summary;
  bool loading = false;
  String? error;

  List<GradeComponent> forSubject(int subjectId) =>
      grades.where((g) => g.subjectId == subjectId).toList();

  SubjectGradeSummary? summaryFor(int subjectId) {
    for (final subject in summary?.subjects ?? const <SubjectGradeSummary>[]) {
      if (subject.subjectId == subjectId) return subject;
    }
    return null;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.grades(),
        _api.gradeSummary(),
      ]);
      grades = results[0] as List<GradeComponent>;
      summary = results[1] as GradeSummary;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Could not load grades (${e.runtimeType}: $e)';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> create({
    required int subjectId,
    required String componentName,
    required double weightPct,
    double? scorePct,
    double targetPct = 85,
  }) async {
    await _api.createGrade(
      subjectId: subjectId,
      componentName: componentName,
      weightPct: weightPct,
      scorePct: scorePct,
      targetPct: targetPct,
    );
    await load();
  }

  Future<void> update(
    int id, {
    String? componentName,
    double? weightPct,
    double? scorePct,
    bool clearScore = false,
    double? targetPct,
  }) async {
    await _api.updateGrade(
      id,
      componentName: componentName,
      weightPct: weightPct,
      scorePct: scorePct,
      clearScore: clearScore,
      targetPct: targetPct,
    );
    await load();
  }

  Future<void> remove(int id) async {
    await _api.deleteGrade(id);
    await load();
  }

  void reset() {
    grades = [];
    summary = null;
    error = null;
    notifyListeners();
  }
}
