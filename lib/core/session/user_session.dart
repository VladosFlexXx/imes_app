import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Отслеживает активный идентификатор аккаунта для изоляции пользовательских данных.
class UserSession extends ChangeNotifier {
  UserSession._();
  static final UserSession instance = UserSession._();

  static const String _kCurrentAccountId = 'current_user_account_id_v1';
  String? _accountId;

  String get accountId => _accountId ?? '';
  bool get hasAccount => _accountId != null && _accountId!.isNotEmpty;

  Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _accountId = sp.getString(_kCurrentAccountId);
    } catch (_) {}
  }

  Future<void> setAccountId(String id) async {
    final clean = id.trim().toLowerCase();
    if (_accountId == clean) return;
    _accountId = clean.isEmpty ? null : clean;
    try {
      final sp = await SharedPreferences.getInstance();
      if (_accountId == null) {
        await sp.remove(_kCurrentAccountId);
      } else {
        await sp.setString(_kCurrentAccountId, _accountId!);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> clear() async {
    _accountId = null;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kCurrentAccountId);
    } catch (_) {}
    notifyListeners();
  }
}
