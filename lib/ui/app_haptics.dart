import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppHaptics {
  AppHaptics._();

  static const _kHapticEnabledKey = 'ui_haptic_feedback_enabled_v1';
  static bool _enabled = true;
  static bool _initialized = false;

  static bool get enabled => !kIsWeb && _enabled;

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _enabled = false;
      _initialized = true;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kHapticEnabledKey) ?? true;
    } catch (_) {}
    _initialized = true;
  }

  static Future<void> setEnabled(bool value) async {
    if (kIsWeb) return;
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHapticEnabledKey, value);
    } catch (_) {}
  }

  static void selectionClick() {
    if (kIsWeb || !_enabled) return;
    HapticFeedback.selectionClick();
  }

  static void lightImpact() {
    if (kIsWeb || !_enabled) return;
    HapticFeedback.lightImpact();
  }

  static void light() => lightImpact();

  static void mediumImpact() {
    if (kIsWeb || !_enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (kIsWeb || !_enabled) return;
    HapticFeedback.heavyImpact();
  }

  static void vibrate() {
    if (kIsWeb || !_enabled) return;
    HapticFeedback.vibrate();
  }
}

