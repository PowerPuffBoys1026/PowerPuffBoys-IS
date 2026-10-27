import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import 'token_store.dart';

class AuthState extends ChangeNotifier {
  AuthState(this._api, this._store);

  final Api _api;
  final TokenStore _store;

  User? user;
  String? token;
  bool ready = false; // finished restoring the saved session
  bool busy = false; // a login/register request is in flight
  String? error;

  bool get isAuthenticated => token != null;

  /// Called once at startup to restore a saved session.
  Future<void> restore() async {
    final saved = await _store.read();
    if (saved != null) {
      _api.token = saved;
      try {
        user = await _api.me();
        token = saved;
      } on ApiException {
        await _store.clear();
        _api.token = null;
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) {
    return _run(() => _api.login(email: email, password: password));
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? studentNo,
    String? course,
  }) {
    return _run(() => _api.register(
          email: email,
          password: password,
          fullName: fullName,
          studentNo: studentNo,
          course: course,
        ));
  }

  Future<bool> _run(Future<AuthResult> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await action();
      token = result.token;
      user = result.user;
      _api.token = result.token;
      await _store.write(result.token);
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Could not reach the server. Is the API running?';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    token = null;
    user = null;
    _api.token = null;
    await _store.clear();
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}
