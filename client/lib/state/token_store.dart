import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT across app restarts. Backed by `shared_preferences`, which
/// works on Android, iOS, Web, and Desktop. Swap for `flutter_secure_storage`
/// later if we want OS-level encryption on mobile.
class TokenStore {
  static const _key = 'classmate_token';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
