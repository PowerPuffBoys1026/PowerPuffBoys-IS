import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/study_session.dart';

/// Study (focus timer) sessions and aggregate stats.
class StudyState extends ChangeNotifier {
  StudyState(this._api);

  final Api _api;

  List<StudySession> sessions = [];
  StudyStats? stats;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.studySessions(),
        _api.studyStats(),
      ]);
      sessions = results[0] as List<StudySession>;
      stats = results[1] as StudyStats;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Could not load study data (${e.runtimeType}: $e)';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<StudySession> create({
    int? subjectId,
    required int durationMinutes,
    String mode = 'focus',
    String? notes,
  }) async {
    final session = await _api.createStudySession(
      subjectId: subjectId,
      durationMinutes: durationMinutes,
      mode: mode,
      notes: notes,
    );
    await load();
    return session;
  }

  Future<void> remove(int id) async {
    await _api.deleteStudySession(id);
    await load();
  }

  void reset() {
    sessions = [];
    stats = null;
    error = null;
    notifyListeners();
  }
}
