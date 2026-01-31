import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Режим восстановления сессии (авторелогин)
enum AuthReloginMode {
  /// Не хранить пароль. При истёкшей сессии открываем WebView логина.
  safeUiLogin,

  /// Хранить логин/пароль (по выбору пользователя) и пробовать логиниться в фоне.
  silentWithCredentials,
}

class AuthSettings extends ChangeNotifier {
  AuthSettings._();
  static final AuthSettings instance = AuthSettings._();

  static const _spMode = 'auth_relogin_mode_v1';
  static const _spCredsEnabled = 'auth_creds_enabled_v1';

  static const _storage = FlutterSecureStorage();
  static const _kUser = 'auth_username_v1';
  static const _kPass = 'auth_password_v1';

  AuthReloginMode _mode = AuthReloginMode.safeUiLogin;
  bool _credsEnabled = false;

  AuthReloginMode get mode => _mode;
  bool get credsEnabled => _credsEnabled;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final modeRaw = sp.getString(_spMode);
    final ce = sp.getBool(_spCredsEnabled);

    _mode = (modeRaw == AuthReloginMode.silentWithCredentials.name)
        ? AuthReloginMode.silentWithCredentials
        : AuthReloginMode.safeUiLogin;

    _credsEnabled = ce ?? false;
    notifyListeners();
  }

  Future<void> setMode(AuthReloginMode mode) async {
    _mode = mode;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_spMode, mode.name);
    notifyListeners();
  }

  Future<void> setCredsEnabled(bool enabled) async {
    _credsEnabled = enabled;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_spCredsEnabled, enabled);
    notifyListeners();
  }

  Future<({String username, String password})?> getCredentials() async {
    final u = (await _storage.read(key: _kUser))?.trim() ?? '';
    final p = (await _storage.read(key: _kPass)) ?? '';
    if (u.isEmpty || p.isEmpty) return null;
    return (username: u, password: p);
  }

  Future<void> setCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _kUser, value: username.trim());
    await _storage.write(key: _kPass, value: password);
    notifyListeners();
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _kUser);
    await _storage.delete(key: _kPass);
    notifyListeners();
  }
}
