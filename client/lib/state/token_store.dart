import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT across app restarts.
///
/// Tokens are stored with `flutter_secure_storage` (Android Keystore / Keychain
/// / DPAPI). Builds that previously used `shared_preferences` are migrated on
/// first read so existing installs stay signed in.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'classmate_token';

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      final secure = await _storage.read(key: _key);
      if (secure != null) return secure;
      return await _readAndMigrateLegacy();
    } catch (e) {
      debugPrint('TokenStore: secure read failed, using prefs: $e');
      return _readLegacy();
    }
  }

  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (e) {
      debugPrint('TokenStore: secure write failed, using prefs: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('TokenStore: secure delete failed: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('TokenStore: prefs delete failed: $e');
    }
  }

  Future<String?> _readAndMigrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_key);
    if (legacy == null) return null;
    try {
      await _storage.write(key: _key, value: legacy);
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('TokenStore: legacy migration failed: $e');
    }
    return legacy;
  }

  Future<String?> _readLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    } catch (e) {
      debugPrint('TokenStore: prefs read failed: $e');
      return null;
    }
  }
}
