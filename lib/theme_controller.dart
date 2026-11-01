import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'platform/theme_platform.dart';

enum AppAccent { blue, orange, purple, red }

class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode'; // light | dark | system
  static const _accentKey = 'theme_accent'; // blue | orange | purple | red
  static const _uiScaleKey = 'ui_scale'; // double, 0.8 .. 1.3
  static const _reduceEffectsKey = 'reduce_visual_effects';
  static const _reduceAnimationsKey = 'reduce_animations';
  static const _materialYouKey = 'theme_material_you';
  static const _amoledBlackKey = 'theme_amoled_black';

  bool _materialYou = false;
  bool get materialYou => _materialYou;

  bool _amoledBlack = false;
  bool get amoledBlack => _amoledBlack;

  bool _reduceEffects = false;
  bool get reduceEffects => _reduceEffects;

  bool _reduceAnimations = false;
  bool get reduceAnimations => _reduceAnimations;

  double _uiScale = 1.0;
  double get uiScale => _uiScale;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  AppAccent _accent = AppAccent.orange;
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
    final a = prefs.getString(_accentKey) ?? 'orange';

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
    _uiScale = prefs.getDouble(_uiScaleKey) ?? 1.0;
    _reduceEffects = prefs.getBool(_reduceEffectsKey) ?? false;
    _reduceAnimations = prefs.getBool(_reduceAnimationsKey) ?? false;
    _materialYou = prefs.getBool(_materialYouKey) ?? false;
    _amoledBlack = prefs.getBool(_amoledBlackKey) ?? false;

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

  Future<void> setThemeMode(ThemeMode mode) => setMode(mode);

  Future<void> setUiScale(double scale) async {
    final rounded = (scale * 10).round() / 10.0;
    if ((_uiScale - rounded).abs() < 0.01) return;
    _uiScale = rounded;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_uiScaleKey, _uiScale);
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

  Future<void> setReduceEffects(bool value) async {
    if (_reduceEffects == value) return;
    _reduceEffects = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reduceEffectsKey, value);
  }

  Future<void> setReduceAnimations(bool value) async {
    if (_reduceAnimations == value) return;
    _reduceAnimations = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reduceAnimationsKey, value);
  }

  Future<void> setMaterialYou(bool value) async {
    if (_materialYou == value) return;
    _materialYou = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_materialYouKey, value);
  }

  Future<void> setAmoledBlack(bool value) async {
    if (_amoledBlack == value) return;
    _amoledBlack = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_amoledBlackKey, value);
  }

  Future<void> setAppearance({
    required ThemeMode mode,
    required AppAccent accent,
    required double uiScale,
    bool? materialYou,
    bool? amoledBlack,
  }) async {
    final roundedScale = (uiScale * 10).round() / 10.0;
    final modeChanged = _mode != mode;
    final accentChanged = _accent != accent;
    final scaleChanged = (_uiScale - roundedScale).abs() >= 0.01;
    final myChanged = materialYou != null && _materialYou != materialYou;
    final amoledChanged = amoledBlack != null && _amoledBlack != amoledBlack;

    if (!modeChanged && !accentChanged && !scaleChanged && !myChanged && !amoledChanged) return;

    _mode = mode;
    _accent = accent;
    _uiScale = roundedScale;
    if (materialYou != null) _materialYou = materialYou;
    if (amoledBlack != null) _amoledBlack = amoledBlack;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (modeChanged) {
      final v = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_key, v);
      await _syncPlatform(mode);
    }
    if (accentChanged) {
      final v = switch (accent) {
        AppAccent.blue => 'blue',
        AppAccent.orange => 'orange',
        AppAccent.purple => 'purple',
        AppAccent.red => 'red',
      };
      await prefs.setString(_accentKey, v);
    }
    if (scaleChanged) {
      await prefs.setDouble(_uiScaleKey, _uiScale);
    }
    if (myChanged) {
      await prefs.setBool(_materialYouKey, _materialYou);
    }
    if (amoledChanged) {
      await prefs.setBool(_amoledBlackKey, _amoledBlack);
    }
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
