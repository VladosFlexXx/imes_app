import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSecurityService {
  AppSecurityService._();
  static final AppSecurityService instance = AppSecurityService._();

  static const _channel = MethodChannel('app.security');
  static const _prefKey = 'secure_screen_protection_v1';

  bool _screenProtectionEnabled = false;
  bool get isScreenProtectionEnabled => _screenProtectionEnabled;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _screenProtectionEnabled = prefs.getBool(_prefKey) ?? false;
      if (Platform.isAndroid && _screenProtectionEnabled) {
        await _applyNative(_screenProtectionEnabled);
      }
    } catch (_) {}
  }

  Future<bool> setScreenProtection(bool enabled) async {
    _screenProtectionEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);

      if (Platform.isAndroid) {
        await _applyNative(enabled);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyNative(bool enabled) async {
    try {
      await _channel.invokeMethod('setSecureMode', {'enabled': enabled});
    } catch (_) {}
  }
}

