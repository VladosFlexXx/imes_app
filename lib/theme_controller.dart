import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'platform/theme_platform.dart';

enum AppAccent { blue, orange, purple, red }

class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode'; // light | dark | system
  static const _accentKey = 'theme_accent'; // blue | orange | purple | red

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  AppAccent _accent = AppAccent.blue;
  AppAccent get accent => _accent;

  Color get seedColor => switch (_accent) {
    AppAccent.blue => const Color(0xFF2868EC),
    AppAccent.orange => const Color(0xFFEC5C0D),
    AppAccent.purple => const Color(0xFF973AED),
    AppAccent.red => const Color(0xFFDF2B2B),
  };

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key) ?? 'system';
    final a = prefs.getString(_accentKey) ?? 'blue';

    _mode = switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _accent = switch (a) {
      'orange' => AppAccent.orange,
      'purple' => AppAccent.purple,
      'red' => AppAccent.red,
      _ => AppAccent.blue,
    };

    // 🔥 синхронизируем Android night mode сразу при старте
    await _syncPlatform(_mode);

    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_key, v);

    // 🔥 синхронизируем Android night mode при переключении в профиле
    await _syncPlatform(mode);
  }

  Future<void> setAccent(AppAccent accent) async {
    if (_accent == accent) return;
    _accent = accent;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final v = switch (accent) {
      AppAccent.blue => 'blue',
      AppAccent.orange => 'orange',
      AppAccent.purple => 'purple',
      AppAccent.red => 'red',
    };
    await prefs.setString(_accentKey, v);
  }

  Future<void> _syncPlatform(ThemeMode mode) async {
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await ThemePlatform.setThemeMode(v);
  }
}
