import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppHaptics {
  AppHaptics._();

  static const _kHapticEnabledKey = 'ui_haptic_feedback_enabled_v1';
  static bool _enabled = true;
  static bool _initialized = false;

  static bool get enabled => _enabled;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kHapticEnabledKey) ?? true;
    } catch (_) {}
    _initialized = true;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHapticEnabledKey, value);
    } catch (_) {}
  }

  static void selectionClick() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  static void lightImpact() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  static void vibrate() {
    if (!_enabled) return;
    HapticFeedback.vibrate();
  }
}

