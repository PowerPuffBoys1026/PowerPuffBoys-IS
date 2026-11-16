import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the student's light/dark preference (mirrors the v2 web toggle).
class ThemeState extends ChangeNotifier {
  static const _key = 'theme_mode';

  bool _dark = true;

  bool get isDark => _dark;
  ThemeMode get themeMode => _dark ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dark = prefs.getString(_key) != 'light';
    } catch (e) {
      debugPrint('ThemeState: could not load theme: $e');
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _dark = !_dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _dark ? 'dark' : 'light');
    } catch (e) {
      debugPrint('ThemeState: could not save theme: $e');
    }
  }
}
