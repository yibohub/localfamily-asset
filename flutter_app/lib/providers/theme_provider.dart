import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式 Provider
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  static const String _keyThemeMode = 'theme_mode';

  ThemeMode get themeMode => _themeMode;

  /// 当前是否为深色模式
  bool get isDarkMode {
    // 强制使用系统主题判断，避免依赖 BuildContext
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadThemeMode();
  }

  /// 加载保存的主题模式
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_keyThemeMode);
    if (savedMode != null) {
      _themeMode = _parseThemeMode(savedMode);
      notifyListeners();
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.toString());
    notifyListeners();
  }

  /// 切换主题（在浅色/深色之间）
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await setThemeMode(newMode);
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
