import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// Keeps the runtime API base URL in sync with [ApiClient].
///
/// The build-time default comes from `--dart-define=API_BASE_URL=...`; a value
/// saved here overrides it (used by the in-app server settings screen so a
/// laptop can move to a new LAN address without rebuilding the APK).
class SettingsState extends ChangeNotifier {
  SettingsState(this._client);

  static const _key = 'server_url';

  final ApiClient _client;
  String? _saved;
  bool _loaded = false;

  bool get loaded => _loaded;
  bool get isCustom => _saved != null;
  String get serverUrl => _client.baseUrl;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        try {
          final url = normalizeServerUrl(raw);
          _saved = url;
          _client.baseUrl = url;
        } on FormatException {
          await prefs.remove(_key);
        }
      }
    } catch (e) {
      debugPrint('SettingsState: could not load server URL: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  /// Validates and persists [raw], switching the client immediately.
  ///
  /// Throws [FormatException] when the value is not a usable http(s) URL.
  Future<void> save(String raw) async {
    final url = normalizeServerUrl(raw);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url);
    _saved = url;
    _client.baseUrl = url;
    notifyListeners();
  }

  Future<void> resetServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('SettingsState: could not clear server URL: $e');
    }
    _saved = null;
    _client.baseUrl = null;
    notifyListeners();
  }

  /// Normalises user input into `scheme://host[:port][/path]`.
  ///
  /// * trims whitespace and trailing slashes
  /// * prepends `http://` when the scheme is missing
  /// * defaults the API path to `/api`
  static String normalizeServerUrl(String? raw) {
    final input = raw?.trim() ?? '';
    if (input.isEmpty) {
      throw const FormatException('Server address is required');
    }
    var value = input;
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value)) {
      value = 'http://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Use a valid http:// or https:// address');
    }
    var path = uri.path;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty || path == '/') path = '/api';
    return '${uri.scheme}://${uri.authority}$path';
  }
}
