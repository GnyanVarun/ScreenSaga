import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const _themePrefKey = 'isDarkTheme';
  bool _isDarkTheme = false;

  ThemeNotifier() {
    _loadThemeFromPrefs();
  }

  bool get isDarkTheme => _isDarkTheme;

  // Add this getter so main.dart can access themeMode easily
  ThemeMode get themeMode => _isDarkTheme ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme(bool isDark) {
    _isDarkTheme = isDark;
    _saveThemeToPrefs(isDark);
    notifyListeners();
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkTheme = prefs.getBool(_themePrefKey) ?? false;
    notifyListeners();
  }

  Future<void> _saveThemeToPrefs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_themePrefKey, value);
  }
}
