import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static const _kBiometricEnabledKey = 'auth_biometric_enabled_v1';
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isSupported() async {
    try {
      final canAuthWithBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthWithBiometrics || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kBiometricEnabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBiometricEnabledKey, enabled);
    } catch (_) {}
  }

  Future<bool> authenticate({
    String reason = 'Подтвердите вход в приложение Мой ИМЭС',
  }) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
      if (authenticated) {
        HapticFeedback.lightImpact();
      }
      return authenticated;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
